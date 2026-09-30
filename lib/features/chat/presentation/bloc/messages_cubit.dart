import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/chat_usecases.dart';

enum MessagesStatus { initial, loading, loaded, error }

class MessagesState extends Equatable {
  const MessagesState({
    this.status = MessagesStatus.initial,
    this.conversations = const [],
    this.errorMessage,
    this.nextCursor,
    this.isLoadingMore = false,
  });

  final MessagesStatus status;
  final List<ConversationEntity> conversations;
  final String? errorMessage;
  final String? nextCursor;
  final bool isLoadingMore;

  bool get hasMore => nextCursor != null;

  int get unreadTotal => conversations.fold(0, (a, c) => a + c.unreadCount);

  /// The people whose dot is currently green. Empty whenever nothing holds a
  /// presence lease (see [MessagesCubit.watchPresence]) or the socket is
  /// down — presence is live-only, and silence is not the same as offline.
  List<ConversationEntity> get onlineNow => conversations.where((c) => c.isOnline).toList();

  /// See `ChatState._unset` — `nextCursor: null` has to mean "no more
  /// pages", otherwise the inbox would keep requesting the last cursor.
  static const Object _unset = Object();

  MessagesState copyWith({
    MessagesStatus? status,
    List<ConversationEntity>? conversations,
    String? errorMessage,
    Object? nextCursor = _unset,
    bool? isLoadingMore,
  }) {
    return MessagesState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      errorMessage: errorMessage,
      nextCursor: identical(nextCursor, _unset) ? this.nextCursor : nextCursor as String?,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [status, conversations, errorMessage, nextCursor, isLoadingMore];
}

/// Owns the Inbox tab's conversation list — a long-lived singleton so the
/// list (and its unread counts) persists across tab switches.
///
/// It is also the write target for the chat and group screens:
/// [ChatCubit] calls [markConversationRead], [applyIncomingMessage] and
/// [applyDeletedMessage]; `GroupInfoCubit` calls [applyConversation] and
/// [removeConversation] — so opening, receiving, unsending, renaming or
/// leaving updates this list in place instead of forcing a refetch.
class MessagesCubit extends Cubit<MessagesState> {
  MessagesCubit(this._getConversations, this._repository) : super(const MessagesState());

  final GetConversationsUseCase _getConversations;

  /// For [watchPresence] alone. A socket stream has no result for a `UseCase`
  /// to carry, so it comes through the repository — the same call `ChatCubit`
  /// makes for `watchEvents`.
  final ChatRepository _repository;

  Future<void>? _refreshTask;
  bool _refreshAgain = false;
  int _generation = 0;

  /// Who is online, as last reported. Cubit-private rather than a state
  /// field: what the UI reads is [ConversationEntity.isOnline] on the rows
  /// themselves, and keeping the set here means presence cannot drift out of
  /// step with the rows it was applied to.
  Set<String> _onlineUserIds = const {};

  StreamSubscription<Set<String>>? _presenceSub;

  /// How many screens currently want live presence. Leases rather than a
  /// plain start/stop because two holders overlap by design: the Inbox
  /// branch, and a chat screen pushed over it (or deep-linked from another
  /// tab). Counting them means the socket survives the hand-off instead of
  /// closing and reconnecting between the two — see ADR-038.
  int _presenceLeases = 0;

  Future<void> load() async {
    if (state.status != MessagesStatus.initial) return;
    await refresh();
  }

  Future<void> refresh({bool queueIfLoading = false}) {
    if (isClosed) return Future.value();
    if (_refreshTask != null) {
      if (queueIfLoading) _refreshAgain = true;
      return Future.value();
    }
    _refreshAgain = true;
    return _refreshTask ??= _drainRefreshes().whenComplete(() => _refreshTask = null);
  }

  Future<void> _drainRefreshes() async {
    while (_refreshAgain && !isClosed) {
      _refreshAgain = false;
      await _refreshOnce();
    }
  }

  Future<void> _refreshOnce() async {
    final generation = ++_generation;
    emit(state.copyWith(status: MessagesStatus.loading, isLoadingMore: false));
    final result = await _getConversations(const CursorParams());
    if (isClosed || generation != _generation) return;
    result.fold(
      (failure) => emit(state.copyWith(status: MessagesStatus.error, errorMessage: failure.message)),
      (page) => emit(state.copyWith(
        status: MessagesStatus.loaded,
        conversations: _sorted(page.conversations),
        nextCursor: page.nextCursor,
        isLoadingMore: false,
      )),
    );
  }

  Future<void> loadMore() async {
    if (isClosed || state.status == MessagesStatus.loading || !state.hasMore || state.isLoadingMore) return;
    final generation = _generation;
    emit(state.copyWith(isLoadingMore: true));

    final result = await _getConversations(CursorParams(cursor: state.nextCursor));
    if (isClosed || generation != _generation) return;
    result.fold(
      (_) => emit(state.copyWith(isLoadingMore: false)),
      (page) => emit(state.copyWith(
        conversations: _sorted([...state.conversations, ...page.conversations]),
        nextCursor: page.nextCursor,
        isLoadingMore: false,
      )),
    );
  }

  /// Takes a lease on live presence, opening the chat socket if it is not
  /// already up. Balanced by [releasePresence] — the holder that acquires is
  /// the holder that releases.
  ///
  /// This is what turns the green dot on. It is leased rather than always-on
  /// because presence has no endpoint: the only way to know is an open
  /// WebSocket, and holding one from a tab that draws no dot would cost a
  /// connection for nothing (ADR-038, and ADR-010's reasoning about paying
  /// for signals nothing on screen can show).
  void watchPresence() {
    if (isClosed) return;
    if (++_presenceLeases > 1) return;
    _presenceSub = _repository.watchPresence().listen(_applyPresence);
  }

