import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_versioning/versioned_endpoints.dart';
import '../../domain/entities/post_entity.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';

/// Result of a reaction PUT/DELETE/GET-summary — the backend's
/// `ReactionSummaryResponse`.
class ReactionSummary {
  const ReactionSummary({required this.counts, required this.viewerReaction});
  final Map<String, int> counts;
  final String? viewerReaction;
}

/// Live implementation against `dev.yello-api.cachewraith.com`
/// (`/v3/api-docs`). Every call goes through [ApiClient] so auth headers,
/// retry, and cert pinning apply uniformly.
abstract interface class FeedRemoteDataSource {
  Future<({List<PostModel> posts, bool hasMore, String? nextCursor})> getFeed({String? cursor});
  Future<PostModel> getPost(String postId);
  Future<({List<CommentModel> comments, bool hasMore})> getComments(String postId, {int page});
  Future<CommentModel> addComment(String postId, String content, {String? parentCommentId});
  Future<ReactionSummary> react(String postId, {String type});
  Future<ReactionSummary> unreact(String postId);

  /// Same PUT/DELETE contract as [react]/[unreact] but against a comment
  /// (`targetType=COMMENT`) instead of a post.
  Future<ReactionSummary> reactToComment(String commentId, {String type});
  Future<ReactionSummary> unreactFromComment(String commentId);

  /// `GET /reactions/{targetType}/{targetId}/summary` — an on-demand
  /// breakdown, independent of whether the viewer has reacted themselves.
  Future<ReactionSummary> getReactionSummary(String targetType, String targetId);
  Future<PostModel> repost(String postId, {String? content});
  Future<PostModel> createPost({
    required String content,
    required PostVisibility visibility,
    List<File> images,
  });
  Future<PostModel> updatePost(String postId, {String? content, PostVisibility? visibility});
  Future<void> deletePost(String postId);
  Future<void> deleteComment(String commentId);

  /// `GET /posts/{id}/share-link` — the post's canonical public URL.
  Future<String> getShareLink(String postId);
}

class FeedRemoteDataSourceImpl implements FeedRemoteDataSource {
  FeedRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  static const _feedPageSize = 20;
  static const _commentsPageSize = 20;

  @override
  Future<({List<PostModel> posts, bool hasMore, String? nextCursor})> getFeed({String? cursor}) =>
      _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          VersionedEndpoints.feed(),
          queryParameters: {'size': _feedPageSize, if (cursor != null) 'cursor': cursor},
        );
        final page = ApiEnvelope.cursorPage(res);
        return (
          posts: page.content.map(PostModel.fromJson).toList(),
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
        );
      });

  @override
  Future<PostModel> getPost(String postId) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(VersionedEndpoints.post(postId));
        return PostModel.fromJson(ApiEnvelope.data(res));
      });

  @override
  Future<({List<CommentModel> comments, bool hasMore})> getComments(String postId, {int page = 0}) =>
      _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          VersionedEndpoints.postComments(postId),
          queryParameters: {'page': page, 'size': _commentsPageSize},
        );
        final envelope = ApiEnvelope.page(res);
        return (
          comments: envelope.content.map(CommentModel.fromJson).toList(),
          hasMore: envelope.hasMore,
        );
      });

  @override
  Future<CommentModel> addComment(String postId, String content, {String? parentCommentId}) =>
      _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          VersionedEndpoints.postComments(postId),
          data: {'content': content, if (parentCommentId != null) 'parentCommentId': parentCommentId},
        );
        return CommentModel.fromJson(ApiEnvelope.data(res));
      });

  @override
  Future<ReactionSummary> react(String postId, {String type = 'LIKE'}) => _guard(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          VersionedEndpoints.reaction('POST', postId),
          data: {'type': type},
        );
        return _toSummary(ApiEnvelope.data(res));
      });

  @override
  Future<ReactionSummary> unreact(String postId) => _guard(() async {
        final res = await _dio.delete<Map<String, dynamic>>(VersionedEndpoints.reaction('POST', postId));
        return _toSummary(ApiEnvelope.data(res));
      });

  @override
  Future<ReactionSummary> reactToComment(String commentId, {String type = 'LIKE'}) =>
      _guard(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          VersionedEndpoints.reaction('COMMENT', commentId),
          data: {'type': type},
        );
        return _toSummary(ApiEnvelope.data(res));
      });

  @override
  Future<ReactionSummary> unreactFromComment(String commentId) => _guard(() async {
        final res =
            await _dio.delete<Map<String, dynamic>>(VersionedEndpoints.reaction('COMMENT', commentId));
        return _toSummary(ApiEnvelope.data(res));
      });

  @override
  Future<ReactionSummary> getReactionSummary(String targetType, String targetId) => _guard(() async {
        final res =
            await _dio.get<Map<String, dynamic>>(VersionedEndpoints.reactionSummary(targetType, targetId));
        return _toSummary(ApiEnvelope.data(res));
      });

  ReactionSummary _toSummary(Map<String, dynamic> json) => ReactionSummary(
        counts: (json['counts'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as num).toInt())),
        viewerReaction: json['viewerReaction'] as String?,
      );

  @override
  Future<PostModel> repost(String postId, {String? content}) => _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          VersionedEndpoints.repost(postId),
          data: {if (content != null && content.isNotEmpty) 'content': content},
        );
        return PostModel.fromJson(ApiEnvelope.data(res));
      });

  @override
  Future<PostModel> createPost({
    required String content,
    required PostVisibility visibility,
    List<File> images = const [],
  }) =>
      _guard(() async {
        // `content`/`visibility` are QUERY params on this endpoint; only
        // `images` lives in the multipart body — an array field that takes
        // one entry per attached photo (see `UpdatePostRequest`'s sibling
        // schema in the spec).
        final form = FormData();
        for (final image in images) {
          form.files.add(MapEntry('images', await MultipartFile.fromFile(image.path)));
        }
        final res = await _dio.post<Map<String, dynamic>>(
          VersionedEndpoints.posts(),
          queryParameters: {'content': content, 'visibility': visibility.wireValue},
          data: form,
        );
        return PostModel.fromJson(ApiEnvelope.data(res));
      });

  @override
  Future<PostModel> updatePost(String postId, {String? content, PostVisibility? visibility}) =>
      _guard(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          VersionedEndpoints.post(postId),
          data: {
            if (content != null) 'content': content,
            if (visibility != null) 'visibility': visibility.wireValue,
          },
        );
        return PostModel.fromJson(ApiEnvelope.data(res));
      });

  @override
  Future<void> deletePost(String postId) =>
      _guard(() => _dio.delete<void>(VersionedEndpoints.post(postId)));

  @override
  Future<void> deleteComment(String commentId) =>
      _guard(() => _dio.delete<void>(VersionedEndpoints.comment(commentId)));

  @override
  Future<String> getShareLink(String postId) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(VersionedEndpoints.shareLink(postId));
        return ApiEnvelope.data(res)['url'] as String;
      });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : ErrorHandler.fromDioException(e);
    }
  }
}
