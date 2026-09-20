import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../bloc/chat_cubit.dart';
import '../bloc/messages_cubit.dart';

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
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  StreamSubscription<void>? _pushUpdates;
  ConversationEntity? _openedConversation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pushUpdates = sl<PushNotificationService>().updates.listen(
      (_) => _refreshLatest(),
    );
    _startRefreshTimer();
    unawaited(_loadConversation());
  }

  Future<void> _loadConversation() async {
    final result = await sl<ChatRepository>().getConversation(widget.conversationId);
    if (!mounted) return;
    result.fold((_) {}, (conversation) => setState(() => _openedConversation = conversation));
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

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshLatest(),
    );
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
    _pushUpdates?.cancel();
    _draftController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  ConversationEntity? get _conversation {
    final conversations = sl<MessagesCubit>().state.conversations;
    for (final c in conversations) {
      if (c.id == widget.conversationId) return c;
    }
    return _openedConversation;
  }

  void _send() {
    final text = _draftController.text;
    if (text.trim().isEmpty) return;
    context.read<ChatCubit>().send(text);
    _draftController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final conversation = _conversation;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.line, width: 1.5),
                ),
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
                    AppAvatar(
                      initials: conversation.name.initials,
                      seed: conversation.avatarSeed,
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
                            style: AppTextStyles.titleMd.copyWith(
                              fontSize: 15,
                              color: colors.ink,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              if (conversation.isOnline) ...[
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.grn,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                conversation.isOnline
                                    ? 'ACTIVE NOW'
                                    : 'OFFLINE',
                                style: AppTextStyles.metaMono.copyWith(
                                  color: colors.ink2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else
                    const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: BlocConsumer<ChatCubit, ChatState>(
                listenWhen: (previous, current) =>
                    previous.messages.length != current.messages.length ||
                    previous.messages.lastOrNull?.id !=
                        current.messages.lastOrNull?.id,
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
                builder: (context, state) {
                  if (state.status == ChatStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == ChatStatus.error) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: ErrorView(
                        message:
                            state.errorMessage ??
                            'Could not load this conversation.',
                        onRetry: context.read<ChatCubit>().load,
                      ),
                    );
                  }
                  return BlocBuilder<MessagesCubit, MessagesState>(
                    bloc: sl<MessagesCubit>(),
                    builder: (context, inboxState) {
                      final conversation = inboxState.conversations
                          .where((item) => item.id == widget.conversationId)
                          .firstOrNull;
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                        itemCount:
                            state.messages.length + (state.isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == state.messages.length) {
                            return const _TypingBubble();
                          }
                          final message = state.messages[index];
                          return _MessageBubble(
                            message: message,
                            isRead: _isReadByPeers(
                              message,
                              state.messages,
                              conversation,
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.line, width: 1.5)),
              ),
              child: Row(
                children: [
                  AppIconButton(
                    icon: const Icon(Icons.add),
                    size: 42,
                    onPressed: () {},
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
                        controller: _draftController,
                        onSubmitted: (_) => _send(),
                        style: AppTextStyles.hint.copyWith(color: colors.ink),
                        decoration: InputDecoration(
                          hintText: 'Message',
                          hintStyle: AppTextStyles.hint.copyWith(
                            color: colors.ink3,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppIconButton(
                    icon: const Icon(Icons.arrow_upward),
                    filled: true,
                    borderColor: colors.ink,
                    size: 46,
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Only an actual read-message marker proves a read. `lastReadAt` is the
/// time of the read action, not the timestamp of the message read.
bool _isReadByPeers(
  MessageEntity message,
  List<MessageEntity> messages,
  ConversationEntity? conversation,
) {
  if (!message.fromMe ||
      message.status != MessageDeliveryStatus.sent ||
      conversation == null) {
    return false;
  }
  final peers = conversation.participants
      .where((peer) => peer.userId != message.senderId)
      .toList();
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isRead});
  final MessageEntity message;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final mine = message.fromMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: mine ? colors.yel : colors.surf,
                border: Border.all(
                  color: mine ? colors.ink : colors.line,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(mine ? 20 : 6),
                  bottomRight: Radius.circular(mine ? 6 : 20),
                ),
              ),
              child: Text(
                message.text,
                style: AppTextStyles.body.copyWith(
                  fontSize: 14.5,
                  color: mine ? colors.onYel : colors.ink,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeLabel(message.sentAt.toLocal()),
                  style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
                ),
                if (mine) ...[
                  const SizedBox(width: 8),
                  _DeliveryMark(message: message, isRead: isRead),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
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
      MessageDeliveryStatus.failed => (
        Icons.error_outline,
        'Failed to send. Tap to retry',
      ),
      MessageDeliveryStatus.sent =>
        isRead ? (Icons.done_all, 'Read') : (Icons.check, 'Sent'),
    };
    return Semantics(
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: message.status == MessageDeliveryStatus.failed
              ? () => context.read<ChatCubit>().retry(message)
              : null,
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

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surf,
          border: Border.all(color: colors.line, width: 1.5),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.ink3,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
