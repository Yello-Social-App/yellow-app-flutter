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
}
