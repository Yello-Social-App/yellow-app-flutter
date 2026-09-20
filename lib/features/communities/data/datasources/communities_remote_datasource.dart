import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_versioning/versioned_endpoints.dart';
import '../../../feed/data/datasources/feed_remote_datasource.dart' show ReactionSummary;
import '../../../feed/data/models/comment_model.dart';
import '../../../feed/domain/entities/post_entity.dart' show ReactionTargetType;
import '../../domain/entities/community_entity.dart';
import '../../domain/entities/community_post_entity.dart';
import '../models/community_model.dart';
import '../models/community_post_model.dart';

/// Live implementation of the `/communities`, `/community-posts` and
/// `/communities/{slug}/posts` routes.
///
/// Two things about this resource are easy to get wrong and worth stating
/// once: the `{community}` segment is a **slug**, while `{post}` on the
/// community-post routes is a **uuid**; and the two post lists are
/// **cursor**-paged (like `/feed`) while `/communities` and the comment list
/// are **offset**-paged. Mixing those up produces a 400, not an empty page.
///
/// Comments reuse the feed feature's [CommentModel] because the backend
/// serves both comment collections from one `Comment` schema — the only
/// difference on the wire is whether `postId` or `communityPostId` is set.
/// Reaction payloads likewise reuse [ReactionSummary] for the same reason.
abstract interface class CommunitiesRemoteDataSource {
  Future<({List<CommunityModel> items, bool hasMore})> getCommunities({
    String? query,
    CommunityMembershipFilter? membership,
    CommunitySort sort,
    int page,
  });

  Future<CommunityModel> getCommunity(String slug);

  /// `POST`/`DELETE /communities/{slug}/membership` — both answer with the
  /// updated `Community`, so `isMember`/`memberCount` need no follow-up GET.
  Future<CommunityModel> joinCommunity(String slug);
  Future<CommunityModel> leaveCommunity(String slug);

  /// `GET /community-posts` — the cross-community timeline (cursor-paged).
  Future<({List<CommunityPostModel> posts, bool hasMore, String? nextCursor})> getCommunityPostFeed({
    CommunityFeedScope scope,
    CommunityPostSort sort,
    String? cursor,
  });

  /// `GET /communities/{slug}/posts` — one community's threads (cursor-paged).
  Future<({List<CommunityPostModel> posts, bool hasMore, String? nextCursor})> getCommunityPosts(
    String slug, {
    CommunityPostSort sort,
    String? cursor,
  });

  /// `POST /communities/{slug}/posts`. [tag] is required and must be one of
  /// the community's own `tags`; a non-member gets
  /// `403 COMMUNITY_MEMBERSHIP_REQUIRED`.
  Future<CommunityPostModel> createCommunityPost(
    String slug, {
    required String title,
    required String tag,
    String? body,
  });

  /// `PUT /community-posts/{id}/vote` — absolute, not a delta.
  Future<CommunityPostVoteResultModel> voteCommunityPost(String postId, CommunityVote vote);

  /// `POST /reactions/COMMUNITY_POST/{id}` — the same add/change/remove
  /// toggle the feed uses, against a community post.
  Future<ReactionSummary> reactToCommunityPost(String postId, {String type});

  Future<({List<CommentModel> comments, bool hasMore})> getComments(String postId, {int page});

  Future<CommentModel> addComment(String postId, String content, {String? parentCommentId});
}

class CommunitiesRemoteDataSourceImpl implements CommunitiesRemoteDataSource {
  CommunitiesRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  static const _pageSize = 20;
  static const _commentsPageSize = 20;

