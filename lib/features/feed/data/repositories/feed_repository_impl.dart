import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/post_entity.dart';
import '../../domain/entities/reaction_breakdown.dart';
import '../../domain/repositories/feed_repository.dart';
import '../datasources/bookmarks_local_datasource.dart';
import '../datasources/feed_remote_datasource.dart';

class FeedRepositoryImpl implements FeedRepository {
  FeedRepositoryImpl(this._remote, this._bookmarks, this._networkInfo);

  final FeedRemoteDataSource _remote;
  final BookmarksLocalDataSource _bookmarks;
  final NetworkInfo _networkInfo;

  Future<Either<Failure, T>> _run<T>(Future<T> Function() body) async {
    if (!await _networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await body());
    } on AppException catch (e) {
      return Left(ErrorHandler.toFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<PostEntity> _withSaved(PostEntity post) async => post.copyWith(savedByMe: await _bookmarks.isSaved(post.id));

  @override
  Future<Either<Failure, FeedPage>> getFeed({String? cursor}) => _run(() async {
    final result = await _remote.getFeed(cursor: cursor);
    final posts = await Future.wait(result.posts.map(_withSaved));
    return FeedPage(posts: posts, hasMore: result.hasMore, nextCursor: result.nextCursor);
  });

  @override
  Future<Either<Failure, PostEntity>> getPost(String postId) => _run(() async {
    final post = await _remote.getPost(postId);
    return _withSaved(post);
  });

  @override
  Future<Either<Failure, CommentsPage>> getComments(String postId, {int page = 0}) => _run(() async {
    final result = await _remote.getComments(postId, page: page);
    return CommentsPage(comments: result.comments, hasMore: result.hasMore);
  });

  @override
  Future<Either<Failure, CommentEntity>> addComment(String postId, String content, {String? parentCommentId}) =>
      _run(() => _remote.addComment(postId, content, parentCommentId: parentCommentId));

  @override
  Future<Either<Failure, PostEntity>> toggleLike(PostEntity post) => _run(() async {
    // The reaction endpoint is a single POST toggle keyed on the type sent:
    // the same type as the viewer's current one removes it, a different one
    // *switches* to it. So an un-react has to echo whatever the viewer
    // already reacted with — hardcoding `LIKE` here turned a plain tap on a
    // post the viewer had reacted to with 😆/😮/… into "change it to
    // LIKE" instead of "take my reaction back".
    final type = post.viewerReactionType ?? ReactionType.like;
    final summary = await _remote.react(post.id, type: type.wireValue);
    return post.copyWith(reactionCounts: summary.counts, viewerReaction: summary.viewerReaction);
  });

  @override
  Future<Either<Failure, PostEntity>> reactToPost(PostEntity post, ReactionType type) => _run(() async {
    final summary = await _remote.react(post.id, type: type.wireValue);
    return post.copyWith(reactionCounts: summary.counts, viewerReaction: summary.viewerReaction);
  });

  @override
  Future<Either<Failure, CommentEntity>> reactToComment(CommentEntity comment, ReactionType type) => _run(() async {
    final summary = await _remote.reactToComment(comment.id, type: type.wireValue);
    // `summary.total` is the server's own sum — see `ReactionSummary.total`
    // for why re-folding `counts` locally under-counts.
    return comment.copyWith(reactionCount: summary.total, viewerReaction: summary.viewerReaction);
  });

  @override
  Future<Either<Failure, ReactionBreakdown>> getReactionSummary({
    required String targetType,
    required String targetId,
  }) => _run(() async {
    final summary = await _remote.getReactionSummary(targetType, targetId);
    final counts = <ReactionType, int>{};
    // Drop any wire key this client doesn't recognize rather than
    // guessing a bucket for it — see `ReactionType.fromWire`.
    for (final entry in summary.counts.entries) {
      final type = ReactionType.fromWire(entry.key);
      if (type != null) counts[type] = entry.value;
    }
    return ReactionBreakdown(counts: counts, viewerReaction: ReactionType.fromWire(summary.viewerReaction));
  });

  @override
  Future<Either<Failure, ReactorsPage>> getReactors({
    required String targetType,
    required String targetId,
    ReactionType? type,
    int page = 0,
  }) => _run(() async {
    final result = await _remote.getReactors(targetType, targetId, type: type?.wireValue, page: page);
    return ReactorsPage(reactors: result.items, hasMore: result.hasMore);
  });

  @override
  Future<Either<Failure, PostEntity>> repost(String postId, {String? content, PostVisibility? visibility}) =>
      _run(() => _remote.repost(postId, content: content, visibility: visibility));

  @override
  Future<Either<Failure, bool>> toggleSave(String postId) => _run(() => _bookmarks.toggle(postId));

  @override
  Future<Either<Failure, List<String>>> getSavedPostIds() =>
      _run(() async => (await _bookmarks.getSavedIds()).toList());

  @override
  Future<Either<Failure, PostEntity>> createPost({
    required String content,
    required PostVisibility visibility,
    List<File> images = const [],
  }) => _run(() => _remote.createPost(content: content, visibility: visibility, images: images));

  @override
  Future<Either<Failure, PostEntity>> updatePost(
    String postId, {
    String? content,
    PostVisibility? visibility,
    List<File> images = const [],
    List<String> removeImageIds = const [],
  }) => _run(
    () => _remote.updatePost(
      postId,
      content: content,
      visibility: visibility,
      images: images,
      removeImageIds: removeImageIds,
    ),
  );

  @override
  Future<Either<Failure, void>> deletePost(String postId) => _run(() => _remote.deletePost(postId));

  @override
  Future<Either<Failure, void>> deleteComment(String commentId) => _run(() => _remote.deleteComment(commentId));

  @override
  Future<Either<Failure, CommentEntity>> editComment(String commentId, String content) =>
      _run(() => _remote.editComment(commentId, content));

  /// No `/posts/{id}/share-link` route exists (it 404s) — the URL is a field
  /// on the post itself, so this re-reads the post and hands back its
  /// `shareUrl`. See the contract's own doc for when a caller can skip this
  /// entirely.
  @override
  Future<Either<Failure, String>> getShareLink(String postId) => _run(() async {
    final post = await _remote.getPost(postId);
    final url = post.shareUrl;
    if (url == null || url.isEmpty) {
      throw const AppException('That post has no share link.');
    }
    return url;
  });
}
