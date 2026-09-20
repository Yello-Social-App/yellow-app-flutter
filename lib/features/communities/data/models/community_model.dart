import '../../domain/entities/community_entity.dart';

/// JSON mapping for the backend's `Community` schema. Field names are the
/// real wire names — this backend is already camelCase, so there is no
/// snake_case translation step anywhere in this feature.
class CommunityModel extends CommunityEntity {
  const CommunityModel({
    required super.id,
    required super.slug,
    required super.name,
    required super.tagline,
    required super.description,
    required super.emoji,
    super.tags,
    super.rules,
    super.memberCount,
    super.onlineCount,
    required super.createdAt,
    super.isMember,
  });

  factory CommunityModel.fromJson(Map<String, dynamic> json) => CommunityModel(
    id: json['id'] as String,
    slug: json['slug'] as String,
    name: json['name'] as String? ?? '',
    tagline: json['tagline'] as String? ?? '',
    description: json['description'] as String? ?? '',
    emoji: json['emoji'] as String? ?? '💬',
    tags: stringList(json['tags']),
    rules: stringList(json['rules']),
    memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
    // Genuinely nullable on the wire (no presence tracking) — kept null
    // rather than coerced to 0, which would render as "0 online".
    onlineCount: (json['onlineCount'] as num?)?.toInt(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    isMember: json['isMember'] as bool? ?? false,
  );

  /// Reads a wire string array defensively: a single non-string entry degrades
  /// to being skipped instead of throwing and taking the whole list down.
  static List<String> stringList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is String && item.isNotEmpty) item,
    ];
  }
}

/// `CommunitySummary` — the nested reference on every `CommunityPost`.
class CommunitySummaryModel extends CommunitySummaryEntity {
  const CommunitySummaryModel({required super.slug, required super.name, required super.emoji});

  factory CommunitySummaryModel.fromJson(Map<String, dynamic> json) => CommunitySummaryModel(
    slug: json['slug'] as String? ?? '',
    name: json['name'] as String? ?? '',
    emoji: json['emoji'] as String? ?? '💬',
  );
}
