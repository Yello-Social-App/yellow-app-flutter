import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/usecases/chat_usecases.dart';

enum MessagesStatus { initial, loading, loaded, error }

class MessagesState extends Equatable {
  const MessagesState({
    this.status = MessagesStatus.initial,
    this.conversations = const [],
    this.errorMessage,
  });

  final MessagesStatus status;
  final List<ConversationEntity> conversations;
  final String? errorMessage;

  int get unreadTotal => conversations.fold(0, (a, c) => a + c.unreadCount);
  List<ConversationEntity> get onlineNow => conversations.where((c) => c.isOnline).toList();

  MessagesState copyWith({
    MessagesStatus? status,
    List<ConversationEntity>? conversations,
    String? errorMessage,
  }) {
    return MessagesState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, conversations, errorMessage];
}

/// Owns the Inbox tab's conversation list — a long-lived singleton so the
/// list (and its unread counts) persists across tab switches.
class MessagesCubit extends Cubit<MessagesState> {
  MessagesCubit(this._getConversations) : super(const MessagesState());

  final GetConversationsUseCase _getConversations;

  Future<void> load() async {
    if (state.status == MessagesStatus.loaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    emit(state.copyWith(status: MessagesStatus.loading));
    final result = await _getConversations(const NoParams());
    result.fold(
      (failure) => emit(state.copyWith(status: MessagesStatus.error, errorMessage: failure.message)),
      (conversations) => emit(state.copyWith(status: MessagesStatus.loaded, conversations: conversations)),
    );
  }
}
