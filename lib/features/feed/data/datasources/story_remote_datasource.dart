import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_versioning/versioned_endpoints.dart';
import '../../domain/entities/story_entity.dart';
import '../../domain/repositories/story_repository.dart';
import '../models/story_model.dart';

/// The `/v1/stories` resource on `api.yello.cachewraith.com`. Every call
/// goes through [ApiClient], so auth, retry, logging and cert pinning apply
/// uniformly — nothing here builds its own Dio.
abstract interface class StoryRemoteDataSource {
  /// `GET /stories/feed?page=&size=` — friends' rings, unseen first then
  /// newest. Your own stories are never in it.
  Future<({List<StoryRingEntity> rings, bool hasMore})> getFeed({int page});

  /// `GET /stories/me` — your own active stories, oldest first. A bare
  /// array, not a page.
  Future<List<StoryEntity>> getMyStories();

  /// `GET /users/{id}/stories` — one user's active stories, a bare array.
  Future<List<StoryEntity>> getUserStories(String userId);

  Future<StoryEntity> getStory(String storyId);

  /// `POST /stories` — JSON for `TEXT`, multipart for `IMAGE`.
  Future<StoryEntity> createStory({
    String? text,
    StoryBackground? background,
    File? image,
    StoryVisibility visibility,
  });

  /// `POST /stories/{id}/view` — `204`, no body.
  Future<void> markViewed(String storyId);

  Future<({List<StoryViewerEntity> viewers, bool hasMore, int totalElements})> getViewers(
    String storyId, {
    int page,
  });

  Future<({List<StoryEntity> stories, bool hasMore})> getArchive({
    int page,
    StoryArchiveFilter filter,
  });

  /// `DELETE /stories/{id}` — `204`, no body.
  Future<void> deleteStory(String storyId);

  /// `POST /stories/{id}/replies` — `202`, the receipt only. The DM itself
  /// arrives over the chat socket.
  Future<StoryReplyReceipt> replyToStory({
    required String storyId,
    required String text,
    required String clientId,
  });
}

class StoryRemoteDataSourceImpl implements StoryRemoteDataSource {
  StoryRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  Dio get _dio => _client.dio;

  @override
  Future<({List<StoryRingEntity> rings, bool hasMore})> getFeed({int page = 0}) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          VersionedEndpoints.storyFeed(),
          queryParameters: {'page': page, 'size': AppConstants.storyFeedPageSize},
        );
        final envelope = ApiEnvelope.page(res);
        return (
          // A group whose `stories` came back empty is dropped rather than
          // drawn as a ring that plays nothing — the server says it never
          // returns empty rings, but the viewer would crash on one.
          rings: envelope.content.map(StoryRingMapper.fromJson).where((r) => r.stories.isNotEmpty).toList(),
          hasMore: envelope.hasMore,
        );
      });

  @override
  Future<List<StoryEntity>> getMyStories() => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(VersionedEndpoints.storiesMe());
        return StoryMapper.fromJsonList(ApiEnvelope.list(res));
      });

  @override
  Future<List<StoryEntity>> getUserStories(String userId) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(VersionedEndpoints.userStories(userId));
        return StoryMapper.fromJsonList(ApiEnvelope.list(res));
      });

  @override
  Future<StoryEntity> getStory(String storyId) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(VersionedEndpoints.story(storyId));
        return StoryMapper.fromJson(ApiEnvelope.data(res));
      });

  @override
  Future<StoryEntity> createStory({
    String? text,
    StoryBackground? background,
    File? image,
    StoryVisibility visibility = StoryVisibility.friends,
  }) => _guard(() async {
        // One path, two request bodies — `application/json` for a text
        // story and `multipart/form-data` when a photo is attached, exactly
        // like `POST /posts`. The multipart field is `image` (singular,
        // **unbracketed**): this endpoint takes exactly one file, so the
        // `images[]` bracket notation `/posts` needs would be rejected here.
        final res = await _dio.post<Map<String, dynamic>>(
          VersionedEndpoints.stories(),
          data: image == null
              ? <String, dynamic>{
                  'type': StoryType.text.wireValue,
                  'text': text,
                  'background': (background ?? StoryBackground.cover0).wireValue,
                  'visibility': visibility.wireValue,
                }
              : FormData.fromMap({
                  'type': StoryType.image.wireValue,
                  if (text != null && text.isNotEmpty) 'text': text,
                  'visibility': visibility.wireValue,
                  'image': await MultipartFile.fromFile(image.path),
                }),
        );
        return StoryMapper.fromJson(ApiEnvelope.data(res));
      });

  @override
  Future<void> markViewed(String storyId) =>
      _guard(() => _dio.post<void>(VersionedEndpoints.storyView(storyId)));

  @override
  Future<({List<StoryViewerEntity> viewers, bool hasMore, int totalElements})> getViewers(
    String storyId, {
    int page = 0,
  }) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          VersionedEndpoints.storyViewers(storyId),
          queryParameters: {'page': page, 'size': AppConstants.storyViewersPageSize},
        );
        final envelope = ApiEnvelope.page(res);
        return (
          viewers: envelope.content.map(StoryViewerMapper.fromJson).toList(),
          hasMore: envelope.hasMore,
          totalElements: envelope.totalElements,
        );
      });

  @override
  Future<({List<StoryEntity> stories, bool hasMore})> getArchive({
    int page = 0,
    StoryArchiveFilter filter = const StoryArchiveFilter(),
  }) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          VersionedEndpoints.storyArchive(),
          queryParameters: {
            'page': page,
            'size': AppConstants.storyArchivePageSize,
            // `from`/`to` are UTC calendar days (`YYYY-MM-DD`), not
            // timestamps — sending an ISO instant is `400 VALIDATION_FAILED`.
            'from': ?_day(filter.from),
            'to': ?_day(filter.to),
            'type': ?filter.type?.wireValue,
          },
        );
        final envelope = ApiEnvelope.page(res);
        return (stories: envelope.content.map(StoryMapper.fromJson).toList(), hasMore: envelope.hasMore);
      });

  /// A UTC calendar day in the `YYYY-MM-DD` form the archive filters take.
  /// Converted to UTC first: the server reads these as UTC days, so a local
  /// date near midnight would otherwise select the wrong one.
  static String? _day(DateTime? date) {
    if (date == null) return null;
    final utc = date.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<void> deleteStory(String storyId) =>
      _guard(() => _dio.delete<void>(VersionedEndpoints.story(storyId)));

  @override
  Future<StoryReplyReceipt> replyToStory({
    required String storyId,
    required String text,
    required String clientId,
  }) => _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          VersionedEndpoints.storyReplies(storyId),
          data: {'text': text, 'clientId': clientId},
        );
        return StoryReplyReceiptMapper.fromJson(ApiEnvelope.data(res));
      });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : ErrorHandler.fromDioException(e);
    }
  }
}
