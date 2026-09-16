import '../../domain/entities/message_entity.dart';

/// Wire → domain mapping for `yello-chat`'s message payloads. As with
/// conversations, responses are bare objects — no `{success, data}` envelope.
abstract final class MessageMapper {
  /// [viewerId] decides [MessageEntity.fromMe]; pass the signed-in user's id.
  /// When it is null nothing is treated as mine, which renders every bubble
  /// on the incoming side rather than mislabelling someone else's message as
  /// the viewer's own.
  static MessageEntity fromJson(Map<String, dynamic> json, {String? viewerId}) {
    final senderId = json['senderId'] as String? ?? '';
    return MessageEntity(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String? ?? '',
      senderId: senderId,
      clientId: json['clientId'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: (json['createdAt'] is String ? DateTime.tryParse(json['createdAt'] as String) : null) ?? DateTime.now(),
      fromMe: viewerId != null && senderId == viewerId,
    );
  }
}

/// A cursor page of messages (`MessagePage`).
class MessagePage {
  const MessagePage({required this.items, this.nextCursor});

  /// Always sorted oldest → newest by this client, regardless of the order
  /// the server returned: the spec fixes the page shape but not its
  /// direction, and the transcript view appends downwards.
  final List<MessageEntity> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  static MessagePage fromJson(Map<String, dynamic> json, {String? viewerId}) {
    final raw = json['items'];
    final items = raw is List
        ? raw.whereType<Map<String, dynamic>>().map((e) => MessageMapper.fromJson(e, viewerId: viewerId)).toList()
        : <MessageEntity>[];
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return MessagePage(items: items, nextCursor: json['nextCursor'] as String?);
  }
}
