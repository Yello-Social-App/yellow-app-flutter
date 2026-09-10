import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_local_datasource.dart';

/// No network round-trip involved (see `ChatLocalDataSource`'s doc), so
/// this skips the network-check + exception-translation dance the other
/// repositories do — there's no failure mode here besides a programming
/// error, which should surface as a real exception, not a swallowed
/// `Failure`.
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._local);

  final ChatLocalDataSource _local;

  @override
  Future<Either<Failure, List<ConversationEntity>>> getConversations() async =>
      Right(await _local.getConversations());

  @override
  Future<Either<Failure, List<MessageEntity>>> getMessages(String conversationId) async =>
      Right(await _local.getMessages(conversationId));

  @override
  Future<Either<Failure, MessageEntity>> sendMessage(String conversationId, String text) async =>
      Right(await _local.sendMessage(conversationId, text));

  @override
  Stream<ChatEvent> watchEvents(String conversationId) => _local.watchEvents(conversationId);
}
