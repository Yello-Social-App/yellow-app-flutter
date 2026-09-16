import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/conversation_entity.dart';
import '../entities/message_entity.dart';

/// A cursor page of conversations. `nextCursor` is opaque — pass it back
/// verbatim; when it is null there is nothing older to fetch.
class ConversationsPage {
  const ConversationsPage({required this.conversations, this.nextCursor});

  final List<ConversationEntity> conversations;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

/// A cursor page of messages, always oldest → newest.
class MessagesPage {
  const MessagesPage({required this.messages, this.nextCursor});

  final List<MessageEntity> messages;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

abstract interface class ChatRepository {
  Future<Either<Failure, ConversationsPage>> getConversations({String? cursor});
  Future<Either<Failure, ConversationEntity>> getConversation(String conversationId);

  /// Opens (or returns the existing) DIRECT conversation with [peerId] —
  /// the entry point from a profile's "Message" button.
  Future<Either<Failure, ConversationEntity>> startDirect(String peerId);

  Future<Either<Failure, ConversationEntity>> startGroup({
    required String title,
    required List<String> memberIds,
  });

  Future<Either<Failure, MessagesPage>> getMessages(String conversationId, {String? cursor});

  /// [clientId] is the caller's idempotency key — generate it once per
  /// composed message and reuse it on retry so a timeout cannot duplicate
  /// the message. See [MessageEntity.clientId].
  Future<Either<Failure, MessageEntity>> sendMessage({
    required String conversationId,
    required String body,
    required String clientId,
  });

  Future<Either<Failure, Unit>> markRead({
    required String conversationId,
    required String messageId,
  });

  /// Live events for one conversation.
  ///
  /// Until the WebSocket client lands this is an empty stream: history and
  /// sending work over HTTP, but another person's message will not appear
  /// until the page is reopened. It is deliberately *not* a polling loop.
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

/// Someone read up to [messageId] — drives the "seen" marker.
class MessagesRead extends ChatEvent {
  const MessagesRead({required this.userId, required this.messageId});
  final String userId;
  final String messageId;
}
