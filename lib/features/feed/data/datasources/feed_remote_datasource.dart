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
import '../models/reactor_model.dart';

/// Result of a reaction POST/GET-summary — the backend's `ReactionSummary`.
class ReactionSummary {
  const ReactionSummary({required this.counts, required this.viewerReaction, required this.total});

  /// Per-type counts, keyed by the wire name (`LIKE`, `LOVE`, …).
  final Map<String, int> counts;
  final String? viewerReaction;

  /// The server's own sum across every type — a real field on the wire
  /// (`ReactionSummary.total`), not something this client derives. Prefer it
  /// over folding [counts]: a reaction type this client version doesn't
  /// know about is dropped from [counts] but still included here, so
  /// re-summing locally under-counts on a newer backend.
  final int total;
}

/// Live implementation against `api.yello.cachewraith.com` (OpenAPI document
/// at `/docs/json?api-docs.json`). Every call goes through [ApiClient] so
/// auth headers, retry, and cert pinning apply uniformly.
abstract interface class FeedRemoteDataSource {
  Future<({List<PostModel> posts, bool hasMore, String? nextCursor})> getFeed({
    String? cursor,
  });
  Future<PostModel> getPost(String postId);
  Future<({List<CommentModel> comments, bool hasMore})> getComments(
    String postId, {
    int page,
  });
  Future<CommentModel> addComment(
    String postId,
    String content, {
    String? parentCommentId,
  });

  /// `PUT /comments/{id}` — replaces your comment's text and returns the
  /// updated `Comment`. Allowed for the commenter only (the post's author
  /// and moderators can delete but not rewrite someone else's words).
  Future<CommentModel> editComment(String commentId, String content);

  /// `POST /reactions/{targetType}/{targetId}` — the server decides
  /// add/change/remove from the viewer's current reaction; there is no
  /// separate un-react call any more.
  Future<ReactionSummary> react(String postId, {String type});

  /// Same POST-toggle contract as [react] but against a comment
  /// (`targetType=COMMENT`) instead of a post.
  Future<ReactionSummary> reactToComment(String commentId, {String type});

  /// `GET /reactions/{targetType}/{targetId}/summary` — an on-demand
  /// breakdown, independent of whether the viewer has reacted themselves.
  Future<ReactionSummary> getReactionSummary(
    String targetType,
    String targetId,
  );

  /// `GET /reactions/{targetType}/{targetId}` — paginated list of users who
  /// reacted, optionally filtered to one reaction [type]. Same path [react]
  /// POSTs to; [getReactionSummary] is the `/summary` sibling of this same
  /// path.
  Future<({List<ReactorModel> items, bool hasMore})> getReactors(
    String targetType,
    String targetId, {
    String? type,
    int page,
  });

  /// `POST /posts/{id}/repost`. [visibility] sets the *repost's* own
  /// audience, independently of the original post's.
  Future<PostModel> repost(String postId, {String? content, PostVisibility? visibility});
  Future<PostModel> createPost({
    required String content,
    required PostVisibility visibility,
    List<File> images,
  });

  /// `PUT /posts/{id}` — every argument is optional and only what's passed
  /// changes. [images] appends new photos; [removeImageIds] drops existing
  /// ones by `PostImage.id` (both can be sent in the same call).
  Future<PostModel> updatePost(
    String postId, {
    String? content,
    PostVisibility? visibility,
    List<File> images,
    List<String> removeImageIds,
  });
  Future<void> deletePost(String postId);
  Future<void> deleteComment(String commentId);
}

class FeedRemoteDataSourceImpl implements FeedRemoteDataSource {
  FeedRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  static const _feedPageSize = 20;
  static const _commentsPageSize = 20;
  static const _reactorsPageSize = 20;

