import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/group_invite_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/chat_usecases.dart';
import 'messages_cubit.dart';

enum ChatStatus { loading, loaded, error }

class ChatState extends Equatable {
  const ChatState({
    this.status = ChatStatus.loading,
    this.messages = const [],
    this.typingUserIds = const {},
    this.isLive = false,
    this.errorMessage,
    this.nextCursor,
    this.isLoadingOlder = false,
    this.conversation,
    this.replyingTo,
    this.editing,
    this.pendingAttachments = const [],
    this.isUploading = false,
    this.busyMessageIds = const {},
    this.busyInviteIds = const {},
    this.actionError,
    this.wasRemoved = false,
  });

  final ChatStatus status;

  /// Oldest → newest, the order the transcript renders in.
  final List<MessageEntity> messages;

  /// Who is typing right now, by user id. Each entry expires on its own
  /// (`ChatCubit.typingTtl`) unless the server says they stopped or their
  /// message arrives first.
  final Set<String> typingUserIds;

  /// The socket is up and authenticated — messages, edits and typing
  /// arrive as they happen, and the screen polls history less often.
  final bool isLive;
  final String? errorMessage;

  /// Cursor for the *older* page; null once history is exhausted.
  final String? nextCursor;
  final bool isLoadingOlder;

  /// The conversation's own detail (title, photo, participants) — what the
  /// header shows and where group roles come from. Null until loaded; the
  /// page falls back to the inbox's row meanwhile.
  final ConversationEntity? conversation;

  /// The message the next send quotes, if the user tapped Reply.
  final MessageEntity? replyingTo;

  /// The message whose text is in the composer, if the user tapped Edit.
  /// Mutually exclusive with [replyingTo].
  final MessageEntity? editing;

  /// Uploaded, not yet sent — visible to the uploader only until their ids
  /// go out on a message. Cleared on send.
  final List<AttachmentEntity> pendingAttachments;
  final bool isUploading;

  /// Message ids with an edit / delete / reaction in flight — the bubble's
  /// actions are disabled meanwhile. The in-flight guard itself lives in
  /// the cubit; this is its projection for the UI.
  final Set<String> busyMessageIds;
  final Set<String> busyInviteIds;

  /// One-shot failure from a bubble action (edit, delete, react, join…),
  /// surfaced as a snackbar. Cleared on the next emit — every `copyWith`
  /// that does not set it drops it — so it never re-shows.
  final String? actionError;

  /// The viewer was removed from, or left, this group: the page pops.
  final bool wasRemoved;

  bool get hasMore => nextCursor != null;
  bool get isTyping => typingUserIds.isNotEmpty;
  bool get isComposingReply => replyingTo != null;
  bool get isEditing => editing != null;

  /// Sentinel so `nextCursor: null` means "history exhausted" rather than
  /// "leave it alone". Without it the last page — which answers
  /// `nextCursor: null` — would keep [hasMore] true and [loadOlder] would
  /// refetch the same page forever. The same trick clears [replyingTo] and
  /// [editing].
  static const Object _unset = Object();

  ChatState copyWith({
    ChatStatus? status,
    List<MessageEntity>? messages,
    Set<String>? typingUserIds,
    bool? isLive,
    String? errorMessage,
    Object? nextCursor = _unset,
    bool? isLoadingOlder,
    ConversationEntity? conversation,
    Object? replyingTo = _unset,
    Object? editing = _unset,
    List<AttachmentEntity>? pendingAttachments,
    bool? isUploading,
    Set<String>? busyMessageIds,
    Set<String>? busyInviteIds,
    String? actionError,
    bool? wasRemoved,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      typingUserIds: typingUserIds ?? this.typingUserIds,
      isLive: isLive ?? this.isLive,
      errorMessage: errorMessage,
      nextCursor: identical(nextCursor, _unset) ? this.nextCursor : nextCursor as String?,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      conversation: conversation ?? this.conversation,
      replyingTo: identical(replyingTo, _unset) ? this.replyingTo : replyingTo as MessageEntity?,
      editing: identical(editing, _unset) ? this.editing : editing as MessageEntity?,
      pendingAttachments: pendingAttachments ?? this.pendingAttachments,
      isUploading: isUploading ?? this.isUploading,
      busyMessageIds: busyMessageIds ?? this.busyMessageIds,
      busyInviteIds: busyInviteIds ?? this.busyInviteIds,
      actionError: actionError,
      wasRemoved: wasRemoved ?? this.wasRemoved,
    );
  }

