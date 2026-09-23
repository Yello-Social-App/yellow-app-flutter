import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/participant_entity.dart';

/// Wire → domain mapping for `yello-chat`'s conversation payloads.
///
/// Note this service does **not** use yello-api's `{success, data,
/// timestamp}` envelope — responses are the object itself — so nothing here
/// goes through `ApiEnvelope`.
abstract final class ConversationMapper {
  /// Handles both `ConversationSummary` (list) and `ConversationDetail`
  /// (single): detail carries `participants` but no `lastMessage` or
  /// `unreadCount`, summary carries all three. Missing fields degrade to
  /// empty rather than throwing, so one added field server-side cannot take
  /// the inbox down.
  static ConversationEntity fromJson(Map<String, dynamic> json, {String? viewerId}) {
    final rawParticipants = json['participants'];
    final participants = rawParticipants is List
        ? rawParticipants
              .whereType<Map<String, dynamic>>()
              .map(ParticipantMapper.fromJson)
              .toList(growable: false)
        : const <ParticipantEntity>[];

    return ConversationEntity(
      id: json['id'] as String,
      type: ConversationType.fromWire(json['type'] as String?),
      title: json['title'] as String?,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: _date(json['createdAt']) ?? DateTime.now(),
      lastMessageAtOrNull: _date(json['lastMessageAt']),
      participants: participants,
      lastMessage: _lastMessage(json['lastMessage']),
      unreadCount: json['unreadCount'] as int? ?? 0,
      viewerId: viewerId,
      photoUrl: json['photoUrl'] as String?,
      photoUrlExpiresAt: _date(json['photoUrlExpiresAt']),
    );
  }

  /// `{ conversationId, participants[] }` — what the member and role routes
  /// answer with instead of a whole conversation.
  static List<ParticipantEntity> participantsFromJson(Map<String, dynamic> json) {
    final raw = json['participants'];
    return raw is List
        ? raw.whereType<Map<String, dynamic>>().map(ParticipantMapper.fromJson).toList(growable: false)
        : const <ParticipantEntity>[];
  }

  /// The `change` object on a `conversation.updated` frame.
  static ConversationChange changeFromJson(Map<String, dynamic> json) {
    final raw = json['userIds'];
    return ConversationChange(
      kind: ConversationChangeKind.fromWire(json['kind'] as String?),
      actorId: json['actorId'] as String? ?? '',
      userIds: raw is List ? raw.whereType<String>().toList(growable: false) : const [],
    );
  }

  static LastMessageEntity? _lastMessage(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id'] as String?;
    if (id == null) return null;
    final body = raw['body'] as String? ?? '';
    return LastMessageEntity(
      id: id,
      senderId: raw['senderId'] as String? ?? '',
      body: body,
      createdAt: _date(raw['createdAt']) ?? DateTime.now(),
      // The summary carries no attachments/invite/deleted flags, so an empty
      // body can only be reported as "not text" — see `LastMessageKind`.
      kind: body.isEmpty ? LastMessageKind.attachment : LastMessageKind.text,
    );
  }

  static DateTime? _date(dynamic raw) => raw is String ? DateTime.tryParse(raw) : null;
}

abstract final class ParticipantMapper {
  static ParticipantEntity fromJson(Map<String, dynamic> json) {
    return ParticipantEntity(
      userId: json['userId'] as String? ?? '',
      role: ParticipantRole.fromWire(json['role'] as String?),
      joinedAt: (json['joinedAt'] is String ? DateTime.tryParse(json['joinedAt'] as String) : null) ?? DateTime.now(),
      lastReadMessageId: json['lastReadMessageId'] as String?,
      lastReadAt: json['lastReadAt'] is String ? DateTime.tryParse(json['lastReadAt'] as String) : null,
    );
  }
}

/// A cursor page of conversations (`ConversationPage`).
class ConversationPage {
  const ConversationPage({required this.items, this.nextCursor});

  final List<ConversationEntity> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  static ConversationPage fromJson(Map<String, dynamic> json, {String? viewerId}) {
    final raw = json['items'];
    return ConversationPage(
      items: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map((e) => ConversationMapper.fromJson(e, viewerId: viewerId))
                .toList(growable: false)
          : const [],
      nextCursor: json['nextCursor'] as String?,
    );
  }
}
