import 'package:equatable/equatable.dart';

import 'post_entity.dart' show ReactionType;

/// Shaped after the backend's `Comment` schema, which serves **both**
/// comment collections: `GET/POST /posts/{id}/comments` and
/// `GET/POST /community-posts/{id}/comments`. Exactly one of [postId] /
/// [communityPostId] is set on the wire, identifying which kind of parent
/// the comment hangs off — see [isOnCommunityPost].
class CommentEntity extends Equatable {
  const CommentEntity({
    required this.id,
    required this.postId,
    this.communityPostId,
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

  /// The parent `Post`'s id, or `''` when this comment belongs to a
  /// community post instead (in which case [communityPostId] is set).
  final String postId;

  /// The parent `CommunityPost`'s id — null for an ordinary feed post's
  /// comment. Added to the wire alongside the Communities endpoints; without
  /// it a comment fetched from `/community-posts/{id}/comments` had no way to
  /// name its own parent.
  final String? communityPostId;
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

  /// True when this comment hangs off a community post rather than a feed
  /// post — the two live on different endpoints, so anything that reloads or
  /// re-posts around a comment has to know which.
  bool get isOnCommunityPost => communityPostId != null;

  /// The viewer's own reaction as a typed [ReactionType], or null if they
  /// haven't reacted (or reacted with a type this client doesn't know).
  ReactionType? get viewerReactionType => ReactionType.fromWire(viewerReaction);

  CommentEntity copyWith({
    String? content,
    int? reactionCount,
    Object? viewerReaction = _unset,
  }) {
    return CommentEntity(
      id: id,
      postId: postId,
      communityPostId: communityPostId,
      authorId: authorId,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      content: content ?? this.content,
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