  @override
  List<Object?> get props => [
    status,
    messages,
    typingUserIds,
    isLive,
    errorMessage,
    nextCursor,
    isLoadingOlder,
    conversation,
    replyingTo,
    editing,
    pendingAttachments,
    isUploading,
    busyMessageIds,
    busyInviteIds,
    actionError,
    wasRemoved,
  ];
}

class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required this.conversationId,
    required GetConversationUseCase getConversation,
    required GetMessagesUseCase getMessages,
    required SendMessageUseCase sendMessage,
    required EditMessageUseCase editMessage,
    required DeleteMessageUseCase deleteMessage,
    required ReactToMessageUseCase reactToMessage,
    required UploadAttachmentUseCase uploadAttachment,
    required RefreshAttachmentUseCase refreshAttachment,
    required AcceptGroupInviteUseCase acceptInvite,
    required DeclineGroupInviteUseCase declineInvite,
    required MarkReadUseCase markRead,
    required ChatRepository repository,
    required MessagesCubit inbox,
    DateTime Function() now = DateTime.now,
  }) : _getConversation = getConversation,
       _getMessages = getMessages,
       _sendMessage = sendMessage,
       _editMessage = editMessage,
       _deleteMessage = deleteMessage,
       _reactToMessage = reactToMessage,
       _uploadAttachment = uploadAttachment,
       _refreshAttachment = refreshAttachment,
       _acceptInvite = acceptInvite,
       _declineInvite = declineInvite,
       _markRead = markRead,
       _repository = repository,
       _inbox = inbox,
       _now = now,
       super(const ChatState());

  final String conversationId;
  final GetConversationUseCase _getConversation;
  final GetMessagesUseCase _getMessages;
  final SendMessageUseCase _sendMessage;
  final EditMessageUseCase _editMessage;
  final DeleteMessageUseCase _deleteMessage;
  final ReactToMessageUseCase _reactToMessage;
  final UploadAttachmentUseCase _uploadAttachment;
  final RefreshAttachmentUseCase _refreshAttachment;
  final AcceptGroupInviteUseCase _acceptInvite;
  final DeclineGroupInviteUseCase _declineInvite;
  final MarkReadUseCase _markRead;
  final ChatRepository _repository;

  /// The inbox list, so opening a conversation clears its unread badge and
  /// an arriving message updates its preview row — without either screen
  /// refetching. Same reasoning as the feed/detail sync.
  final MessagesCubit _inbox;

  /// Injectable clock, for the detail-refresh cadence in tests.
  final DateTime Function() _now;

  StreamSubscription<ChatEvent>? _sub;
  bool _isLoading = false;
  bool _isRefreshing = false;

  /// A peer's typing signal is forgotten after this much silence, in case
  /// the server never sends the "stopped" frame (a dropped socket, a
  /// closed app on their side).
  static const Duration typingTtl = Duration(seconds: 6);

  /// Our own signal: re-sent at most this often while the draft keeps
  /// changing, and followed by "stopped" after this much idle time.
  static const Duration typingRefresh = Duration(seconds: 3);
  static const Duration typingIdle = Duration(seconds: 3);

  final Map<String, Timer> _typingExpiry = {};
  Timer? _typingIdleTimer;
  DateTime? _typingSentAt;

  /// How often [refreshLatest] also re-fetches the conversation itself.
  /// The detail is what carries each participant's `lastReadMessageId` —
  /// the "Read" ticks — and any rename, photo or member change made by
  /// someone else. 10 s is the cadence the Inbox list used to be polled at
  /// while a chat was open, which was the only reason that list was fetched
  /// from here at all (ADR-010).
  static const Duration detailRefreshInterval = Duration(seconds: 10);
  DateTime? _detailFetchedAt;

  /// In-flight guards — the `FeedCubit._pendingReactions` shape. One set per
  /// kind of id: a message may have one edit/delete/reaction in flight, an
  /// invite one answer, an attachment one URL refresh.
  final Set<String> _pendingMessageIds = {};
  final Set<String> _pendingInviteIds = {};
  final Set<String> _pendingAttachmentRefreshes = {};

  /// Fetches new messages without clearing history or optimistic drafts.
  /// Server copies replace local ones by id, which is also how edits,
  /// deletes and reactions by *other* people reach this screen while the
  /// socket is not wired. Every [detailRefreshInterval] the conversation
  /// itself is re-fetched alongside, for read receipts and group changes.
  Future<void> refreshLatest() async {
    if (isClosed || _isLoading || _isRefreshing) return;
    _isRefreshing = true;
    try {
      final fetchedAt = _detailFetchedAt;
      final detailDue = fetchedAt == null || _now().difference(fetchedAt) >= detailRefreshInterval;
      if (detailDue) {
        _detailFetchedAt = _now();
        unawaited(
          _getConversation(conversationId).then((detail) {
            if (isClosed) return;
            detail.fold((_) {}, _applyDetail);
          }),
        );
      }
      final result = await _getMessages(GetMessagesParams(conversationId: conversationId));
      if (isClosed) return;
      result.fold((_) {}, (page) {
        final hadHistory = state.messages.isNotEmpty;
        final next = [...state.messages];
        for (final message in page.messages) {
          final index = next.indexWhere(
            (existing) =>
                existing.id == message.id || (message.clientId.isNotEmpty && existing.clientId == message.clientId),
          );
          if (index < 0) {
            next.add(message);
          } else {
            next[index] = message;
          }
        }
        next.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        emit(
          state.copyWith(
            status: ChatStatus.loaded,
            messages: next,
            nextCursor: hadHistory ? state.nextCursor : page.nextCursor,
          ),
        );
        _acknowledgeRead();
      });
    } finally {
      _isRefreshing = false;
    }
  }

  static final _random = Random();

  /// Idempotency key for one composed message: time-ordered, collision-safe
  /// enough for a single device, and well inside the server's 64-char limit.
  static String newClientId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${_random.nextInt(0x7fffffff).toRadixString(36)}';

  Future<void> load() async {
    if (_isLoading || isClosed) return;
    _isLoading = true;
    emit(state.copyWith(status: ChatStatus.loading));
    // The detail is needed for the header and for group roles, but a
    // failure there must not blank the transcript — it is fetched beside
    // the history and folded in only on success.
    final results = await Future.wait<dynamic>([
      _getMessages(GetMessagesParams(conversationId: conversationId)),
      _getConversation(conversationId),
    ]);
    _isLoading = false;
    // `ChatPage` pushes this cubit and pops it on exit — backing out of a
    // conversation before this resolves closes it mid-flight. Without this
    // guard, `emit` below throws, and `_sub` (only assigned after this
    // point) would never get cancelled by `close()`, leaking the
    // subscription for the rest of the app's life.
    if (isClosed) return;

    final pageResult = results[0] as Either<Failure, MessagesPage>;
    final detailResult = results[1] as Either<Failure, ConversationEntity>;
    final conversation = detailResult.fold((_) => null, (c) => c);
    if (conversation != null) {
      _detailFetchedAt = _now();
      _inbox.applyConversation(conversation);
    }
    pageResult.fold(
      (failure) =>
          emit(state.copyWith(status: ChatStatus.error, errorMessage: failure.message, conversation: conversation)),
      (page) {
        emit(
          state.copyWith(
            status: ChatStatus.loaded,
            messages: page.messages,
            nextCursor: page.nextCursor,
            conversation: conversation,
          ),
        );
        _acknowledgeRead();
      },
    );

    _sub ??= _repository.watchEvents(conversationId).listen(_onEvent);
  }

  /// Re-fetches the detail alone — the group screen calls this after a
  /// change it made so the header catches up without a full reload.
  Future<void> reloadConversation() async {
    final result = await _getConversation(conversationId);
    if (isClosed) return;
    result.fold((_) {}, _applyDetail);
  }

  /// A fresh detail goes to both places the page reads it from: this
  /// state, and the inbox row (which the header prefers, and which carries
  /// the participants the "Read" ticks are computed from).
  void _applyDetail(ConversationEntity conversation) {
    _detailFetchedAt = _now();
    emit(state.copyWith(conversation: conversation));
    _inbox.applyConversation(conversation);
  }

  void _onEvent(ChatEvent event) {
    if (isClosed) return;
    switch (event) {
      case TypingChanged(:final userId, :final isTyping):
        // The server may echo our own signal back; it is not news.
        if (userId.isEmpty || userId == state.conversation?.viewerId) return;
        _setPeerTyping(userId, isTyping);
      case LiveDeliveryChanged(:final isLive):
        if (!isLive) _clearPeerTyping();
        emit(state.copyWith(isLive: isLive));
      case MessageArrived(:final message):
        // Their message landing is the surest "stopped typing".
        if (!message.fromMe) _setPeerTyping(message.senderId, false);
        _upsert(message);
        _inbox.applyIncomingMessage(message);
        _acknowledgeRead();
      case MessageUpdated(:final message):
        _upsert(message);
      case MessageDeleted(:final messageId, :final deletedAt):
        _applyDeleted(messageId, deletedAt);
      case MessageReactionsChanged(:final messageId, :final reactions):
        _replaceById(messageId, (m) => m.copyWith(reactions: reactions));
      case MessagesRead():
        unawaited(_inbox.refresh(queueIfLoading: true));
      case ConversationUpdated(:final conversation):
        emit(state.copyWith(conversation: conversation));
        _inbox.applyConversation(conversation);
      case ConversationRemoved():
        _inbox.removeConversation(conversationId);
        emit(state.copyWith(wasRemoved: true));
      case GroupInviteUpdated(:final inviteId, :final status):
        _setInviteStatus(inviteId, status);
    }
  }

  /// Pulls the next older page. The transcript keeps its scroll position
  /// because older messages are prepended, never appended.
  Future<void> loadOlder() async {
    if (!state.hasMore || state.isLoadingOlder) return;
    emit(state.copyWith(isLoadingOlder: true));

    final result = await _getMessages(GetMessagesParams(conversationId: conversationId, cursor: state.nextCursor));
    if (isClosed) return;

    result.fold(
      (_) => emit(state.copyWith(isLoadingOlder: false)),
      (page) => emit(
        state.copyWith(
          messages: [...page.messages, ...state.messages],
          nextCursor: page.nextCursor,
          isLoadingOlder: false,
        ),
      ),
    );
  }

  // --- composing: reply / edit ---

  void startReply(MessageEntity message) {
    if (!message.canInteract) return;
    emit(state.copyWith(replyingTo: message, editing: null));
  }

  void cancelReply() => emit(state.copyWith(replyingTo: null));

  /// Puts the message's text in the composer. The page reads
  /// `state.editing.body` into the field; [submitEdit] takes it back.
  void startEdit(MessageEntity message) {
    if (!message.canEdit) return;
    emit(state.copyWith(editing: message, replyingTo: null));
  }

  void cancelEdit() => emit(state.copyWith(editing: null));

  /// Shows the bubble immediately, then reconciles with the server's copy.
  ///
  /// The optimistic entry carries the same `clientId` the request does, so
  /// [_upsert] replaces it rather than leaving a duplicate — and because that
  /// id is the server's idempotency key, a retry of a request that actually
  /// succeeded returns the original message instead of double-posting.
  ///
  /// When the composer is in edit mode this is an edit, not a send — the
  /// page has one submit action, so the fork lives here.
  Future<void> send(String text) async {
    if (state.isEditing) return submitEdit(text);

    final draft = text.trim();
    final attachments = state.pendingAttachments;
    if (draft.isEmpty && attachments.isEmpty) return;
    if (state.isUploading) return;

    _stopTyping();
    final replyTo = state.replyingTo;
    final clientId = newClientId();
    final optimistic = MessageEntity(
      id: 'local-$clientId',
      conversationId: conversationId,
      senderId: state.conversation?.viewerId ?? '',
      clientId: clientId,
      body: draft,
      createdAt: DateTime.now(),
      fromMe: true,
      status: MessageDeliveryStatus.sending,
      replyTo: replyTo?.toReplyPreview(),
      attachments: attachments,
    );
    emit(state.copyWith(replyingTo: null, pendingAttachments: const []));
    _upsert(optimistic);

    await _deliver(optimistic);
  }

  /// Re-sends a failed message under its original [MessageEntity.clientId],
  /// which is what makes the retry safe. The reply target and attachment
  /// ids ride along on the optimistic copy.
  Future<void> retry(MessageEntity message) async {
    if (message.status != MessageDeliveryStatus.failed) return;
    _replaceByClientId(message.clientId, message.copyWith(status: MessageDeliveryStatus.sending));
    await _deliver(message);
  }

  Future<void> _deliver(MessageEntity optimistic) async {
    final result = await _sendMessage(
      SendMessageParams(
        conversationId: conversationId,
        text: optimistic.body,
        clientId: optimistic.clientId,
        replyToMessageId: optimistic.replyTo?.id,
        attachmentIds: [for (final a in optimistic.attachments) a.id],
      ),
    );
    if (isClosed) return;

    result.fold(
      (failure) {
        _replaceByClientId(optimistic.clientId, optimistic.copyWith(status: MessageDeliveryStatus.failed));
        emit(state.copyWith(actionError: failure.message));
      },
      (message) {
        _replaceByClientId(optimistic.clientId, message);
        _inbox.applyIncomingMessage(message);
      },
    );
  }

  /// `PATCH` the text. Unchanged text is dropped here rather than sent —
  /// the server would no-op it anyway, without an `editedAt`.
  Future<void> submitEdit(String text) async {
    final editing = state.editing;
    if (editing == null) return;
    final draft = text.trim();
    if (draft == editing.body) {
      cancelEdit();
      return;
    }
    if (!_pendingMessageIds.add(editing.id)) return;
    emit(state.copyWith(editing: null, busyMessageIds: {...state.busyMessageIds, editing.id}));
    try {
      final result = await _editMessage(
        EditMessageParams(
          conversationId: conversationId,
          messageId: editing.id,
          text: draft,
          hasAttachments: editing.hasAttachments,
        ),
      );
      if (isClosed) return;
      result.fold((failure) => emit(state.copyWith(actionError: failure.message)), _upsert);
    } finally {
      _pendingMessageIds.remove(editing.id);
      if (!isClosed) emit(state.copyWith(busyMessageIds: {...state.busyMessageIds}..remove(editing.id)));
    }
  }

  /// Unsend for everyone. On success the bubble becomes a tombstone locally
  /// — the same shape the server keeps — and any reply quoting it flips to
  /// "Message deleted".
  Future<void> deleteMessage(MessageEntity message) async {
    if (!message.canDelete) return;
    if (!_pendingMessageIds.add(message.id)) return;
    emit(state.copyWith(busyMessageIds: {...state.busyMessageIds, message.id}));
    try {
      final result = await _deleteMessage(MessageRefParams(conversationId: conversationId, messageId: message.id));
      if (isClosed) return;
      result.fold((failure) => emit(state.copyWith(actionError: failure.message)), (_) {
        _applyDeleted(message.id, DateTime.now());
        _inbox.applyDeletedMessage(conversationId: conversationId, messageId: message.id);
      });
    } finally {
      _pendingMessageIds.remove(message.id);
      if (!isClosed) emit(state.copyWith(busyMessageIds: {...state.busyMessageIds}..remove(message.id)));
    }
  }

  /// One tap on an emoji: sets it, or — the same emoji the viewer already
  /// has — removes it. A different emoji replaces the old one server-side,
  /// so there is never more than one of the viewer's on a message.
  Future<void> toggleReaction(MessageEntity message, String emoji) async {
    if (!message.canInteract) return;
    if (!_pendingMessageIds.add(message.id)) return;
    emit(state.copyWith(busyMessageIds: {...state.busyMessageIds, message.id}));
    final remove = message.myReaction?.emoji == emoji;
    try {
      final result = await _reactToMessage(
        ReactToMessageParams(conversationId: conversationId, messageId: message.id, emoji: remove ? null : emoji),
      );
      if (isClosed) return;
      result.fold(
        (failure) => emit(state.copyWith(actionError: failure.message)),
        // The full list comes back — replace, don't merge.
        (reactions) => _replaceById(message.id, (m) => m.copyWith(reactions: reactions)),
      );
    } finally {
      _pendingMessageIds.remove(message.id);
      if (!isClosed) emit(state.copyWith(busyMessageIds: {...state.busyMessageIds}..remove(message.id)));
    }
  }

  // --- attachments ---

  /// Uploads one file and parks it in [ChatState.pendingAttachments] until
  /// the next send carries its id. Uploads are sequential on purpose: the
  /// composer shows one spinner, and the server's per-message cap is easier
  /// to hold when they land one at a time.
  Future<void> attachFile(File file) async {
    if (state.isUploading) return;
    if (state.pendingAttachments.length >= chatMessageMaxAttachments) {
      emit(state.copyWith(actionError: 'You can attach up to $chatMessageMaxAttachments files.'));
      return;
    }
    emit(state.copyWith(isUploading: true));
    final result = await _uploadAttachment(UploadAttachmentParams(conversationId: conversationId, file: file));
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isUploading: false, actionError: failure.message)),
      (attachment) =>
          emit(state.copyWith(isUploading: false, pendingAttachments: [...state.pendingAttachments, attachment])),
    );
  }

  /// A pending upload nobody else can see; dropping it locally is all there
  /// is to do — the service has no delete for an unsent attachment.
  void removePendingAttachment(String attachmentId) {
    emit(state.copyWith(pendingAttachments: state.pendingAttachments.where((a) => a.id != attachmentId).toList()));
  }

  /// A presigned URL expired (or failed to load): fetch a fresh one and
  /// swap it into whichever message carries the attachment. Guarded per id
  /// so an image widget erroring repeatedly cannot loop on the endpoint.
  Future<void> refreshAttachment(String attachmentId) async {
    if (!_pendingAttachmentRefreshes.add(attachmentId)) return;
    try {
      final result = await _refreshAttachment(attachmentId);
      if (isClosed) return;
      result.fold((failure) => appLogger.w('refreshAttachment($attachmentId) failed — ${failure.message}'), (fresh) {
        final next = [
          for (final m in state.messages)
            if (m.attachments.any((a) => a.id == attachmentId))
              m.copyWith(attachments: [for (final a in m.attachments) a.id == attachmentId ? fresh : a])
            else
              m,
        ];
        emit(state.copyWith(messages: next));
      });
    } finally {
      _pendingAttachmentRefreshes.remove(attachmentId);
    }
  }

  // --- invite cards ---

  /// Joins the group on the card. Returns it (hydrated) so the page can
  /// offer to open it; the inbox gains the row straight away.
  Future<ConversationEntity?> acceptInvite(GroupInviteCardEntity card) async {
    if (!card.canRespond) return null;
    if (!_pendingInviteIds.add(card.id)) return null;
    emit(state.copyWith(busyInviteIds: {...state.busyInviteIds, card.id}));
    try {
      final result = await _acceptInvite(card.id);
      if (isClosed) return null;
      return result.fold(
        (failure) {
          emit(state.copyWith(actionError: failure.message));
          return null;
        },
        (group) {
          _setInviteStatus(card.id, GroupInviteStatus.accepted);
          _inbox.applyConversation(group);
          return group;
        },
      );
    } finally {
      _pendingInviteIds.remove(card.id);
      if (!isClosed) emit(state.copyWith(busyInviteIds: {...state.busyInviteIds}..remove(card.id)));
    }
  }

  Future<void> declineInvite(GroupInviteCardEntity card) async {
    if (!card.canRespond) return;
    if (!_pendingInviteIds.add(card.id)) return;
    emit(state.copyWith(busyInviteIds: {...state.busyInviteIds, card.id}));
    try {
      final result = await _declineInvite(card.id);
      if (isClosed) return;
      result.fold(
        (failure) => emit(state.copyWith(actionError: failure.message)),
        (_) => _setInviteStatus(card.id, GroupInviteStatus.declined),
      );
    } finally {
      _pendingInviteIds.remove(card.id);
      if (!isClosed) emit(state.copyWith(busyInviteIds: {...state.busyInviteIds}..remove(card.id)));
    }
  }

  void _setInviteStatus(String inviteId, GroupInviteStatus status) {
    final next = [
      for (final m in state.messages)
        if (m.groupInvite?.id == inviteId) m.copyWith(groupInvite: m.groupInvite!.copyWith(status: status)) else m,
    ];
    emit(state.copyWith(messages: next));
  }

  // --- typing ---

  /// The composer's text changed. Sends "typing" at most every
  /// [typingRefresh] while the draft is non-empty, and "stopped" after
  /// [typingIdle] of silence, on send, or when the draft is cleared. Goes
  /// through the repository like [ChatRepository.watchEvents] does: a
  /// fire-and-forget socket frame has no result for a `UseCase` to carry.
  void onDraftChanged(String text) {
    if (text.trim().isEmpty) {
      _stopTyping();
      return;
    }
    final now = _now();
    final sentAt = _typingSentAt;
    if (sentAt == null || now.difference(sentAt) >= typingRefresh) {
      _typingSentAt = now;
      _repository.sendTyping(conversationId: conversationId, isTyping: true);
    }
    _typingIdleTimer?.cancel();
    _typingIdleTimer = Timer(typingIdle, _stopTyping);
  }

  void _stopTyping() {
    _typingIdleTimer?.cancel();
    _typingIdleTimer = null;
    if (_typingSentAt == null) return;
    _typingSentAt = null;
    _repository.sendTyping(conversationId: conversationId, isTyping: false);
  }

  void _setPeerTyping(String userId, bool isTyping) {
    _typingExpiry.remove(userId)?.cancel();
    final next = {...state.typingUserIds};
    if (isTyping) {
      next.add(userId);
      _typingExpiry[userId] = Timer(typingTtl, () {
        if (!isClosed) _setPeerTyping(userId, false);
      });
    } else {
      next.remove(userId);
    }
    if (next.length != state.typingUserIds.length || !next.containsAll(state.typingUserIds)) {
      emit(state.copyWith(typingUserIds: next));
    }
  }

  void _clearPeerTyping() {
    for (final timer in _typingExpiry.values) {
      timer.cancel();
    }
    _typingExpiry.clear();
    if (state.typingUserIds.isNotEmpty) emit(state.copyWith(typingUserIds: const {}));
  }

  // --- read marker ---

  /// Tells the server (and the inbox badge) we have seen the newest message.
  /// Finds the newest incoming message even when we have already replied.
  void _acknowledgeRead() {
    final last = state.messages.reversed
        .where((message) => !message.fromMe && message.status == MessageDeliveryStatus.sent)
        .firstOrNull;
    if (last == null) return;

    _inbox.markConversationRead(conversationId);
    if (_lastAcknowledgedId == last.id) return;
    _lastAcknowledgedId = last.id;
    unawaited(
      _markRead(MarkReadParams(conversationId: conversationId, messageId: last.id)).then((result) {
        result.fold((_) {
          if (_lastAcknowledgedId == last.id) _lastAcknowledgedId = null;
        }, (_) {});
      }),
    );
  }

  String? _lastAcknowledgedId;

  // --- list surgery ---

  /// Inserts or replaces by `clientId` first (an optimistic copy being
  /// confirmed), then by `id` (the same message echoed twice, e.g. the HTTP
  /// response racing a socket frame), keeping the list ordered by time.
  void _upsert(MessageEntity message) {
    final next = [...state.messages];

    final byClient = message.clientId.isEmpty
        ? -1
        : next.indexWhere((m) => m.clientId.isNotEmpty && m.clientId == message.clientId);
    final index = byClient >= 0 ? byClient : next.indexWhere((m) => m.id == message.id);

    if (index >= 0) {
      next[index] = message;
    } else {
      next.add(message);
      next.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    emit(state.copyWith(messages: next));
  }

  void _replaceByClientId(String clientId, MessageEntity message) {
    final next = [...state.messages];
    final index = next.indexWhere((m) => m.clientId == clientId);
    if (index < 0) return;
    next[index] = message;
    emit(state.copyWith(messages: next));
  }

  void _replaceById(String messageId, MessageEntity Function(MessageEntity) update) {
    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;
    final next = [...state.messages];
    next[index] = update(next[index]);
    emit(state.copyWith(messages: next));
  }

  /// The tombstone, plus `replyTo.deleted` on every reply that quotes it —
  /// exactly what the next history fetch would show.
  void _applyDeleted(String messageId, DateTime deletedAt) {
    final next = [
      for (final m in state.messages)
        if (m.id == messageId)
          m.asDeleted(deletedAt)
        else if (m.replyTo?.id == messageId && !(m.replyTo!.deleted))
          m.copyWith(replyTo: m.replyTo!.copyWith(deleted: true))
        else
          m,
    ];
    // Editing or replying to a message that just vanished is no longer
    // possible; drop that composer state too.
    emit(
      state.copyWith(
        messages: next,
        replyingTo: state.replyingTo?.id == messageId ? null : state.replyingTo,
        editing: state.editing?.id == messageId ? null : state.editing,
      ),
    );
  }

  @override
  Future<void> close() {
    _stopTyping();
    _clearPeerTyping();
    _sub?.cancel();
    return super.close();
  }
}
