import 'dart:convert';

import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/group_invite_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

/// Turns one `yello-chat` socket frame — `{ "event": string, "data": object }`
/// — into the [ChatEvent] the cubit understands.
///
/// This is the whole server → client vocabulary from the service's frame
/// reference, kept apart from the transport (`ChatSocket`) so it stays a
/// pure, unit-testable function of one frame.
///
/// An unrecognised or malformed frame decodes to `null`, which the caller
/// drops. That is the documented contract ("unknown frames can be ignored
/// safely"), and it means a new event type the server starts sending never
/// takes a live conversation down.
abstract final class ChatFrameDecoder {
  /// [viewerId] is threaded into the message mappers for `fromMe` /
  /// `reactedByMe` / `forMe`, exactly as on the HTTP path.
  static ChatEvent? decode(String raw, {String? viewerId}) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map<String, dynamic>) return null;
    return decodeFrame(json, viewerId: viewerId);
  }

  static ChatEvent? decodeFrame(Map<String, dynamic> frame, {String? viewerId}) {
    final event = frame['event'];
    final data = frame['data'];
    if (event is! String || data is! Map<String, dynamic>) return null;

    try {
      return switch (event) {
        'message.new' || 'message.sent' => _message(data, viewerId: viewerId, wrap: MessageArrived.new),
        'message.updated' => _message(data, viewerId: viewerId, wrap: MessageUpdated.new),
        'message.deleted' => MessageDeleted(
            conversationId: data['conversationId'] as String,
            messageId: data['messageId'] as String,
            deletedAt: _date(data['deletedAt']) ?? DateTime.now(),
          ),
        'message.reactions' => MessageReactionsChanged(
            conversationId: data['conversationId'] as String,
            messageId: data['messageId'] as String,
            reactions: ReactionMapper.fromMessageReactions(data, viewerId: viewerId),
          ),
        'message.read' => MessagesRead(
            userId: data['userId'] as String,
            messageId: data['messageId'] as String,
          ),
        // The relayed typing frame's exact field names are not in the
        // published reference; `userId` plus an `isTyping`/`typing` flag
        // (absent meaning "started") covers the likely shapes. A frame
        // the server sends that this does not read shows up in the device
        // log through the error path in `ChatRepositoryImpl.watchEvents`.
        'typing' => TypingChanged(
            userId: data['userId'] as String? ?? data['senderId'] as String? ?? '',
            isTyping: data['isTyping'] as bool? ?? data['typing'] as bool? ?? true,
          ),
        'conversation.updated' => _conversationUpdated(data, viewerId: viewerId),
        'conversation.removed' => ConversationRemoved(
            conversationId: data['conversationId'] as String,
            reason: data['reason'] as String? ?? 'REMOVED',
          ),
        'group.invite.updated' => GroupInviteUpdated(
            inviteId: data['inviteId'] as String,
            conversationId: data['conversationId'] as String? ?? '',
            status: GroupInviteStatus.fromWire(data['status'] as String?),
          ),
        _ => null,
      };
    } on TypeError {
      // A required field missing or of the wrong type — treat the frame as
      // unknown rather than crash the listener.
      return null;
    }
  }

  /// `message.new` / `message.sent` / `message.updated` all carry
  /// `{ message }`; `message.sent` also echoes `ref`, which is irrelevant
  /// here — the HTTP response already confirmed the optimistic bubble.
  static ChatEvent? _message(
    Map<String, dynamic> data, {
    required String? viewerId,
    required ChatEvent Function(MessageEntity) wrap,
  }) {
    final raw = data['message'];
    if (raw is! Map<String, dynamic>) return null;
    return wrap(MessageMapper.fromJson(raw, viewerId: viewerId));
  }

  static ChatEvent? _conversationUpdated(Map<String, dynamic> data, {required String? viewerId}) {
    final raw = data['conversation'];
    if (raw is! Map<String, dynamic>) return null;
    // The frame puts `participants` beside `conversation`, not inside it;
    // fold them in so the entity is whole.
    final merged = {...raw, if (data['participants'] is List) 'participants': data['participants']};
    final change = data['change'];
    return ConversationUpdated(
      conversation: ConversationMapper.fromJson(merged, viewerId: viewerId),
      change: change is Map<String, dynamic>
          ? ConversationMapper.changeFromJson(change)
          : const ConversationChange(kind: ConversationChangeKind.unknown, actorId: ''),
    );
  }

  static DateTime? _date(dynamic raw) => raw is String ? DateTime.tryParse(raw) : null;
}
