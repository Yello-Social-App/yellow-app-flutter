import '../../domain/entities/story_entity.dart';

/// Wire → domain mapping for the `/v1/stories` resource. Every endpoint
/// returns the same `Story` shape, so [StoryMapper.fromJson] is the only
/// place that shape is read.
///
/// Mapping functions rather than `XModel extends XEntity` subclasses: a
/// `Story` is deeply nested (author, image) and read-only — nothing in this
/// feature ever serializes one back, so a model class would only add a
/// second name for the same value. `toJson` exists only for the two request
/// bodies, which are built in the data source from primitives.
abstract final class StoryMapper {
  static StoryEntity fromJson(Map<String, dynamic> json) => StoryEntity(
        id: json['id'] as String,
        author: StoryAuthorMapper.fromJson(json['author']),
        type: StoryType.fromWire(json['type'] as String?),
        text: json['text'] as String?,
        background: StoryBackground.fromWire(json['background'] as String?),
        image: StoryImageMapper.fromJsonOrNull(json['image']),
        visibility: StoryVisibility.fromWire(json['visibility'] as String?),
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
        // `expiresAt` is always `createdAt + 24h` server-side; deriving the
        // fallback from `createdAt` keeps a malformed row expiring at the
        // right moment instead of immediately.
        expiresAt: _date(json['expiresAt']) ??
            (_date(json['createdAt']) ?? DateTime.now()).add(const Duration(hours: 24)),
        isExpired: json['isExpired'] as bool? ?? false,
        isOwner: json['isOwner'] as bool? ?? false,
        isSeen: json['isSeen'] as bool? ?? false,
        viewCount: (json['viewCount'] as num?)?.toInt(),
      );

  /// The bare arrays `/stories/me` and `/users/{id}/stories` return, and the
  /// `stories` array inside a feed group.
  static List<StoryEntity> fromJsonList(dynamic raw) => raw is List
      ? raw.whereType<Map<String, dynamic>>().where((e) => e['id'] is String).map(fromJson).toList(growable: false)
      : const [];

  static DateTime? _date(dynamic raw) => raw is String ? DateTime.tryParse(raw) : null;
}

abstract final class StoryAuthorMapper {
  static StoryAuthorEntity fromJson(dynamic raw) {
    final json = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return StoryAuthorEntity(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

abstract final class StoryImageMapper {
  static StoryImageEntity? fromJsonOrNull(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final url = raw['url'] as String?;
    if (url == null || url.isEmpty) return null;
    return StoryImageEntity(
      url: url,
      width: (raw['width'] as num?)?.toInt() ?? 0,
      height: (raw['height'] as num?)?.toInt() ?? 0,
      urlExpiresAt: raw['urlExpiresAt'] is String ? DateTime.tryParse(raw['urlExpiresAt'] as String) : null,
    );
  }
}

/// `StoryFeedGroup` — one author's ring as `/stories/feed` returns it.
abstract final class StoryRingMapper {
  static StoryRingEntity fromJson(Map<String, dynamic> json) {
    final stories = StoryMapper.fromJsonList(json['stories']);
    return StoryRingEntity(
      author: StoryAuthorMapper.fromJson(json['author']),
      stories: stories,
      hasUnseen: json['hasUnseen'] as bool? ?? stories.any((s) => !s.isSeen),
      latestAt: StoryMapper._date(json['latestAt']) ??
          (stories.isEmpty
              ? DateTime.now()
              : stories.map((s) => s.createdAt).reduce((a, b) => a.isAfter(b) ? a : b)),
    );
  }
}

abstract final class StoryViewerMapper {
  static StoryViewerEntity fromJson(Map<String, dynamic> json) => StoryViewerEntity(
        user: StoryAuthorMapper.fromJson(json['user']),
        viewedAt: StoryMapper._date(json['viewedAt']) ?? DateTime.now(),
      );
}

/// The `202` body of `POST /stories/{id}/replies`.
abstract final class StoryReplyReceiptMapper {
  static StoryReplyReceipt fromJson(Map<String, dynamic> json) => StoryReplyReceipt(
        storyId: json['storyId'] as String? ?? '',
        recipientId: json['recipientId'] as String? ?? '',
        clientId: json['clientId'] as String? ?? '',
      );
}
