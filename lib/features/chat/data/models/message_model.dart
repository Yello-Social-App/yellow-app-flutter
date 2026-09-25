import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/group_invite_entity.dart';
import '../../domain/entities/message_entity.dart';

/// Wire → domain mapping for `yello-chat`'s message payloads. As with
/// conversations, responses are bare objects — no `{success, data}` envelope.
abstract final class MessageMapper {
  /// [viewerId] decides [MessageEntity.fromMe], every reaction's
  /// `reactedByMe`, and an invite card's `forMe`; pass the signed-in user's
  /// id. When it is null nothing is treated as mine, which renders every
  /// bubble on the incoming side rather than mislabelling someone else's
  /// message as the viewer's own.
  static MessageEntity fromJson(Map<String, dynamic> json, {String? viewerId}) {
    final senderId = json['senderId'] as String? ?? '';
    return MessageEntity(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String? ?? '',
      senderId: senderId,
      clientId: json['clientId'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: _date(json['createdAt']) ?? DateTime.now(),
      fromMe: viewerId != null && senderId == viewerId,
      replyTo: _replyTo(json['replyTo']),
      attachments: AttachmentMapper.fromJsonList(json['attachments']),
      reactions: ReactionMapper.fromJsonList(json['reactions'], viewerId: viewerId),
      groupInvite: GroupInviteCardMapper.fromJsonOrNull(json['groupInvite'], viewerId: viewerId),
      storyReply: StoryReplyMapper.fromJsonOrNull(json['storyReply']),
      editedAt: _date(json['editedAt']),
      deletedAt: _date(json['deletedAt']),
    );
  }

  static ReplyPreviewEntity? _replyTo(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id'] as String?;
    if (id == null) return null;
    return ReplyPreviewEntity(
      id: id,
      senderId: raw['senderId'] as String? ?? '',
      body: raw['body'] as String? ?? '',
      hasAttachments: raw['hasAttachments'] as bool? ?? false,
      deleted: raw['deleted'] as bool? ?? false,
    );
  }

  static DateTime? _date(dynamic raw) => raw is String ? DateTime.tryParse(raw) : null;
}

abstract final class StoryReplyMapper {
  /// `Message.storyReply` — present on both the `message.new` frame and
  /// history, and null on every message that is not a story reply.
  static StoryReplyEntity? fromJsonOrNull(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final storyId = raw['storyId'] as String?;
    if (storyId == null || storyId.isEmpty) return null;
    return StoryReplyEntity(
      storyId: storyId,
      storyAuthorId: raw['storyAuthorId'] as String? ?? '',
      storyIsImage: raw['storyType'] == 'IMAGE',
      storyExpiresAt: raw['storyExpiresAt'] is String ? DateTime.tryParse(raw['storyExpiresAt'] as String) : null,
    );
  }
}

abstract final class AttachmentMapper {
  static AttachmentEntity fromJson(Map<String, dynamic> json) => AttachmentEntity(
        id: json['id'] as String,
        kind: AttachmentKind.fromWire(json['kind'] as String?),
        fileName: json['fileName'] as String? ?? '',
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        voice: _voiceFromJson(json['voice']),
        url: json['url'] as String?,
        urlExpiresAt: json['urlExpiresAt'] is String ? DateTime.tryParse(json['urlExpiresAt'] as String) : null,
      );

  /// `voice` is present only on a VOICE attachment. A `durationMs` of 0 or
  /// less means the server could not measure the audio, which leaves nothing
  /// to draw — the attachment then renders as a plain file rather than as a
  /// player stuck at 0:00.
  static VoiceMetaEntity? _voiceFromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final durationMs = (raw['durationMs'] as num?)?.toInt() ?? 0;
    if (durationMs <= 0) return null;
    final waveform = raw['waveform'];
    return VoiceMetaEntity(
      durationMs: durationMs,
      waveform: waveform is List
          ? [
              for (final value in waveform)
                if (value is num) value.toInt().clamp(0, 100),
            ]
          : const [],
    );
  }

  static List<AttachmentEntity> fromJsonList(dynamic raw) => raw is List
      ? raw.whereType<Map<String, dynamic>>().where((e) => e['id'] is String).map(fromJson).toList(growable: false)
      : const [];
}

abstract final class ReactionMapper {
  static ReactionEntity fromJson(Map<String, dynamic> json, {String? viewerId}) {
    final userIds = (json['userIds'] is List)
        ? (json['userIds'] as List).whereType<String>().toList(growable: false)
        : const <String>[];
    return ReactionEntity(
      emoji: json['emoji'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? userIds.length,
      userIds: userIds,
      reactedByMe: viewerId != null && userIds.contains(viewerId),
    );
  }

  static List<ReactionEntity> fromJsonList(dynamic raw, {String? viewerId}) => raw is List
      ? raw
          .whereType<Map<String, dynamic>>()
          .map((e) => fromJson(e, viewerId: viewerId))
          .where((r) => r.emoji.isNotEmpty)
          .toList(growable: false)
      : const [];

  /// `PUT`/`DELETE …/reaction` and the `message.reactions` frame all answer
  /// `{ messageId, reactions[] }`.
  static List<ReactionEntity> fromMessageReactions(Map<String, dynamic> json, {String? viewerId}) =>
      fromJsonList(json['reactions'], viewerId: viewerId);
}

abstract final class GroupInviteCardMapper {
  static GroupInviteCardEntity? fromJsonOrNull(dynamic raw, {String? viewerId}) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id'] as String?;
    if (id == null) return null;
    final inviteeId = raw['inviteeId'] as String? ?? '';
    return GroupInviteCardEntity(
      id: id,
      conversationId: raw['conversationId'] as String? ?? '',
      inviterId: raw['inviterId'] as String? ?? '',
      inviteeId: inviteeId,
      status: GroupInviteStatus.fromWire(raw['status'] as String?),
      title: raw['title'] as String?,
      memberCount: (raw['memberCount'] as num?)?.toInt() ?? 0,
      photoUrl: raw['photoUrl'] as String?,
      photoUrlExpiresAt: raw['photoUrlExpiresAt'] is String ? DateTime.tryParse(raw['photoUrlExpiresAt'] as String) : null,
      forMe: viewerId != null && inviteeId == viewerId,
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
