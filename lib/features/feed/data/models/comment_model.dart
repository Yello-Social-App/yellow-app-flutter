import '../../domain/entities/comment_entity.dart';

class CommentModel extends CommentEntity {
  const CommentModel({
    required super.id,
    required super.postId,
    required super.authorId,
    required super.authorUsername,
    super.authorAvatarUrl,
    required super.content,
    required super.createdAt,
    super.parentCommentId,
    super.reactionCount,
    super.viewerReaction,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>? ?? const {};
    return CommentModel(
      id: json['id'] as String,
      postId: json['postId'] as String? ?? '',
      authorId: author['id'] as String? ?? '',
      authorUsername: author['username'] as String? ?? 'unknown',
      authorAvatarUrl: author['avatarUrl'] as String?,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      parentCommentId: json['parentCommentId'] as String?,
      reactionCount: (json['reactionCount'] as num?)?.toInt() ?? 0,
      viewerReaction: json['viewerReaction'] as String?,
    );
  }

  /// Parses one top-level `CommentResponse` *and* flattens its nested
  /// `replies` (an array of full `CommentResponse` objects, per the
  /// `/posts/{id}/comments` schema) into the same flat list — the rest of
  /// this app (`PostDetailCubit`/`post_detail_page.dart`'s `_Loaded`) models
  /// comments as one flat list where a reply is just identified by its own
  /// `parentCommentId` (Facebook-style 2-level grouping), so this is where
  /// the backend's nested shape gets flattened to match. Without this, every
  /// reply the backend nests under a top-level comment is silently dropped —
  /// only the top-level comments in the page's `content` array would ever
  /// reach the UI.
  static List<CommentModel> withRepliesFromJson(Map<String, dynamic> json) {
    final replies = (json['replies'] as List<dynamic>?) ?? const [];
    return [
      CommentModel.fromJson(json),
      for (final reply in replies) CommentModel.fromJson(reply as Map<String, dynamic>),
    ];
  }
}
