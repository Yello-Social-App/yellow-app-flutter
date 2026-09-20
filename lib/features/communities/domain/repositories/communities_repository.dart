import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../feed/domain/entities/comment_entity.dart';
import '../../../feed/domain/entities/post_entity.dart' show ReactionType;
import '../entities/community_entity.dart';
import '../entities/community_post_entity.dart';

/// One offset-paged page of `GET /communities`.
class CommunitiesPage {
  const CommunitiesPage({required this.communities, required this.hasMore});
  final List<CommunityEntity> communities;
  final bool hasMore;
}

/// One cursor-paged page of either community post list.
class CommunityPostsPage {
  const CommunityPostsPage({required this.posts, required this.hasMore, this.nextCursor});
  final List<CommunityPostEntity> posts;
  final bool hasMore;
  final String? nextCursor;
}

/// One offset-paged page of a community post's comments, already flattened
/// (replies carry their own `parentCommentId`).
class CommunityCommentsPage {
  const CommunityCommentsPage({required this.comments, required this.hasMore});
  final List<CommentEntity> comments;
  final bool hasMore;
}

/// Domain-facing contract for Communities.
///
/// There is deliberately **no** `getCommunityPost(id)` here, because the
/// backend has no `GET /community-posts/{id}` route: a thread is only ever
/// reachable from one of the two lists. Screens that show a single thread
/// therefore receive the entity they were opened with rather than re-fetching
/// it by id — see `CommunityPostCubit`.
abstract interface class CommunitiesRepository {
  Future<Either<Failure, CommunitiesPage>> getCommunities({
    String? query,
    CommunityMembershipFilter? membership,
    CommunitySort sort = CommunitySort.popular,
    int page = 0,
  });

  Future<Either<Failure, CommunityEntity>> getCommunity(String slug);

  /// Joins/leaves and returns the community with `isMember`/`memberCount`
  /// already updated — no follow-up read needed.
  Future<Either<Failure, CommunityEntity>> joinCommunity(String slug);
  Future<Either<Failure, CommunityEntity>> leaveCommunity(String slug);

  Future<Either<Failure, CommunityPostsPage>> getCommunityPostFeed({
    CommunityFeedScope scope = CommunityFeedScope.all,
    CommunityPostSort sort = CommunityPostSort.hot,
    String? cursor,
  });

  Future<Either<Failure, CommunityPostsPage>> getCommunityPosts(
    String slug, {
    CommunityPostSort sort = CommunityPostSort.hot,
    String? cursor,
  });

  /// Requires membership of [slug] — otherwise the call fails with the
  /// backend's `COMMUNITY_MEMBERSHIP_REQUIRED` code.
  Future<Either<Failure, CommunityPostEntity>> createPost(
    String slug, {
    required String title,
    required String tag,
    String? body,
  });

  /// Sets [post]'s vote to [vote] (absolute, not a delta) and returns the post
  /// with the server's authoritative score and vote merged back in.
  Future<Either<Failure, CommunityPostEntity>> vote(CommunityPostEntity post, CommunityVote vote);

  /// Set/switch/remove the viewer's reaction on a community post — the same
  /// single-POST toggle the feed uses, with `targetType=COMMUNITY_POST`.
  Future<Either<Failure, CommunityPostEntity>> react(CommunityPostEntity post, ReactionType type);

  Future<Either<Failure, CommunityCommentsPage>> getComments(String postId, {int page = 0});

  Future<Either<Failure, CommentEntity>> addComment(
    String postId,
    String content, {
    String? parentCommentId,
  });
}