  @override
  Future<({List<PostModel> posts, bool hasMore, String? nextCursor})> getFeed({
    String? cursor,
  }) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      VersionedEndpoints.feed(),
      queryParameters: {'size': _feedPageSize, 'cursor': ?cursor},
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
    final res = await _dio.get<Map<String, dynamic>>(
      VersionedEndpoints.post(postId),
    );
    return PostModel.fromJson(ApiEnvelope.data(res));
  });

  @override
  Future<({List<CommentModel> comments, bool hasMore})> getComments(
    String postId, {
    int page = 0,
  }) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      VersionedEndpoints.postComments(postId),
      queryParameters: {'page': page, 'size': _commentsPageSize},
    );
    final envelope = ApiEnvelope.page(res);
    return (
      comments: envelope.content.expand(CommentModel.withRepliesFromJson).toList(),
      hasMore: envelope.hasMore,
    );
  });

  @override
  Future<CommentModel> addComment(
    String postId,
    String content, {
    String? parentCommentId,
  }) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      VersionedEndpoints.postComments(postId),
      data: {'content': content, 'parentCommentId': ?parentCommentId},
    );
    return CommentModel.fromJson(ApiEnvelope.data(res));
  });

  @override
  Future<CommentModel> editComment(String commentId, String content) => _guard(() async {
    final res = await _dio.put<Map<String, dynamic>>(
      VersionedEndpoints.comment(commentId),
      data: {'content': content},
    );
    return CommentModel.fromJson(ApiEnvelope.data(res));
  });

  @override
  Future<ReactionSummary> react(String postId, {String type = 'LIKE'}) =>
      _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          VersionedEndpoints.reaction(ReactionTargetType.post.wireValue, postId),
          data: {'type': type},
        );
        return _toSummary(ApiEnvelope.data(res));
      });

  @override
  Future<ReactionSummary> reactToComment(
    String commentId, {
    String type = 'LIKE',
  }) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      VersionedEndpoints.reaction(ReactionTargetType.comment.wireValue, commentId),
      data: {'type': type},
    );
    return _toSummary(ApiEnvelope.data(res));
  });

  @override
  Future<ReactionSummary> getReactionSummary(String targetType, String targetId) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(VersionedEndpoints.reactionSummary(targetType, targetId));
    return _toSummary(ApiEnvelope.data(res));
  });

  @override
  Future<({List<ReactorModel> items, bool hasMore})> getReactors(
    String targetType,
    String targetId, {
    String? type,
    int page = 0,
  }) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      VersionedEndpoints.reaction(targetType, targetId),
      queryParameters: {'page': page, 'size': _reactorsPageSize, 'type': ?type},
    );
    final envelope = ApiEnvelope.page(res);
    return (
      items: envelope.content.map(ReactorModel.fromJson).toList(),
      hasMore: envelope.hasMore,
    );
  });

  ReactionSummary _toSummary(Map<String, dynamic> json) {
    final counts = (json['counts'] as Map<String, dynamic>? ?? const {}).map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
    return ReactionSummary(
      counts: counts,
      viewerReaction: json['viewerReaction'] as String?,
      // `total` is a sibling of `counts` on this schema (unlike `Post`'s
      // `reactionCounts`, which nests its own `total` *inside* the map) —
      // fall back to a local fold only if an older deployment omits it.
      total: (json['total'] as num?)?.toInt() ?? counts.values.fold<int>(0, (a, b) => a + b),
    );
  }

  @override
  Future<PostModel> repost(String postId, {String? content, PostVisibility? visibility}) =>
      _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          VersionedEndpoints.repost(postId),
          data: {
            if (content != null && content.isNotEmpty) 'content': content,
            if (visibility != null) 'visibility': visibility.wireValue,
          },
        );
        return PostModel.fromJson(ApiEnvelope.data(res));
      });

  @override
  Future<PostModel> createPost({
    required String content,
    required PostVisibility visibility,
    List<File> images = const [],
  }) => _guard(() async {
    // `content`/`visibility` are **body** fields, not query params: the
    // spec gives this endpoint two request bodies — `application/json` for
    // a text-only post and `multipart/form-data` (same two fields plus
    // `images[]`) when photos are attached. An earlier revision of the API
    // took them on the query string; sending them there now leaves the
    // body empty and the post content blank.
    //
    // The multipart field name is `images[]` (bracket notation, straight
    // from the spec) — the backend's multipart parser only builds an array
    // from a bracketed key, so a plain `images` key is read as a scalar and
    // rejected as "not an array", even for a single photo.
    final res = await _dio.post<Map<String, dynamic>>(
      VersionedEndpoints.posts(),
      data: images.isEmpty
          ? {'content': content, 'visibility': visibility.wireValue}
          : await _postForm(
              content: content,
              visibility: visibility,
              images: images,
            ),
    );
    return PostModel.fromJson(ApiEnvelope.data(res));
  });

  @override
  Future<PostModel> updatePost(
    String postId, {
    String? content,
    PostVisibility? visibility,
    List<File> images = const [],
    List<String> removeImageIds = const [],
  }) => _guard(() async {
    // Same two-body split as `createPost`: JSON unless new photos are being
    // attached, in which case everything (including `removeImageIds[]`)
    // moves into the multipart body. Adding and removing images in one call
    // is allowed — removals are applied against the *existing* image ids,
    // so an id in [removeImageIds] never refers to one of [images].
    final res = await _dio.put<Map<String, dynamic>>(
      VersionedEndpoints.post(postId),
      data: images.isEmpty
          ? <String, dynamic>{
              'content': ?content,
              if (visibility != null) 'visibility': visibility.wireValue,
              if (removeImageIds.isNotEmpty) 'removeImageIds': removeImageIds,
            }
          : await _postForm(
              content: content,
              visibility: visibility,
              images: images,
              removeImageIds: removeImageIds,
            ),
    );
    return PostModel.fromJson(ApiEnvelope.data(res));
  });

  /// The shared `multipart/form-data` body for create/edit post. Scalars go
  /// in `fields`, photos in `files` under the repeated `images[]` key.
  Future<FormData> _postForm({
    String? content,
    PostVisibility? visibility,
    List<File> images = const [],
    List<String> removeImageIds = const [],
  }) async {
    final form = FormData();
    if (content != null) form.fields.add(MapEntry('content', content));
    if (visibility != null) form.fields.add(MapEntry('visibility', visibility.wireValue));
    for (final id in removeImageIds) {
      form.fields.add(MapEntry('removeImageIds[]', id));
    }
    for (final image in images) {
      form.files.add(MapEntry('images[]', await MultipartFile.fromFile(image.path)));
    }
    return form;
  }

  @override
  Future<void> deletePost(String postId) =>
      _guard(() => _dio.delete<void>(VersionedEndpoints.post(postId)));

  @override
  Future<void> deleteComment(String commentId) =>
      _guard(() => _dio.delete<void>(VersionedEndpoints.comment(commentId)));

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : ErrorHandler.fromDioException(e);
    }
  }
}
