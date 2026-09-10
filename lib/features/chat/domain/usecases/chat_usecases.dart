import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/conversation_entity.dart';
import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

class GetConversationsUseCase implements UseCase<List<ConversationEntity>, NoParams> {
  GetConversationsUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, List<ConversationEntity>>> call(NoParams params) => _repository.getConversations();
}

class GetMessagesUseCase implements UseCase<List<MessageEntity>, String> {
  GetMessagesUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, List<MessageEntity>>> call(String conversationId) =>
      _repository.getMessages(conversationId);
}

class SendMessageParams extends Equatable {
  const SendMessageParams({required this.conversationId, required this.text});
  final String conversationId;
  final String text;

  @override
  List<Object?> get props => [conversationId, text];
}

class SendMessageUseCase implements UseCase<MessageEntity, SendMessageParams> {
  SendMessageUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, MessageEntity>> call(SendMessageParams params) {
    final clean = InputSanitizer.sanitizeText(params.text, maxLength: 2000);
    if (clean.isEmpty) return Future.value(const Left(ValidationFailure('Message cannot be empty.')));
    return _repository.sendMessage(params.conversationId, clean);
  }
}
