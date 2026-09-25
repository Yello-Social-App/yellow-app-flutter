import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/comment_entity.dart';
import '../entities/post_entity.dart';
import '../entities/reaction_breakdown.dart';
import '../entities/reactor_entity.dart';

/// One cursor-paginated page of the `/feed` endpoint.
class FeedPage {
  const FeedPage({required this.posts, required this.hasMore, this.nextCursor});
  final List<PostEntity> posts;
  final bool hasMore;
  final String? nextCursor;
}

/// One page-number-paginated page of a post's comments.
class CommentsPage {
  const CommentsPage({required this.comments, required this.hasMore});
  final List<CommentEntity> comments;
  final bool hasMore;
}

/// One page of `GET /reactions/{targetType}/{targetId}` — see
/// [FeedRepository.getReactors].
class ReactorsPage {
  const ReactorsPage({required this.reactors, required this.hasMore});
  final List<ReactorEntity> reactors;
  final bool hasMore;
}

/// Domain-facing contract for everything the Home/Feed tab needs. Backed by
/// the real `api.yello.cachewraith.com` API for posts/comments/reactions/
/// reposts. "Save" has no backend endpoint and is a device-local bookmark
/// (`BookmarksLocalDataSource`).
///
/// Stories are **not** here: they have their own resource and their own
/// contract (`StoryRepository`). The rail is the only place the two
/// features meet, and it holds both.
abstract interface class FeedRepository {
  Future<Either<Failure, FeedPage>> getFeed({String? cursor});
  Future<Either<Failure, PostEntity>> getPost(String postId);
  Future<Either<Failure, CommentsPage>> getComments(String postId, {int page = 0});
  Future<Either<Failure, CommentEntity>> addComment(String postId, String content, {String? parentCommentId});

  /// The quick-like tap: adds `LIKE` if the viewer hasn't reacted to [post],
  /// otherwise **removes** whatever reaction they already left — of any
  /// type, not just `LIKE`. Goes through the single
  /// `POST /reactions/{targetType}/{targetId}` toggle endpoint, echoing the
  /// viewer's current type so the server reads it as an un-react (see
  /// [reactToPost] for the type-switching path). Returns the post merged
  /// with the backend's authoritative reaction summary.
  Future<Either<Failure, PostEntity>> toggleLike(PostEntity post);

  /// Sets [post]'s reaction to [type] via the same POST toggle as
  /// [toggleLike] — sending the viewer's current reaction type again
  /// removes it, server-side. Returns the post merged with the backend's
  /// authoritative reaction summary.
  Future<Either<Failure, PostEntity>> reactToPost(PostEntity post, ReactionType type);

  /// Same toggle-by-type semantics as [reactToPost], against a comment.
  Future<Either<Failure, CommentEntity>> reactToComment(CommentEntity comment, ReactionType type);

  /// On-demand reaction breakdown for any target (`targetType` is `'POST'`
  /// or `'COMMENT'`) — independent of the viewer's own reaction, unlike the
  /// counts that ride along on [PostEntity]/[CommentEntity] already.
  Future<Either<Failure, ReactionBreakdown>> getReactionSummary({required String targetType, required String targetId});

  /// Paginated list of users who reacted to [targetType]/[targetId],
  /// optionally filtered to one [type] — the `reactors` operation on the
  /// same path [getReactionSummary] hits with `/summary` appended. Unlike
  /// that summary, this can be a genuinely long list, hence pagination.
  Future<Either<Failure, ReactorsPage>> getReactors({
    required String targetType,
    required String targetId,
    ReactionType? type,
    int page = 0,
  });

  /// Reposts [postId], optionally with added [content] — returns the newly
  /// created repost `PostEntity` (its `originalPost` is the source post).
  /// [visibility] sets the repost's *own* audience and defaults server-side
  /// when omitted; it does not change the original post's.
  Future<Either<Failure, PostEntity>> repost(
    String postId, {
    String? content,
    PostVisibility? visibility,
  });

  /// Device-local bookmark toggle — see class doc. Returns the new saved
  /// state.
  Future<Either<Failure, bool>> toggleSave(String postId);

  /// All bookmarked post ids (device-local) — used to hydrate the Profile
  /// "Saved" tab.
  Future<Either<Failure, List<String>>> getSavedPostIds();

  Future<Either<Failure, PostEntity>> createPost({
    required String content,
    required PostVisibility visibility,
    List<File> images = const [],
  });

  /// Edits a post you own (`PUT /posts/{id}`) — only what's passed changes.
  /// [images] appends new photos and [removeImageIds] drops existing ones by
  /// `PostEntity.images`' `id`; both may be sent in the same call.
  Future<Either<Failure, PostEntity>> updatePost(
    String postId, {
    String? content,
    PostVisibility? visibility,
    List<File> images = const [],
    List<String> removeImageIds = const [],
  });

  /// Deletes a post you own (`DELETE /posts/{id}`).
  Future<Either<Failure, void>> deletePost(String postId);

  /// Deletes a comment you own, or one on a post you own
  /// (`DELETE /comments/{id}`).
  Future<Either<Failure, void>> deleteComment(String commentId);

  /// Rewrites your own comment's text (`PUT /comments/{id}`). Unlike
  /// [deleteComment], this is the commenter's alone — a post author or
  /// moderator may remove someone's comment but not reword it.
  Future<Either<Failure, CommentEntity>> editComment(String commentId, String content);

  /// The post's canonical public URL.
  ///
  /// There is no `/posts/{id}/share-link` route — that path answers
  /// `404 RESOURCE_NOT_FOUND` on the live backend. Every `Post` already
  /// carries a ready-made `shareUrl`, so this reads that field, re-fetching
  /// the post when the caller only has an id. A caller that already holds
  /// the `PostEntity` should read [PostEntity.shareUrl] directly and skip
  /// the round-trip.
  Future<Either<Failure, String>> getShareLink(String postId);
}
