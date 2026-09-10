import '../../domain/entities/post_entity.dart';

/// JSON mapping for the backend's `PostResponse` schema exactly (field
/// names are the real wire names — no snake_case translation, this backend
/// is already camelCase).
class PostModel extends PostEntity {
  const PostModel({
    required super.id,
    required super.authorId,
    required super.authorUsername,
    super.authorAvatarUrl,
    required super.createdAt,
    required super.content,
    super.imageUrls,
    super.visibility,
    super.commentCount,
    super.repostCount,
    super.reactionCounts,
    super.viewerReaction,
    super.shareUrl,
    super.originalPost,
    super.savedByMe,
    super.repostedByMe,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>? ?? const {};
    final images = (json['images'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>()
      // `PostImageResponse` carries a `position` — sort defensively in
      // case the backend doesn't guarantee list order.
      ..sort((a, b) => (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
    final original = json['originalPost'] as Map<String, dynamic>?;

    return PostModel(
      id: json['id'] as String,
      authorId: author['id'] as String? ?? '',
      authorUsername: author['username'] as String? ?? 'unknown',
      authorAvatarUrl: author['avatarUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      content: json['content'] as String? ?? '',
      imageUrls: images.map((i) => i['url'] as String).toList(),
      visibility: PostVisibility.fromWire(json['visibility'] as String?),
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      repostCount: (json['repostCount'] as num?)?.toInt() ?? 0,
      reactionCounts: (json['reactionCounts'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ),
      viewerReaction: json['viewerReaction'] as String?,
      shareUrl: json['shareUrl'] as String?,
      originalPost: original == null ? null : PostModel.fromJson(original),
    );
  }
}
