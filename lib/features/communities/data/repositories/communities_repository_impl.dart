import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../feed/domain/entities/comment_entity.dart';
import '../../../feed/domain/entities/post_entity.dart' show ReactionType;
import '../../domain/entities/community_entity.dart';
import '../../domain/entities/community_post_entity.dart';
import '../../domain/repositories/communities_repository.dart';
import '../datasources/communities_remote_datasource.dart';

class CommunitiesRepositoryImpl implements CommunitiesRepository {
  CommunitiesRepositoryImpl(this._remote, this._networkInfo);

  final CommunitiesRemoteDataSource _remote;
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

  @override
  Future<Either<Failure, CommunitiesPage>> getCommunities({
    String? query,
    CommunityMembershipFilter? membership,
    CommunitySort sort = CommunitySort.popular,
    int page = 0,
  }) => _run(() async {
    final result = await _remote.getCommunities(
      query: query,
      membership: membership,
      sort: sort,
      page: page,
    );
    return CommunitiesPage(communities: result.items, hasMore: result.hasMore);
  });

  @override
  Future<Either<Failure, CommunityEntity>> getCommunity(String slug) => _run(() => _remote.getCommunity(slug));

  @override
  Future<Either<Failure, CommunityEntity>> joinCommunity(String slug) =>
      _run(() => _remote.joinCommunity(slug));

  @override
  Future<Either<Failure, CommunityEntity>> leaveCommunity(String slug) =>
      _run(() => _remote.leaveCommunity(slug));

  @override
  Future<Either<Failure, CommunityPostsPage>> getCommunityPostFeed({
    CommunityFeedScope scope = CommunityFeedScope.all,
    CommunityPostSort sort = CommunityPostSort.hot,
    String? cursor,
  }) => _run(() async {
    final result = await _remote.getCommunityPostFeed(scope: scope, sort: sort, cursor: cursor);
    return CommunityPostsPage(posts: result.posts, hasMore: result.hasMore, nextCursor: result.nextCursor);
  });

  @override
  Future<Either<Failure, CommunityPostsPage>> getCommunityPosts(
    String slug, {
    CommunityPostSort sort = CommunityPostSort.hot,
    String? cursor,
  }) => _run(() async {
    final result = await _remote.getCommunityPosts(slug, sort: sort, cursor: cursor);
    return CommunityPostsPage(posts: result.posts, hasMore: result.hasMore, nextCursor: result.nextCursor);
  });

  @override
  Future<Either<Failure, CommunityPostEntity>> createPost(
    String slug, {
    required String title,
    required String tag,
    String? body,
  }) => _run(() => _remote.createCommunityPost(slug, title: title, tag: tag, body: body));

  @override
  Future<Either<Failure, CommunityPostEntity>> vote(CommunityPostEntity post, CommunityVote vote) =>
      _run(() async {
        final result = await _remote.voteCommunityPost(post.id, vote);
        // The vote response carries the authoritative score, so the row is
        // updated from the server's number rather than an optimistic ±1 that
        // drifts as other people vote on the same thread.
        return post.copyWith(score: result.score, viewerVote: result.viewerVote);
      });

  @override
  Future<Either<Failure, CommunityPostEntity>> react(CommunityPostEntity post, ReactionType type) =>
      _run(() async {
        final summary = await _remote.reactToCommunityPost(post.id, type: type.wireValue);
        return post.copyWith(reactionCounts: summary.counts, viewerReaction: summary.viewerReaction);
      });

  @override
  Future<Either<Failure, CommunityCommentsPage>> getComments(String postId, {int page = 0}) =>
      _run(() async {
        final result = await _remote.getComments(postId, page: page);
        return CommunityCommentsPage(comments: result.comments, hasMore: result.hasMore);
      });

  @override
  Future<Either<Failure, CommentEntity>> addComment(
    String postId,
    String content, {
    String? parentCommentId,
  }) => _run(() => _remote.addComment(postId, content, parentCommentId: parentCommentId));
}
