import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/app_warning_dialog.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/group_invite_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/participant_entity.dart';
import '../bloc/chat_cubit.dart';
import '../bloc/messages_cubit.dart';

/// The quick-react palette on a long-pressed bubble. Any single emoji is
/// accepted by the server; these six are what one tap offers.
const List<String> _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// The sender avatar beside an incoming bubble, and the column it takes up
/// (avatar plus gap). Every incoming row reserves the column — only the last
/// bubble of a run draws the avatar in it — so bubbles, reactions and times
/// stay in one line down the transcript.
const double _senderAvatarSize = 28;
const double _senderColumnWidth = _senderAvatarSize + 8;

/// Consecutive messages from one sender read as a run — one name above, one
/// avatar below — unless this much time passed between two of them.
const Duration _runGap = Duration(minutes: 5);

class ChatPage extends StatelessWidget {
  const ChatPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ChatCubit>(param1: conversationId)..load(),
      child: _ChatView(conversationId: conversationId),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({required this.conversationId});
  final String conversationId;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> with WidgetsBindingObserver {
  final _draftController = TextEditingController();
  final _draftFocus = FocusNode();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  Timer? _refreshTimer;
  StreamSubscription<void>? _pushUpdates;

  /// One key per rendered message, so a tapped reply quote can find the
  /// original bubble and `Scrollable.ensureVisible` it. `ListView.builder`
  /// only builds what is on screen, so a key has no context until its row
  /// is built — [_revealMessage] walks the viewport up until it is.
  final Map<String, GlobalKey> _messageKeys = {};

  /// The bubble a reply quote just jumped to; tinted for a moment so the
  /// eye lands on it. A colour change only — no shadow (`docs/GOTCHAS.md`).
  String? _highlightedMessageId;
  Timer? _highlightTimer;
  bool _isJumping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pushUpdates = sl<PushNotificationService>().updates.listen((_) => _refreshLatest());
    _startRefreshTimer();
  }

  void _refreshLatest() {
    if (!mounted ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent != true ||
        sl<SessionManager>().currentState != SessionState.authenticated) {
      return;
    }
    unawaited(context.read<ChatCubit>().refreshLatest());
  }