  @override
  Future<({List<CommunityModel> items, bool hasMore})> getCommunities({
    String? query,
    CommunityMembershipFilter? membership,
    CommunitySort sort = CommunitySort.popular,
    int page = 0,
  }) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      VersionedEndpoints.communities(),
      queryParameters: {
        'q': ?query,
        'membership': ?membership?.wireValue,
        'sort': sort.wireValue,
        'page': page,
        'size': _pageSize,
      },
    );
    final envelope = ApiEnvelope.page(res);
    return (items: envelope.content.map(CommunityModel.fromJson).toList(), hasMore: envelope.hasMore);
  });

  @override
  Future<CommunityModel> getCommunity(String slug) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(VersionedEndpoints.community(slug));
    return CommunityModel.fromJson(ApiEnvelope.data(res));
  });

  @override
  Future<CommunityModel> joinCommunity(String slug) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(VersionedEndpoints.communityMembership(slug));
    return CommunityModel.fromJson(ApiEnvelope.data(res));
  });

  @override
  Future<CommunityModel> leaveCommunity(String slug) => _guard(() async {
    final res = await _dio.delete<Map<String, dynamic>>(VersionedEndpoints.communityMembership(slug));
    return CommunityModel.fromJson(ApiEnvelope.data(res));
  });

  @override
  Future<({List<CommunityPostModel> posts, bool hasMore, String? nextCursor})> getCommunityPostFeed({
    CommunityFeedScope scope = CommunityFeedScope.all,
    CommunityPostSort sort = CommunityPostSort.hot,
    String? cursor,
  }) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      VersionedEndpoints.communityPostFeed(),
      queryParameters: {
        'scope': scope.wireValue,
        'sort': sort.wireValue,
        'size': _pageSize,
        'cursor': ?cursor,
      },
    );
    return _postPage(res);
  });

  @override
  Future<({List<CommunityPostModel> posts, bool hasMore, String? nextCursor})> getCommunityPosts(
    String slug, {
    CommunityPostSort sort = CommunityPostSort.hot,
    String? cursor,
  }) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      VersionedEndpoints.communityPosts(slug),
      queryParameters: {'sort': sort.wireValue, 'size': _pageSize, 'cursor': ?cursor},
    );
    return _postPage(res);
  });

  ({List<CommunityPostModel> posts, bool hasMore, String? nextCursor}) _postPage(
    Response<Map<String, dynamic>> res,
  ) {
    final page = ApiEnvelope.cursorPage(res);
    return (
      posts: page.content.map(CommunityPostModel.fromJson).toList(),
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
  }

  @override
  Future<CommunityPostModel> createCommunityPost(
    String slug, {
    required String title,
    required String tag,
    String? body,
  }) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      VersionedEndpoints.communityPosts(slug),
      data: {'title': title, 'tag': tag, 'body': ?body},
    );
    return CommunityPostModel.fromJson(ApiEnvelope.data(res));
  });

  @override
  Future<CommunityPostVoteResultModel> voteCommunityPost(String postId, CommunityVote vote) =>
      _guard(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          VersionedEndpoints.communityPostVote(postId),
          data: {'value': vote.wireValue},
        );
        return CommunityPostVoteResultModel.fromJson(ApiEnvelope.data(res));
      });

  @override
  Future<ReactionSummary> reactToCommunityPost(String postId, {String type = 'LIKE'}) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      VersionedEndpoints.reaction(ReactionTargetType.communityPost.wireValue, postId),
      data: {'type': type},
    );
    final json = ApiEnvelope.data(res);
    final counts = (json['counts'] as Map<String, dynamic>? ?? const {}).map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
    return ReactionSummary(
      counts: counts,
      viewerReaction: json['viewerReaction'] as String?,
      total: (json['total'] as num?)?.toInt() ?? counts.values.fold<int>(0, (a, b) => a + b),
    );
  });

  @override
  Future<({List<CommentModel> comments, bool hasMore})> getComments(String postId, {int page = 0}) =>
      _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          VersionedEndpoints.communityPostComments(postId),
          queryParameters: {'page': page, 'size': _commentsPageSize},
        );
        final envelope = ApiEnvelope.page(res);
        // Replies arrive nested under their top-level parent; flatten to the
        // same one-list-with-parentCommentId shape the feed's thread uses.
        return (
          comments: envelope.content.expand(CommentModel.withRepliesFromJson).toList(),
          hasMore: envelope.hasMore,
        );
      });

  @override
  Future<CommentModel> addComment(String postId, String content, {String? parentCommentId}) =>
      _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          VersionedEndpoints.communityPostComments(postId),
          data: {'content': content, 'parentCommentId': ?parentCommentId},
        );
        return CommentModel.fromJson(ApiEnvelope.data(res));
      });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : ErrorHandler.fromDioException(e);
    }
  }
}
