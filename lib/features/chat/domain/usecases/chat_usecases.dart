import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/conversation_entity.dart';
import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

class CursorParams extends Equatable {
  const CursorParams({this.cursor});
  final String? cursor;

  @override
  List<Object?> get props => [cursor];
}

class GetConversationsUseCase implements UseCase<ConversationsPage, CursorParams> {
  GetConversationsUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, ConversationsPage>> call(CursorParams params) =>
      _repository.getConversations(cursor: params.cursor);
}

class GetMessagesParams extends Equatable {
  const GetMessagesParams({required this.conversationId, this.cursor});
  final String conversationId;
  final String? cursor;

  @override
  List<Object?> get props => [conversationId, cursor];
}

class GetMessagesUseCase implements UseCase<MessagesPage, GetMessagesParams> {
  GetMessagesUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, MessagesPage>> call(GetMessagesParams params) =>
      _repository.getMessages(params.conversationId, cursor: params.cursor);
}

class SendMessageParams extends Equatable {
  const SendMessageParams({
    required this.conversationId,
    required this.text,
    required this.clientId,
  });

  final String conversationId;
  final String text;

  /// Idempotency key — generated once by the caller and reused on retry.
  final String clientId;

  @override
  List<Object?> get props => [conversationId, text, clientId];
}

class SendMessageUseCase implements UseCase<MessageEntity, SendMessageParams> {
  SendMessageUseCase(this._repository);
  final ChatRepository _repository;

  /// 20 000 is the server's own `SendMessage.body` ceiling; sanitising to
  /// the same number means the client never truncates something the API
  /// would have accepted, and never sends something it would reject.
  static const int maxBodyLength = 20000;

  @override
  Future<Either<Failure, MessageEntity>> call(SendMessageParams params) {
    final clean = InputSanitizer.sanitizeText(params.text, maxLength: maxBodyLength);
    if (clean.isEmpty) return Future.value(const Left(ValidationFailure('Message cannot be empty.')));
    return _repository.sendMessage(
      conversationId: params.conversationId,
      body: clean,
      clientId: params.clientId,
    );
  }
}

class MarkReadParams extends Equatable {
  const MarkReadParams({required this.conversationId, required this.messageId});
  final String conversationId;
  final String messageId;

  @override
  List<Object?> get props => [conversationId, messageId];
}

class MarkReadUseCase implements UseCase<Unit, MarkReadParams> {
  MarkReadUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(MarkReadParams params) =>
      _repository.markRead(conversationId: params.conversationId, messageId: params.messageId);
}

/// Opens or reuses the DIRECT conversation with another user — the entry
/// point from a profile's "Message" action.
class StartDirectConversationUseCase implements UseCase<ConversationEntity, String> {
  StartDirectConversationUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, ConversationEntity>> call(String peerId) => _repository.startDirect(peerId);
}
