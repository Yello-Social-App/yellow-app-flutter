import 'dart:async';

import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart' show ChatEvent, TypingChanged, MessageArrived;

/// Entirely local — see `ChatRepository`'s doc for why (no backend
/// endpoint exists). Seeded with the Yello Mobile v2 design source's demo
/// conversations/messages; a `sendMessage` gets a simulated typing-then-reply
/// a couple seconds later, the same beat the mockup scripted.
class ChatLocalDataSource {
  final _now = DateTime.now();
  final _controllers = <String, StreamController<ChatEvent>>{};

  late final List<ConversationEntity> _conversations = [
    ConversationEntity(
      id: 'c-elena',
      name: 'Elena Rodriguez',
      avatarSeed: 2,
      isOnline: true,
      lastMessagePreview: 'Sent you the mobile layout ✓',
      lastMessageAt: _now.subtract(const Duration(minutes: 13)),
      unreadCount: 2,
    ),
    ConversationEntity(
      id: 'c-studio-nine',
      name: 'Studio Nine',
      avatarSeed: 0,
      lastMessagePreview: 'Marcus: kickoff moved to Thursday',
      lastMessageAt: _now.subtract(const Duration(hours: 5)),
      unreadCount: 4,
    ),
    ConversationEntity(
      id: 'c-maya',
      name: 'Maya Lin',
      avatarSeed: 1,
      isOnline: true,
      lastMessagePreview: 'You: let the space breathe',
      lastMessageAt: _now.subtract(const Duration(days: 1)),
    ),
    ConversationEntity(
      id: 'c-david',
      name: 'David Kim',
      avatarSeed: 4,
      lastMessagePreview: 'Voice note · 0:42',
      lastMessageAt: _now.subtract(const Duration(days: 1, hours: 3)),
    ),
    ConversationEntity(
      id: 'c-sarah',
      name: 'Sarah Jenkins',
      avatarSeed: 1,
      isOnline: true,
      lastMessagePreview: 'Reacted ♥ to your story',
      lastMessageAt: _now.subtract(const Duration(days: 3)),
    ),
    ConversationEntity(
      id: 'c-light-club',
      name: 'Light Club',
      avatarSeed: 5,
      lastMessagePreview: 'Elena: same time next week?',
      lastMessageAt: _now.subtract(const Duration(days: 4)),
    ),
  ];

  late final Map<String, List<MessageEntity>> _messages = {
    'c-elena': [
      MessageEntity(
        id: 'm1',
        conversationId: 'c-elena',
        fromMe: false,
        text: 'Hey! Are we still on for the light study review this afternoon? I have the new '
            'prototypes ready.',
        sentAt: _now.subtract(const Duration(hours: 2, minutes: 3)),
      ),
      MessageEntity(
        id: 'm2',
        conversationId: 'c-elena',
        fromMe: true,
        text: "Yes — let's aim for 2. Excited to see how you handled the stairwell sequence.",
        sentAt: _now.subtract(const Duration(hours: 2)),
      ),
      MessageEntity(
        id: 'm3',
        conversationId: 'c-elena',
        fromMe: false,
        text: 'I leaned all the way into the white-space-first idea. It breathes now.',
        sentAt: _now.subtract(const Duration(hours: 1, minutes: 58)),
      ),
      MessageEntity(
        id: 'm4',
        conversationId: 'c-elena',
        fromMe: true,
        text: 'Can you send a sneak peek of the mobile layout? A screenshot is fine.',
        sentAt: _now.subtract(const Duration(hours: 1, minutes: 55)),
      ),
    ],
  };

  Future<List<ConversationEntity>> getConversations() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final list = [..._conversations]..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return list;
  }

  Future<List<MessageEntity>> getMessages(String conversationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_messages[conversationId] ?? const []);
  }

  Future<MessageEntity> sendMessage(String conversationId, String text) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final message = MessageEntity(
      id: 'm-${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      fromMe: true,
      text: text,
      sentAt: DateTime.now(),
    );
    _messages.putIfAbsent(conversationId, () => []).add(message);
    _updateConversationPreview(conversationId, text);
    _scheduleReply(conversationId);
    return message;
  }

  void _updateConversationPreview(String conversationId, String preview) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;
    _conversations[index] = _conversations[index].copyWith(
      lastMessagePreview: 'You: $preview',
      lastMessageAt: DateTime.now(),
    );
  }

  void _scheduleReply(String conversationId) {
    final controller = _controllers[conversationId];
    if (controller == null) return;
    controller.add(const TypingChanged(true));
    Timer(const Duration(milliseconds: 1900), () {
      if (controller.isClosed) return;
      const replyText = 'Just sent it over — check the second frame.';
      final reply = MessageEntity(
        id: 'm-${DateTime.now().microsecondsSinceEpoch}',
        conversationId: conversationId,
        fromMe: false,
        text: replyText,
        sentAt: DateTime.now(),
      );
      _messages.putIfAbsent(conversationId, () => []).add(reply);
      _updateConversationPreview(conversationId, replyText);
      controller
        ..add(const TypingChanged(false))
        ..add(MessageArrived(reply));
    });
  }

  Stream<ChatEvent> watchEvents(String conversationId) {
    final controller =
        _controllers.putIfAbsent(conversationId, () => StreamController<ChatEvent>.broadcast());
    return controller.stream;
  }
}
