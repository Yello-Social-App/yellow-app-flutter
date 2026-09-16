import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
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

  /// Presence arrives on the `presence` WebSocket frame; with no socket
  /// connected yet every conversation reports offline, so this is empty
  /// rather than wrong.
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
/// It is also the write target for the chat screen: [ChatCubit] calls
/// [markConversationRead] and [applyIncomingMessage] so opening or receiving
/// a message updates this list in place instead of forcing a refetch.
class MessagesCubit extends Cubit<MessagesState> {
  MessagesCubit(this._getConversations) : super(const MessagesState());

  final GetConversationsUseCase _getConversations;

  Future<void> load() async {
    if (state.status == MessagesStatus.loaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    emit(state.copyWith(status: MessagesStatus.loading));
    final result = await _getConversations(const CursorParams());
    result.fold(
      (failure) => emit(state.copyWith(status: MessagesStatus.error, errorMessage: failure.message)),
      (page) => emit(state.copyWith(
        status: MessagesStatus.loaded,
        conversations: _sorted(page.conversations),
        nextCursor: page.nextCursor,
      )),
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true));

    final result = await _getConversations(CursorParams(cursor: state.nextCursor));
    result.fold(
      (_) => emit(state.copyWith(isLoadingMore: false)),
      (page) => emit(state.copyWith(
        conversations: _sorted([...state.conversations, ...page.conversations]),
        nextCursor: page.nextCursor,
        isLoadingMore: false,
      )),
    );
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
      lastMessage: LastMessageEntity(
        id: message.id,
        senderId: message.senderId,
        body: message.body,
        createdAt: message.createdAt,
      ),
      lastMessageAtOrNull: message.createdAt,
      unreadCount: message.fromMe ? current.unreadCount : current.unreadCount + 1,
    );
    emit(state.copyWith(conversations: _sorted(next)));
  }

  /// Newest activity first. Applied on every write so an arriving message
  /// reorders the inbox the way the server would have.
  List<ConversationEntity> _sorted(List<ConversationEntity> conversations) {
    final next = [...conversations];
    next.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return next;
  }

  /// Same reasoning as `FeedCubit.reset()` — drops this long-lived
  /// singleton back to its initial state on a signed-in-identity change.
  void reset() => emit(const MessagesState());
}