  /// History poll. With the socket up, messages, edits and reactions
  /// arrive as frames and the poll is only a safety net for a dropped one;
  /// without it, the poll *is* delivery.
  static const Duration _pollLive = Duration(seconds: 30);
  static const Duration _pollFallback = Duration(seconds: 5);
  bool _isLive = false;

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_isLive ? _pollLive : _pollFallback, (_) => _refreshLatest());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLatest();
      _startRefreshTimer();
    } else {
      _refreshTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _highlightTimer?.cancel();
    _pushUpdates?.cancel();
    // The shell's Inbox poll stands down while this screen covers it
    // (`MainShellPage`); one refresh on the way out brings the list — and
    // the other conversations' unread counts — current for the return.
    unawaited(sl<MessagesCubit>().refresh(queueIfLoading: true));
    _draftController.dispose();
    _draftFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// The inbox row first — it is what group changes and live previews are
  /// written to — then the cubit's own detail for a conversation the inbox
  /// has not loaded (a deep link, a group just joined).
  ConversationEntity? _conversation(ChatState state) {
    final conversations = sl<MessagesCubit>().state.conversations;
    for (final c in conversations) {
      if (c.id == widget.conversationId) return c;
    }
    return state.conversation;
  }

  void _send() {
    final cubit = context.read<ChatCubit>();
    final text = _draftController.text;
    if (text.trim().isEmpty && cubit.state.pendingAttachments.isEmpty) return;
    unawaited(cubit.send(text));
    _draftController.clear();
  }

  Future<void> _pickAttachment() async {
    final cubit = context.read<ChatCubit>();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AttachmentSourceSheet(),
    );
    if (source == null || !mounted) return;
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: AppConstants.postImageMaxDimension,
      maxHeight: AppConstants.postImageMaxDimension,
    );
    if (picked == null || !mounted) return;
    unawaited(cubit.attachFile(File(picked.path)));
  }

  Future<void> _showMessageActions(MessageEntity message) async {
    final cubit = context.read<ChatCubit>();
    final action = await showModalBottomSheet<_MessageAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MessageActionsSheet(message: message),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _ReactAction(:final emoji):
        unawaited(cubit.toggleReaction(message, emoji));
      case _ReplyAction():
        cubit.startReply(message);
        _draftFocus.requestFocus();
      case _EditAction():
        cubit.startEdit(message);
        _draftController.value = TextEditingValue(
          text: message.body,
          selection: TextSelection.collapsed(offset: message.body.length),
        );
        _draftFocus.requestFocus();
      case _DeleteAction():
        final confirmed = await AppWarningDialog.show(
          context,
          title: 'Unsend this message?',
          message: 'It will be removed for everyone in the conversation.',
          confirmLabel: 'Unsend',
          icon: Icons.delete_outline,
        );
        if (confirmed && mounted) unawaited(cubit.deleteMessage(message));
    }
  }

  void _cancelCompose(ChatCubit cubit, ChatState state) {
    if (state.isEditing) {
      cubit.cancelEdit();
      _draftController.clear();
    } else {
      cubit.cancelReply();
    }
  }

  Future<void> _acceptInvite(GroupInviteCardEntity card) async {
    final cubit = context.read<ChatCubit>();
    final group = await cubit.acceptInvite(card);
    if (group == null || !mounted) return;
    AppStatusSnackbar.showSuccess(context, message: 'You joined ${group.name}.', title: 'Welcome!');
  }

  /// Most pages of history a quote tap will pull in looking for its
  /// original before giving up — ~15 × `messagesPageSize` messages.
  static const int _jumpMaxOlderPages = 15;

  /// A reply quote was tapped: bring the quoted message on screen and flash
  /// it. The quoted message is always older than the reply, so it is either
  /// already loaded (and above the viewport) or on an older page — pages are
  /// pulled in until it turns up, within [_jumpMaxOlderPages].
  Future<void> _jumpToMessage(String messageId) async {
    if (_isJumping) return;
    _isJumping = true;
    try {
      final cubit = context.read<ChatCubit>();
      var pagesLoaded = 0;
      while (!cubit.state.messages.any((m) => m.id == messageId)) {
        if (!cubit.state.hasMore || pagesLoaded >= _jumpMaxOlderPages) {
          if (mounted) AppStatusSnackbar.showError(context, message: 'That message is too far back to jump to.');
          return;
        }
        await cubit.loadOlder();
        pagesLoaded++;
        if (!mounted) return;
      }
      await _revealMessage(messageId);
      if (!mounted) return;
      _highlightTimer?.cancel();
      setState(() => _highlightedMessageId = messageId);
      _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _highlightedMessageId = null);
      });
    } finally {
      _isJumping = false;
    }
  }

  /// Scrolls until [messageId]'s row is built, then lets `ensureVisible`
  /// place it. Jumps a viewport at a time — the target may be many screens
  /// up — and animates only the final approach.
  Future<void> _revealMessage(String messageId) async {
    final key = _messageKeys[messageId];
    if (key == null) return;
    for (var step = 0; step < 200; step++) {
      // Read fresh each pass — the row may have been built by the last jump.
      final target = key.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0.2,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
        return;
      }
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.pixels <= position.minScrollExtent) return;
      _scrollController.jumpTo(math.max(position.minScrollExtent, position.pixels - position.viewportDimension));
      // Let the builder lay out the newly exposed rows before checking again.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return BlocListener<ChatCubit, ChatState>(
      listenWhen: (previous, current) =>
          previous.actionError != current.actionError ||
          previous.wasRemoved != current.wasRemoved ||
          previous.isLive != current.isLive,
      listener: (context, state) {
        if (state.isLive != _isLive) {
          _isLive = state.isLive;
          _startRefreshTimer();
          // Coming back up after a gap: catch up on whatever the socket missed.
          if (_isLive) _refreshLatest();
        }
        if (state.wasRemoved) {
          AppStatusSnackbar.showError(context, message: 'You are no longer in this group.', title: 'Removed');
          Navigator.of(context).maybePop();
          return;
        }
        final error = state.actionError;
        if (error != null) AppStatusSnackbar.showError(context, message: error);
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Column(
            children: [
              // Rebuilds on inbox changes too, since the header reads the
              // inbox row first (see `_conversation`).
              BlocBuilder<MessagesCubit, MessagesState>(
                bloc: sl<MessagesCubit>(),
                builder: (context, _) => BlocBuilder<ChatCubit, ChatState>(
                  buildWhen: (previous, current) => previous.conversation != current.conversation,
                  builder: (context, state) => _Header(conversation: _conversation(state)),
                ),
              ),
              Expanded(
                child: BlocConsumer<ChatCubit, ChatState>(
                  // Follow the newest message only. A length change alone
                  // is an older page arriving at the *top* (a quote jump
                  // pulling history in), which must not yank the view back
                  // to the bottom.
                  listenWhen: (previous, current) =>
                      previous.messages.lastOrNull?.id != current.messages.lastOrNull?.id,
                  listener: (context, state) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_scrollController.hasClients) return;
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    });
                  },
                  buildWhen: (previous, current) =>
                      previous.status != current.status ||
                      previous.messages != current.messages ||
                      previous.typingUserIds != current.typingUserIds ||
                      previous.busyMessageIds != current.busyMessageIds ||
                      previous.busyInviteIds != current.busyInviteIds ||
                      previous.errorMessage != current.errorMessage,
                  builder: (context, state) {
                    if (state.status == ChatStatus.loading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state.status == ChatStatus.error) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: ErrorView(
                          message: state.errorMessage ?? 'Could not load this conversation.',
                          onRetry: context.read<ChatCubit>().load,
                        ),
                      );
                    }
                    return BlocBuilder<MessagesCubit, MessagesState>(
                      bloc: sl<MessagesCubit>(),
                      builder: (context, inboxState) {
                        final conversation = _conversation(state);
                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                          itemCount: state.messages.length + (state.isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            final messages = state.messages;
                            if (index == messages.length) {
                              return _TypingBubble(
                                typists: _typists(state.typingUserIds, conversation),
                                isGroup: conversation?.isGroup ?? false,
                              );
                            }
                            final message = messages[index];
                            final card = message.groupInvite;
                            final Widget bubble;
                            if (card != null) {
                              bubble = _InviteCardBubble(
                                message: message,
                                card: card,
                                busy: state.busyInviteIds.contains(card.id),
                                onAccept: () => _acceptInvite(card),
                                onDecline: () => context.read<ChatCubit>().declineInvite(card),
                              );
                            } else {
                              final reply = message.replyTo;
                              bubble = _MessageBubble(
                                message: message,
                                sender: _participant(message.senderId, conversation),
                                isGroup: conversation?.isGroup ?? false,
                                firstInRun: index == 0 || !_sameRun(messages[index - 1], message),
                                lastInRun: index == messages.length - 1 || !_sameRun(message, messages[index + 1]),
                                isRead: _isReadByPeers(message, messages, conversation),
                                busy: state.busyMessageIds.contains(message.id),
                                quotedAuthor: reply == null ? null : _authorName(reply.senderId, conversation),
                                onLongPress: message.canInteract ? () => _showMessageActions(message) : null,
                                onToggleReaction: (emoji) => context.read<ChatCubit>().toggleReaction(message, emoji),
                                onAttachmentExpired: context.read<ChatCubit>().refreshAttachment,
                                onQuoteTap: reply == null ? null : () => _jumpToMessage(reply.id),
                              );
                            }
                            return KeyedSubtree(
                              key: _messageKeys.putIfAbsent(message.id, GlobalKey.new),
                              child: _JumpHighlight(active: message.id == _highlightedMessageId, child: bubble),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              _Composer(
                controller: _draftController,
                focusNode: _draftFocus,
                onSend: _send,
                onAttach: _pickAttachment,
                onCancelCompose: _cancelCompose,
                authorName: (message) => _authorName(message.senderId, _conversation(context.read<ChatCubit>().state)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The participant row for [userId] — null while the list is unhydrated,
  /// or once they have left the group.
  ParticipantEntity? _participant(String userId, ConversationEntity? conversation) {
    if (conversation == null) return null;
    for (final p in conversation.participants) {
      if (p.userId == userId) return p;
    }
    return null;
  }

  /// The participants behind `typingUserIds`, in the order they started.
  /// An id with no participant row (a member added since the detail was
  /// fetched) still counts — it renders with a placeholder avatar.
  List<ParticipantEntity> _typists(Set<String> userIds, ConversationEntity? conversation) => [
        for (final id in userIds)
          _participant(id, conversation) ??
              ParticipantEntity(userId: id, role: ParticipantRole.member, joinedAt: DateTime(1970)),
      ];

  /// How a reply names the message it quotes: the viewer is "You", anyone
  /// else goes by their participant row.
  String _authorName(String userId, ConversationEntity? conversation) {
    if (conversation?.viewerId == userId) return 'You';
    return _participant(userId, conversation)?.displayName ?? 'Unknown';
  }

  /// Whether [b] continues [a]'s run: same sender, close in time, and
  /// neither an invite card (a card is its own block, never part of a run).
  static bool _sameRun(MessageEntity a, MessageEntity b) =>
      a.senderId == b.senderId &&
      !a.isInviteCard &&
      !b.isInviteCard &&
      b.createdAt.difference(a.createdAt).abs() <= _runGap;
}

/// Only an actual read-message marker proves a read. `lastReadAt` is the
/// time of the read action, not the timestamp of the message read.
bool _isReadByPeers(MessageEntity message, List<MessageEntity> messages, ConversationEntity? conversation) {
  if (!message.fromMe || message.status != MessageDeliveryStatus.sent || conversation == null) {
    return false;
  }
  final peers = conversation.participants.where((peer) => peer.userId != message.senderId).toList();
  if (peers.isEmpty) return false;
  final messageIndex = messages.indexWhere((item) => item.id == message.id);
  return peers.every((peer) {
    final readId = peer.lastReadMessageId;
    if (readId == null) return false;
    if (readId == message.id) return true;
    final readIndex = messages.indexWhere((item) => item.id == readId);
    return messageIndex >= 0 && readIndex > messageIndex;
  });
}

class _Header extends StatelessWidget {
  const _Header({required this.conversation});
  final ConversationEntity? conversation;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final conversation = this.conversation;
    final isGroup = conversation?.isGroup ?? false;

    final String subtitle;
    if (conversation == null) {
      subtitle = '';
    } else if (isGroup) {
      final n = conversation.participants.length;
      subtitle = '$n ${n == 1 ? 'MEMBER' : 'MEMBERS'}';
    } else {
      subtitle = conversation.isOnline ? 'ACTIVE NOW' : 'OFFLINE';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line, width: 1.5)),
      ),
      child: Row(
        children: [
          AppIconButton(
            icon: const Icon(Icons.arrow_back),
            size: 36,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 10),
          if (conversation != null) ...[
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                onTap: isGroup
                    ? () => context.pushNamed(RouteNames.groupInfo, pathParameters: {'conversationId': conversation.id})
                    : null,
                child: Row(
                  children: [
                    AppAvatar(
                      initials: conversation.name.initials,
                      seed: conversation.avatarSeed,
                      imageUrl: conversation.avatarUrl,
                      cacheKey: conversation.avatarCacheKey,
                      size: 42,
                      showOnlineDot: conversation.isOnline,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conversation.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleRow.copyWith(color: colors.ink),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              if (!isGroup && conversation.isOnline) ...[
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors.grn),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(subtitle, style: AppTextStyles.metaMono.copyWith(color: colors.ink2)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isGroup)
              AppIconButton(
                icon: const Icon(Icons.info_outline),
                size: 36,
                onPressed: () =>
                    context.pushNamed(RouteNames.groupInfo, pathParameters: {'conversationId': conversation.id}),
              ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Composer
// ---------------------------------------------------------------------------

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onAttach,
    required this.onCancelCompose,
    required this.authorName,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final void Function(ChatCubit cubit, ChatState state) onCancelCompose;

  /// Names the sender of the message being replied to, for the banner.
  final String Function(MessageEntity message) authorName;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return BlocBuilder<ChatCubit, ChatState>(
      buildWhen: (previous, current) =>
          previous.replyingTo != current.replyingTo ||
          previous.editing != current.editing ||
          previous.pendingAttachments != current.pendingAttachments ||
          previous.isUploading != current.isUploading,
      builder: (context, state) {
        final cubit = context.read<ChatCubit>();
        final editing = state.editing;
        final replyingTo = state.replyingTo;
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.line, width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (editing != null)
                _ComposeBanner(
                  icon: Icons.edit_outlined,
                  label: 'EDITING',
                  preview: editing.body,
                  onCancel: () => onCancelCompose(cubit, state),
                )
              else if (replyingTo != null)
                _ComposeBanner(
                  icon: Icons.reply,
                  label: 'REPLYING TO ${replyingTo.fromMe ? 'YOURSELF' : authorName(replyingTo).toUpperCase()}',
                  preview: _previewText(replyingTo),
                  onCancel: () => onCancelCompose(cubit, state),
                ),
              if (state.pendingAttachments.isNotEmpty || state.isUploading)
                _PendingAttachmentsStrip(
                  attachments: state.pendingAttachments,
                  isUploading: state.isUploading,
                  onRemove: cubit.removePendingAttachment,
                ),
              Row(
                children: [
                  AppIconButton(
                    icon: const Icon(Icons.add),
                    size: 42,
                    // No files on an edit: the server only changes text.
                    onPressed: editing == null && !state.isUploading ? onAttach : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: colors.surf,
                        border: Border.all(color: colors.line, width: 1.5),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: cubit.onDraftChanged,
                        onSubmitted: (_) => onSend(),
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        style: AppTextStyles.hint.copyWith(color: colors.ink),
                        decoration: InputDecoration(
                          hintText: editing != null ? 'Edit message' : 'Message',
                          hintStyle: AppTextStyles.hint.copyWith(color: colors.ink3),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppIconButton(
                    icon: Icon(editing != null ? Icons.check : Icons.arrow_upward),
                    filled: true,
                    borderColor: colors.ink,
                    size: 46,
                    onPressed: state.isUploading ? null : onSend,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

String _timeLabel(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
}

String _previewText(MessageEntity message) {
  if (message.isDeleted) return 'Message deleted';
  if (message.hasText) return message.body;
  if (message.hasAttachments) return message.attachments.first.isImage ? 'Photo' : message.attachments.first.fileName;
  return '';
}

class _ComposeBanner extends StatelessWidget {
  const _ComposeBanner({required this.icon, required this.label, required this.preview, required this.onCancel});

  final IconData icon;
  final String label;
  final String preview;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: colors.surf2,
          border: Border(left: BorderSide(color: colors.yel, width: 3)),
          borderRadius: BorderRadius.circular(AppRadii.xs),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: colors.ink2),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySm.copyWith(color: colors.ink),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Cancel',
              icon: Icon(Icons.close, size: 18, color: colors.ink2),
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingAttachmentsStrip extends StatelessWidget {
  const _PendingAttachmentsStrip({required this.attachments, required this.isUploading, required this.onRemove});

  final List<AttachmentEntity> attachments;
  final bool isUploading;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        // 64 for the thumb plus headroom for the remove button that sits
        // just past its top-right corner — the viewport would clip it.
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(top: 8, right: 8),
          itemCount: attachments.length + (isUploading ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == attachments.length) {
              return Container(
                width: 64,
                decoration: BoxDecoration(
                  color: colors.surf2,
                  borderRadius: BorderRadius.circular(AppRadii.xs),
                  border: Border.all(color: colors.line, width: 1.5),
                ),
                child: const Center(
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }
            final attachment = attachments[index];
            return Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: _AttachmentThumb(attachment: attachment, borderRadius: BorderRadius.circular(AppRadii.xs)),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: Material(
                    color: colors.ink,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onRemove(attachment.id),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(Icons.close, size: 12, color: colors.bg),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AttachmentSourceSheet extends StatelessWidget {
  const _AttachmentSourceSheet();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return _SheetCard(
      children: [
        _SheetRow(
          icon: Icons.photo_library_outlined,
          label: 'Photo library',
          onTap: () => Navigator.of(context).pop(ImageSource.gallery),
        ),
        _SheetRow(
          icon: Icons.photo_camera_outlined,
          label: 'Take a photo',
          onTap: () => Navigator.of(context).pop(ImageSource.camera),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Text(
            'Up to 10 MB each, 10 per message.',
            style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Message actions
// ---------------------------------------------------------------------------

sealed class _MessageAction {
  const _MessageAction();
}

class _ReactAction extends _MessageAction {
  const _ReactAction(this.emoji);
  final String emoji;
}

class _ReplyAction extends _MessageAction {
  const _ReplyAction();
}

class _EditAction extends _MessageAction {
  const _EditAction();
}

class _DeleteAction extends _MessageAction {
  const _DeleteAction();
}

class _MessageActionsSheet extends StatelessWidget {
  const _MessageActionsSheet({required this.message});
  final MessageEntity message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final mine = message.myReaction?.emoji;
    return _SheetCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final emoji in _quickReactions)
                Material(
                  color: mine == emoji ? colors.yel : colors.surf2,
                  shape: CircleBorder(side: BorderSide(color: mine == emoji ? colors.ink : colors.line, width: 1.5)),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(_ReactAction(emoji)),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: colors.line2),
        _SheetRow(icon: Icons.reply, label: 'Reply', onTap: () => Navigator.of(context).pop(const _ReplyAction())),
        if (message.hasText)
          _SheetRow(
            icon: Icons.copy_outlined,
            label: 'Copy text',
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.body));
              Navigator.of(context).pop();
            },
          ),
        if (message.canEdit)
          _SheetRow(
            icon: Icons.edit_outlined,
            label: 'Edit',
            onTap: () => Navigator.of(context).pop(const _EditAction()),
          ),
        if (message.canDelete)
          _SheetRow(
            icon: Icons.delete_outline,
            label: 'Unsend',
            destructive: true,
            onTap: () => Navigator.of(context).pop(const _DeleteAction()),
          ),
      ],
    );
  }
}

class _SheetCard extends StatelessWidget {
  const _SheetCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surf,
            border: Border.all(color: colors.line, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.icon, required this.label, required this.onTap, this.destructive = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ink = destructive ? colors.red : colors.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ink),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppTextStyles.bodyMd.copyWith(color: ink, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bubbles
// ---------------------------------------------------------------------------

/// A bubble's corners: 20 all round, with the bottom corner on the sender's
/// side pulled in to 6 as the tail. A lone picture uses the same shape so an
/// image-only message still reads as a bubble without a frame around it.
BorderRadius _bubbleRadius({required bool mine, required bool tailed}) => BorderRadius.only(
  topLeft: const Radius.circular(20),
  topRight: const Radius.circular(20),
  bottomLeft: Radius.circular(!mine && tailed ? 6 : 20),
  bottomRight: Radius.circular(mine && tailed ? 6 : 20),
);

/// One message row. Text, a quote and file chips sit in the bubble; pictures
/// stand below it on their own with no frame (see [_ImageBlock]), so a
/// photo-only message has no bubble at all. Incoming rows carry the sender's
/// avatar on the last bubble of a run and, in a group, their name on the
/// first.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.sender,
    required this.isGroup,
    required this.firstInRun,
    required this.lastInRun,
    required this.isRead,
    required this.busy,
    required this.onLongPress,
    required this.onToggleReaction,
    required this.onAttachmentExpired,
    this.quotedAuthor,
    this.onQuoteTap,
  });

  final MessageEntity message;

  /// Who sent it, as the participant list knows them — null while unhydrated
  /// or after they left, in which case the avatar falls back to a `?` tile.
  final ParticipantEntity? sender;
  final bool isGroup;

  /// Where this message sits in a run of consecutive messages from one
  /// sender. The first carries the name (groups only), the last the avatar.
  final bool firstInRun;
  final bool lastInRun;

  final bool isRead;
  final bool busy;
  final VoidCallback? onLongPress;
  final ValueChanged<String> onToggleReaction;
  final ValueChanged<String> onAttachmentExpired;

  /// Who wrote the quoted message, when there is one.
  final String? quotedAuthor;

  /// Tapping the quoted block jumps the transcript to the original.
  final VoidCallback? onQuoteTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final mine = message.fromMe;
    final deleted = message.isDeleted;
    final reply = message.replyTo;
    // Everything under an incoming bubble is pushed past the avatar column
    // so it lines up with the bubble, not with the avatar.
    final indent = mine ? 0.0 : _senderColumnWidth;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78 - indent;
    final showName = !mine && isGroup && firstInRun;

    final images = deleted ? const <AttachmentEntity>[] : message.attachments.where((a) => a.isImage).toList();
    final files = deleted ? const <AttachmentEntity>[] : message.attachments.where((a) => !a.isImage).toList();
    final hasBubble = deleted || reply != null || message.hasText || files.isNotEmpty;

    Widget? bubble;
    if (hasBubble) {
      Widget body;
      if (deleted) {
        body = _Tombstone(ink: colors.ink3);
      } else {
        body = Column(
          // A quote spans the bubble's width; the bubble is still only as
          // wide as its widest line — that is what `IntrinsicWidth` below
          // buys, and why it is only paid for on a reply.
          crossAxisAlignment: reply != null ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reply != null) ...[
              _ReplyQuote(reply: reply, author: quotedAuthor ?? 'Unknown', onYellow: mine, onTap: onQuoteTap),
              const SizedBox(height: 8),
            ],
            for (final file in files)
              Padding(
                padding: EdgeInsets.only(bottom: message.hasText || file != files.last ? 6 : 0),
                child: _FileChip(attachment: file),
              ),
            if (message.hasText)
              Text(message.text, style: AppTextStyles.body.copyWith(color: mine ? colors.onYel : colors.ink)),
          ],
        );
        if (reply != null) body = IntrinsicWidth(child: body);
      }
      bubble = Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: deleted ? colors.surf2 : (mine ? colors.yel : colors.surf),
          border: Border.all(color: mine && !deleted ? colors.ink : colors.line, width: 1.5),
          // The tail goes on whatever is lowest: the bubble, or the
          // pictures under it.
          borderRadius: _bubbleRadius(mine: mine, tailed: images.isEmpty),
        ),
        child: body,
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: firstInRun ? 10 : 4, bottom: 3),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showName)
            Padding(
              padding: EdgeInsets.only(left: indent + 6, bottom: 4),
              child: Text(
                sender?.displayName ?? 'Unknown',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) ...[
                SizedBox(
                  width: _senderAvatarSize,
                  child: lastInRun ? _SenderAvatar(sender: sender, senderId: message.senderId) : null,
                ),
                const SizedBox(width: _senderColumnWidth - _senderAvatarSize),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Opacity(
                  opacity: busy ? 0.6 : 1,
                  child: GestureDetector(
                    onLongPress: busy ? null : onLongPress,
                    child: Column(
                      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ?bubble,
                        if (images.isNotEmpty) ...[
                          if (bubble != null) const SizedBox(height: 4),
                          _ImageBlock(images: images, maxWidth: maxWidth, mine: mine, onExpired: onAttachmentExpired),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (message.reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 6, left: indent),
              child: _ReactionsRow(
                reactions: message.reactions,
                enabled: !busy && message.canInteract,
                onTap: onToggleReaction,
              ),
            ),
          Padding(
            padding: EdgeInsets.only(top: 7, left: indent),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_timeLabel(message.sentAt.toLocal()), style: AppTextStyles.metaMono.copyWith(color: colors.ink2)),
                if (message.isEdited && !deleted) ...[
                  const SizedBox(width: 6),
                  Text('· EDITED', style: AppTextStyles.metaMono.copyWith(color: colors.ink3)),
                ],
                if (mine && !deleted) ...[const SizedBox(width: 8), _DeliveryMark(message: message, isRead: isRead)],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The small avatar beside an incoming bubble. Seeded by the sender's id,
/// the same way the inbox row and header seed theirs, so one person gets
/// the same placeholder colour everywhere.
class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({required this.sender, required this.senderId});

  final ParticipantEntity? sender;
  final String senderId;

  @override
  Widget build(BuildContext context) {
    return AppAvatar(
      initials: sender == null ? '?' : sender!.displayName.initials,
      seed: senderId.hashCode.abs(),
      imageUrl: sender?.avatarUrl,
      size: _senderAvatarSize,
    );
  }
}

class _Tombstone extends StatelessWidget {
  const _Tombstone({required this.ink});
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.block, size: 14, color: ink),
        const SizedBox(width: 6),
        Text(
          'Message deleted',
          style: AppTextStyles.body.copyWith(color: ink, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

/// The quoted message at the top of a reply: who wrote it, then what it
/// said, behind an accent bar — the same shape as the composer's reply
/// banner, so the quote in the transcript matches the one being written.
class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({required this.reply, required this.author, required this.onYellow, this.onTap});

  final ReplyPreviewEntity reply;

  /// Who wrote the quoted message — "You" for the viewer's own.
  final String author;

  /// On the viewer's own (yellow) bubble the quote uses the on-yellow ink.
  final bool onYellow;

  /// Jump to the quoted message. A tombstone is still a row in history, so
  /// a deleted quote is as jumpable as any other.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ink = onYellow ? colors.onYel : colors.ink;
    // The bar is brand yellow on a plain bubble, as on the composer banner;
    // on the yellow bubble it would vanish, so there it is ink.
    final accent = onYellow ? colors.onYel : colors.yel;
    final String text;
    if (reply.deleted) {
      text = 'Message deleted';
    } else if (reply.body.isNotEmpty) {
      text = reply.body;
    } else if (reply.hasAttachments) {
      text = 'Attachment';
    } else {
      text = '';
    }
    final IconData? icon = reply.deleted ? Icons.block : (reply.hasAttachments ? Icons.attach_file : null);
    return Semantics(
      button: onTap != null,
      label: 'Go to the quoted message from $author',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Clipped rather than given a `borderRadius`, since the decoration's
        // border is one-sided.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.xs),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 7, 12, 8),
            decoration: BoxDecoration(
              color: ink.withValues(alpha: 0.07),
              border: Border(left: BorderSide(color: accent, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm.copyWith(color: ink, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(icon, size: 14, color: ink.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySm.copyWith(
                          color: ink.withValues(alpha: 0.72),
                          fontStyle: reply.deleted ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The brief tint behind a bubble a reply quote jumped to. Colour only:
/// an animated blurred shadow crashed this project's renderer
/// (`docs/GOTCHAS.md`), and a colour change is the app's convention for an
/// animated "active" cue.
class _JumpHighlight extends StatelessWidget {
  const _JumpHighlight({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: active ? colors.yel.withValues(alpha: 0.22) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: child,
    );
  }
}

/// The pictures a message carries, with nothing drawn around them — no
/// bubble, no border. One picture is a wide tile in the bubble's own shape
/// (tail included); several are laid out two-up as plain rounded tiles.
class _ImageBlock extends StatelessWidget {
  const _ImageBlock({required this.images, required this.maxWidth, required this.mine, required this.onExpired});

  final List<AttachmentEntity> images;
  final double maxWidth;
  final bool mine;
  final ValueChanged<String> onExpired;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return SizedBox(
        width: maxWidth,
        height: maxWidth * 0.72,
        child: _AttachmentThumb(
          attachment: images.first,
          borderRadius: _bubbleRadius(mine: mine, tailed: true),
          onExpired: onExpired,
        ),
      );
    }
    final tile = (maxWidth - 6) / 2;
    return SizedBox(
      width: maxWidth,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: mine ? WrapAlignment.end : WrapAlignment.start,
        children: [
          for (final image in images)
            SizedBox(
              width: tile,
              height: tile,
              child: _AttachmentThumb(
                attachment: image,
                borderRadius: BorderRadius.circular(AppRadii.xs),
                onExpired: onExpired,
              ),
            ),
        ],
      ),
    );
  }
}

/// One picture, keyed in the image cache by attachment **id** rather than
/// URL: every history fetch re-signs the URL, and without a stable key the
/// 5-second poll would re-download every photo in the transcript each tick.
class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.attachment, required this.borderRadius, this.onExpired});

  final AttachmentEntity attachment;
  final BorderRadius borderRadius;
  final ValueChanged<String>? onExpired;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final url = attachment.url;
    final placeholder = Container(
      color: colors.surf2,
      alignment: Alignment.center,
      child: Icon(attachment.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined, color: colors.ink3),
    );
    return ClipRRect(
      borderRadius: borderRadius,
      child: url == null || !attachment.isImage
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url,
              cacheKey: attachment.id,
              fit: BoxFit.cover,
              memCacheWidth: 800,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) {
                // An expired link 403s — ask for a fresh one. Guarded in the
                // cubit, so a genuinely broken file cannot loop; deferred a
                // frame so the cubit never emits from inside a build.
                if (attachment.isUrlExpired && onExpired != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => onExpired!(attachment.id));
                }
                return placeholder;
              },
            ),
    );
  }
}

/// A non-image attachment. Tapping copies the download link — the same
/// affordance every other external link in this app uses (no
/// `url_launcher`; see `project_detail_page.dart`).
class _FileChip extends StatelessWidget {
  const _FileChip({required this.attachment});
  final AttachmentEntity attachment;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final url = attachment.url;
    return Material(
      color: colors.surf2,
      borderRadius: BorderRadius.circular(AppRadii.xs),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.xs),
        onTap: url == null
            ? null
            : () {
                Clipboard.setData(ClipboardData(text: url));
                AppStatusSnackbar.showSuccess(context, message: 'Download link copied.', title: 'Copied');
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file_outlined, size: 20, color: colors.ink2),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      attachment.fileName.isEmpty ? 'File' : attachment.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySm.copyWith(color: colors.ink, fontWeight: FontWeight.w600),
                    ),
                    Text(attachment.sizeLabel, style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionsRow extends StatelessWidget {
  const _ReactionsRow({required this.reactions, required this.enabled, required this.onTap});

  final List<ReactionEntity> reactions;
  final bool enabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final reaction in reactions)
          Material(
            color: colors.surf,
            shape: StadiumBorder(side: BorderSide(color: reaction.reactedByMe ? colors.yel : colors.line, width: 1.5)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: enabled ? () => onTap(reaction.emoji) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(
                  '${reaction.emoji} ${reaction.count}',
                  style: AppTextStyles.metaMono.copyWith(color: reaction.reactedByMe ? colors.onYel : colors.ink),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InviteCardBubble extends StatelessWidget {
  const _InviteCardBubble({
    required this.message,
    required this.card,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final MessageEntity message;
  final GroupInviteCardEntity card;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final mine = message.fromMe;
    final status = switch (card.status) {
      GroupInviteStatus.pending => mine ? 'Invite sent' : 'Invited you',
      GroupInviteStatus.accepted => 'Joined',
      GroupInviteStatus.declined => 'Declined',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surf,
                border: Border.all(color: colors.line, width: 1.5),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('GROUP INVITE', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      AppAvatar(
                        initials: card.displayTitle.initials,
                        seed: card.conversationId.hashCode.abs(),
                        imageUrl: card.photoUrl,
                        cacheKey: card.photoCacheKey,
                        size: 40,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.titleRow.copyWith(color: colors.ink),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${card.memberCount} ${card.memberCount == 1 ? 'MEMBER' : 'MEMBERS'} · ${status.toUpperCase()}',
                              style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (card.canRespond) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Join',
                            dense: true,
                            fullWidth: true,
                            onPressed: busy ? null : onAccept,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: 'Decline',
                            dense: true,
                            fullWidth: true,
                            variant: AppButtonVariant.outline,
                            onPressed: busy ? null : onDecline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              _timeLabel(message.sentAt.toLocal()),
              style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryMark extends StatelessWidget {
  const _DeliveryMark({required this.message, required this.isRead});
  final MessageEntity message;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (icon, label) = switch (message.status) {
      MessageDeliveryStatus.sending => (Icons.schedule, 'Sending'),
      MessageDeliveryStatus.failed => (Icons.error_outline, 'Failed to send. Tap to retry'),
      MessageDeliveryStatus.sent => isRead ? (Icons.done_all, 'Read') : (Icons.check, 'Sent'),
    };
    return Semantics(
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: message.status == MessageDeliveryStatus.failed ? () => context.read<ChatCubit>().retry(message) : null,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(
              icon,
              size: 16,
              color: message.status == MessageDeliveryStatus.failed
                  ? colors.red
                  : isRead
                  ? colors.grn
                  : colors.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

/// The "…" bubble, sitting in the same avatar column as incoming messages.
/// [sender] is the DM peer — a group's typing frame does not say who, so
/// there the column is left empty.
/// "Someone is typing": an incoming-side bubble with three pulsing dots,
/// carrying the typist's avatar like any of their messages would. In a
/// group the names go above it — one bubble however many are typing.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.typists, required this.isGroup});

  final List<ParticipantEntity> typists;
  final bool isGroup;

  String get _label {
    final names = typists.map((p) => p.displayName).toList();
    return switch (names.length) {
      0 => '',
      1 => '${names[0]} is typing',
      2 => '${names[0]} and ${names[1]} are typing',
      _ => '${names[0]}, ${names[1]} and ${names.length - 2} more are typing',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final sender = typists.firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isGroup && typists.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: _senderColumnWidth + 6, bottom: 4),
              child: Text(_label, style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2)),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: _senderAvatarSize,
                child: sender == null ? null : _SenderAvatar(sender: sender, senderId: sender.userId),
              ),
              const SizedBox(width: _senderColumnWidth - _senderAvatarSize),
              Semantics(
                label: typists.isEmpty ? 'Typing' : _label,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: colors.surf,
                    border: Border.all(color: colors.line, width: 1.5),
                    borderRadius: _bubbleRadius(mine: false, tailed: true),
                  ),
                  child: _TypingDots(color: colors.ink3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Three dots that rise and brighten in turn. Position and opacity only —
/// nothing here paints a shadow, which is the one animated thing this
/// renderer has crashed on (`docs/GOTCHAS.md`).
class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});

  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot runs the same rise, a fifth of a cycle behind the last.
            final phase = (_controller.value - i * 0.2) % 1.0;
            final lift = phase < 0.5 ? math.sin(phase * math.pi) : 0.0;
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 5, bottom: 3 * lift),
              child: Opacity(
                opacity: 0.35 + 0.65 * lift,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
