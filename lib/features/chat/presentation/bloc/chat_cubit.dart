import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/chat_usecases.dart';

enum ChatStatus { loading, loaded, error }

class ChatState extends Equatable {
  const ChatState({
    this.status = ChatStatus.loading,
    this.messages = const [],
    this.isTyping = false,
    this.errorMessage,
  });

  final ChatStatus status;
  final List<MessageEntity> messages;
  final bool isTyping;
  final String? errorMessage;

  ChatState copyWith({
    ChatStatus? status,
    List<MessageEntity>? messages,
    bool? isTyping,
    String? errorMessage,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, messages, isTyping, errorMessage];
}

class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required this.conversationId,
    required GetMessagesUseCase getMessages,
    required SendMessageUseCase sendMessage,
    required ChatRepository repository,
  })  : _getMessages = getMessages,
        _sendMessage = sendMessage,
        _repository = repository,
        super(const ChatState());

  final String conversationId;
  final GetMessagesUseCase _getMessages;
  final SendMessageUseCase _sendMessage;
  final ChatRepository _repository;
  StreamSubscription<ChatEvent>? _sub;

  Future<void> load() async {
    final result = await _getMessages(conversationId);
    result.fold(
      (failure) => emit(state.copyWith(status: ChatStatus.error, errorMessage: failure.message)),
      (messages) => emit(state.copyWith(status: ChatStatus.loaded, messages: messages)),
    );
    _sub = _repository.watchEvents(conversationId).listen((event) {
      switch (event) {
        case TypingChanged(:final isTyping):
          emit(state.copyWith(isTyping: isTyping));
        case MessageArrived(:final message):
          emit(state.copyWith(messages: [...state.messages, message]));
      }
    });
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    final result = await _sendMessage(SendMessageParams(conversationId: conversationId, text: text));
    result.fold((_) {}, (message) {
      emit(state.copyWith(messages: [...state.messages, message]));
    });
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
