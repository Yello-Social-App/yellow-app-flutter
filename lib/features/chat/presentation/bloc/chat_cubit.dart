import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/chat_usecases.dart';
import 'messages_cubit.dart';

enum ChatStatus { loading, loaded, error }

class ChatState extends Equatable {
  const ChatState({
    this.status = ChatStatus.loading,
    this.messages = const [],
    this.isTyping = false,
    this.errorMessage,
    this.nextCursor,
    this.isLoadingOlder = false,
  });

  final ChatStatus status;

  /// Oldest → newest, the order the transcript renders in.
  final List<MessageEntity> messages;
  final bool isTyping;
  final String? errorMessage;

  /// Cursor for the *older* page; null once history is exhausted.
  final String? nextCursor;
  final bool isLoadingOlder;

  bool get hasMore => nextCursor != null;

  /// Sentinel so `nextCursor: null` means "history exhausted" rather than
  /// "leave it alone". Without it the last page — which answers
  /// `nextCursor: null` — would keep [hasMore] true and [loadOlder] would
  /// refetch the same page forever.
  static const Object _unset = Object();

  ChatState copyWith({
    ChatStatus? status,
    List<MessageEntity>? messages,
    bool? isTyping,
    String? errorMessage,
    Object? nextCursor = _unset,
    bool? isLoadingOlder,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      errorMessage: errorMessage,
      nextCursor: identical(nextCursor, _unset) ? this.nextCursor : nextCursor as String?,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
    );
  }

  @override
  List<Object?> get props => [status, messages, isTyping, errorMessage, nextCursor, isLoadingOlder];
}

class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required this.conversationId,
    required GetMessagesUseCase getMessages,
    required SendMessageUseCase sendMessage,
    required MarkReadUseCase markRead,
    required ChatRepository repository,
    required MessagesCubit inbox,
  })  : _getMessages = getMessages,
        _sendMessage = sendMessage,
        _markRead = markRead,
        _repository = repository,
        _inbox = inbox,
        super(const ChatState());

  final String conversationId;
  final GetMessagesUseCase _getMessages;
  final SendMessageUseCase _sendMessage;
  final MarkReadUseCase _markRead;
  final ChatRepository _repository;

  /// The inbox list, so opening a conversation clears its unread badge and
  /// an arriving message updates its preview row — without either screen
  /// refetching. Same reasoning as the feed/detail sync.
  final MessagesCubit _inbox;

  StreamSubscription<ChatEvent>? _sub;
  bool _isLoading = false;
  bool _isRefreshing = false;

  /// Fetches new messages without clearing history or optimistic drafts.
  Future<void> refreshLatest() async {
    if (isClosed || _isLoading || _isRefreshing) return;
    _isRefreshing = true;
    try {
      final result = await _getMessages(GetMessagesParams(conversationId: conversationId));
      if (isClosed) return;
      result.fold((_) {}, (page) {
        final hadHistory = state.messages.isNotEmpty;
        final next = [...state.messages];
        for (final message in page.messages) {
          final index = next.indexWhere((existing) =>
              existing.id == message.id ||
              (message.clientId.isNotEmpty && existing.clientId == message.clientId));
          if (index < 0) {
            next.add(message);
          } else {
            next[index] = message;
          }
        }
        next.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        emit(state.copyWith(
          status: ChatStatus.loaded,
          messages: next,
          nextCursor: hadHistory ? state.nextCursor : page.nextCursor,
        ));
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
    final result = await _getMessages(GetMessagesParams(conversationId: conversationId));
    _isLoading = false;
    // `ChatPage` pushes this cubit and pops it on exit — backing out of a
    // conversation before this resolves closes it mid-flight. Without this
    // guard, `emit` below throws, and `_sub` (only assigned after this
    // point) would never get cancelled by `close()`, leaking the
    // subscription for the rest of the app's life.
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(status: ChatStatus.error, errorMessage: failure.message)),
      (page) {
        emit(state.copyWith(
          status: ChatStatus.loaded,
          messages: page.messages,
          nextCursor: page.nextCursor,
        ));
        _acknowledgeRead();
      },
    );

    _sub ??= _repository.watchEvents(conversationId).listen((event) {
      if (isClosed) return;
      switch (event) {
        case TypingChanged(:final isTyping):
          emit(state.copyWith(isTyping: isTyping));
        case MessageArrived(:final message):
          _upsert(message);
          _inbox.applyIncomingMessage(message);
          _acknowledgeRead();
        case MessagesRead():
          unawaited(_inbox.refresh(queueIfLoading: true));
      }
    });
  }

  /// Pulls the next older page. The transcript keeps its scroll position
  /// because older messages are prepended, never appended.
  Future<void> loadOlder() async {
    if (!state.hasMore || state.isLoadingOlder) return;
    emit(state.copyWith(isLoadingOlder: true));

    final result = await _getMessages(
      GetMessagesParams(conversationId: conversationId, cursor: state.nextCursor),
    );
    if (isClosed) return;

    result.fold(
      (_) => emit(state.copyWith(isLoadingOlder: false)),
      (page) => emit(state.copyWith(
        messages: [...page.messages, ...state.messages],
        nextCursor: page.nextCursor,
        isLoadingOlder: false,
      )),
    );
  }

  /// Shows the bubble immediately, then reconciles with the server's copy.
  ///
  /// The optimistic entry carries the same `clientId` the request does, so
  /// [_upsert] replaces it rather than leaving a duplicate — and because that
  /// id is the server's idempotency key, a retry of a request that actually
  /// succeeded returns the original message instead of double-posting.
  Future<void> send(String text) async {
    final draft = text.trim();
    if (draft.isEmpty) return;

    final clientId = newClientId();
    final optimistic = MessageEntity(
      id: 'local-$clientId',
      conversationId: conversationId,
      senderId: '',
      clientId: clientId,
      body: draft,
      createdAt: DateTime.now(),
      fromMe: true,
      status: MessageDeliveryStatus.sending,
    );
    _upsert(optimistic);

    final result = await _sendMessage(
      SendMessageParams(conversationId: conversationId, text: draft, clientId: clientId),
    );
    if (isClosed) return;

    result.fold(
      (_) => _replaceByClientId(clientId, optimistic.copyWith(status: MessageDeliveryStatus.failed)),
      (message) {
        _replaceByClientId(clientId, message);
        _inbox.applyIncomingMessage(message);
      },
    );
  }

  /// Re-sends a failed message under its original [MessageEntity.clientId],
  /// which is what makes the retry safe.
  Future<void> retry(MessageEntity message) async {
    if (message.status != MessageDeliveryStatus.failed) return;
    _replaceByClientId(message.clientId, message.copyWith(status: MessageDeliveryStatus.sending));

    final result = await _sendMessage(
      SendMessageParams(
        conversationId: conversationId,
        text: message.body,
        clientId: message.clientId,
      ),
    );
    if (isClosed) return;

    result.fold(
      (_) => _replaceByClientId(message.clientId, message.copyWith(status: MessageDeliveryStatus.failed)),
      (sent) => _replaceByClientId(message.clientId, sent),
    );
  }

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
    unawaited(_markRead(MarkReadParams(conversationId: conversationId, messageId: last.id)).then((result) {
      result.fold((_) {
        if (_lastAcknowledgedId == last.id) _lastAcknowledgedId = null;
      }, (_) {});
    }));
  }

  String? _lastAcknowledgedId;

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

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