  /// Drops one lease; the last one out closes the watch and clears every dot,
  /// because with nothing listening this client no longer knows.
  void releasePresence() {
    if (_presenceLeases == 0 || --_presenceLeases > 0) return;
    unawaited(_presenceSub?.cancel());
    _presenceSub = null;
    _applyPresence(const {});
  }

  void _applyPresence(Set<String> onlineUserIds) {
    if (isClosed) return;
    _onlineUserIds = onlineUserIds;
    if (state.conversations.isEmpty) return;
    // Rows whose dot did not move come back as the same instance, so an
    // update about somebody the viewer has no conversation with is `==` the
    // current state and `emit` drops it.
    emit(state.copyWith(conversations: _withPresence(state.conversations)));
  }

  /// Folds the current presence set into the rows. A DM's dot is its peer's;
  /// a group has none — its avatar is the group's photo, so a dot there would
  /// claim something about a person that presence never said. A group gets a
  /// count of its online members instead, for the chat header's "Online".
  List<ConversationEntity> _withPresence(List<ConversationEntity> conversations) {
    if (_onlineUserIds.isEmpty && conversations.every((c) => !c.isOnline && c.onlineMemberCount == 0)) {
      return conversations;
    }
    return [
      for (final conversation in conversations) _withPeerPresence(conversation),
    ];
  }

  ConversationEntity _withPeerPresence(ConversationEntity conversation) {
    if (conversation.isGroup) {
      final count = conversation.participants
          .where((p) => p.userId != conversation.viewerId && _onlineUserIds.contains(p.userId))
          .length;
      return conversation.onlineMemberCount == count ? conversation : conversation.copyWith(onlineMemberCount: count);
    }
    final peerId = conversation.peer?.userId;
    final isOnline = peerId != null && _onlineUserIds.contains(peerId);
    return conversation.isOnline == isOnline ? conversation : conversation.copyWith(isOnline: isOnline);
  }

  /// Clears one row's unread badge — called when its chat screen opens, so
  /// the badge disappears without waiting for a refetch.
  void markConversationRead(String conversationId) {
    final index = state.conversations.indexWhere((c) => c.id == conversationId);
    if (index < 0 || state.conversations[index].unreadCount == 0) return;

    final next = [...state.conversations];
    next[index] = next[index].copyWith(unreadCount: 0);
    emit(state.copyWith(conversations: next));
  }

  /// Moves a conversation to the top with a fresh preview. Counts the
  /// message as unread only when it is someone else's — our own sent message
  /// updates the preview but must never raise our own badge.
  void applyIncomingMessage(MessageEntity message) {
    final index = state.conversations.indexWhere((c) => c.id == message.conversationId);
    if (index < 0) return;

    final current = state.conversations[index];
    final next = [...state.conversations];
    next[index] = current.copyWith(
      lastMessage: LastMessageEntity.fromMessage(message),
      lastMessageAtOrNull: message.createdAt,
      unreadCount: message.fromMe ? current.unreadCount : current.unreadCount + 1,
    );
    emit(state.copyWith(conversations: _sorted(next)));
  }

  /// A message was unsent. Only the row whose preview *is* that message
  /// changes — an older one is not what the inbox shows anyway.
  void applyDeletedMessage({required String conversationId, required String messageId}) {
    final index = state.conversations.indexWhere((c) => c.id == conversationId);
    if (index < 0) return;
    final current = state.conversations[index];
    final last = current.lastMessage;
    if (last == null || last.id != messageId || last.kind == LastMessageKind.deleted) return;

    final next = [...state.conversations];
    next[index] = current.copyWith(lastMessage: last.copyWith(kind: LastMessageKind.deleted));
    emit(state.copyWith(conversations: next));
  }

  /// Folds a fresh detail — rename, new photo, member change, or a group
  /// the viewer just joined — into the list. An existing row keeps its
  /// preview and unread count (`mergeDetail`); an unknown one is inserted,
  /// which is how an accepted invite shows up without a refetch.
  void applyConversation(ConversationEntity conversation) {
    final index = state.conversations.indexWhere((c) => c.id == conversation.id);
    final next = [...state.conversations];
    if (index < 0) {
      next.add(conversation);
    } else {
      next[index] = next[index].mergeDetail(conversation);
    }
    emit(state.copyWith(conversations: _sorted(next)));
  }

  /// The viewer left or was removed — the server answers 404 for it from
  /// now on, so it must not stay tappable in the list.
  void removeConversation(String conversationId) {
    if (!state.conversations.any((c) => c.id == conversationId)) return;
    emit(state.copyWith(conversations: state.conversations.where((c) => c.id != conversationId).toList()));
  }

  /// Newest activity first, with presence applied. Both on every write, so an
  /// arriving message reorders the inbox the way the server would have and a
  /// row the server just handed back keeps the dot it should have — a fetched
  /// conversation carries no presence of its own (the wire has no such field).
  List<ConversationEntity> _sorted(List<ConversationEntity> conversations) {
    final next = _withPresence([...conversations]);
    next.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return next;
  }

  /// Same reasoning as `FeedCubit.reset()` — drops this long-lived
  /// singleton back to its initial state on a signed-in-identity change.
  /// Presence goes with it: the ids belonged to the socket the previous
  /// session authenticated. The leases do not — whoever holds one still has
  /// its screen open — so the watch itself is left running and simply
  /// repopulates once the new session's socket comes up.
  void reset() {
    _generation++;
    _refreshAgain = false;
    _onlineUserIds = const {};
    emit(const MessagesState());
  }

  @override
  Future<void> close() {
    unawaited(_presenceSub?.cancel());
    _presenceSub = null;
    return super.close();
  }
}
