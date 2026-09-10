import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/conversation_entity.dart';
import '../entities/message_entity.dart';

abstract interface class ChatRepository {
  Future<Either<Failure, List<ConversationEntity>>> getConversations();
  Future<Either<Failure, List<MessageEntity>>> getMessages(String conversationId);
  Future<Either<Failure, MessageEntity>> sendMessage(String conversationId, String text);

  /// A simulated reply arrives shortly after `sendMessage` — this streams
  /// those local, unprompted arrivals (and the typing indicator toggle
  /// preceding them) for [ChatCubit] to render.
  Stream<ChatEvent> watchEvents(String conversationId);
}

sealed class ChatEvent {
  const ChatEvent();
}

class TypingChanged extends ChatEvent {
  const TypingChanged(this.isTyping);
  final bool isTyping;
}

class MessageArrived extends ChatEvent {
  const MessageArrived(this.message);
  final MessageEntity message;
}
