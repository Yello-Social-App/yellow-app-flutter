import 'package:equatable/equatable.dart';

import 'post_entity.dart' show ReactionType;

/// Shaped after the backend's `CommentResponse`
/// (`GET/POST /api/v1/posts/{id}/comments`).
class CommentEntity extends Equatable {
  const CommentEntity({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorUsername,
    this.authorAvatarUrl,
    required this.content,
    required this.createdAt,
    this.parentCommentId,
    this.reactionCount = 0,
    this.viewerReaction,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorUsername;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;

  /// Non-null when this comment is a reply to another comment.
  final String? parentCommentId;
  final int reactionCount;
  final String? viewerReaction;

  bool get isReply => parentCommentId != null;

  /// The viewer's own reaction as a typed [ReactionType], or null if they
  /// haven't reacted (or reacted with a type this client doesn't know).
  ReactionType? get viewerReactionType => ReactionType.fromWire(viewerReaction);

  CommentEntity copyWith({int? reactionCount, Object? viewerReaction = _unset}) {
    return CommentEntity(
      id: id,
      postId: postId,
      authorId: authorId,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      content: content,
      createdAt: createdAt,
      parentCommentId: parentCommentId,
      reactionCount: reactionCount ?? this.reactionCount,
      viewerReaction:
          identical(viewerReaction, _unset) ? this.viewerReaction : viewerReaction as String?,
    );
  }

  @override
  List<Object?> get props => [id, content, reactionCount, viewerReaction];
}

const Object _unset = Object();
