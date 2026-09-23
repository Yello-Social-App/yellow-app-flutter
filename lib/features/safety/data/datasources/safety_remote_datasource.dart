import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_versioning/versioned_endpoints.dart';
import '../../domain/entities/feedback_entity.dart';
import '../../domain/entities/post_report_entity.dart';
import '../models/feedback_model.dart';
import '../models/muted_user_model.dart';
import '../models/post_report_model.dart';

/// The four safety-and-feedback resources, which share one data source
/// because they share one page shape, one guard, and one reason to exist —
/// splitting them into four would repeat all of that four times for no
/// reader's benefit.
///
/// Mute and hide answer `204 No Content`, so their calls are typed
/// `Future<void>` and **must not** unwrap an envelope: there is no body to
/// unwrap, and reaching for `data` would throw on success.
abstract interface class SafetyRemoteDataSource {
  /// Attaches `diagnostics` itself — see [SafetyRemoteDataSourceImpl].
  Future<FeedbackModel> submitFeedback({required FeedbackFeature feature, required int rating, String? note});
  Future<({List<FeedbackModel> items, bool hasMore})> getMyFeedback({int page});

  Future<PostReportModel> reportPost({required String postId, required ReportReason reason, String? details});
  Future<({List<PostReportModel> items, bool hasMore})> getMyReports({int page});

  Future<void> muteUser(String userId);
  Future<void> unmuteUser(String userId);
  Future<({List<MutedUserModel> items, bool hasMore})> getMutedUsers({int page});

  Future<void> hidePost(String postId);
  Future<void> unhidePost(String postId);
}

class SafetyRemoteDataSourceImpl implements SafetyRemoteDataSource {
  SafetyRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  /// The server's own default, and its cap is 50 — the same fixed page size
  /// every other offset-paged list in this app uses.
  static const _pageSize = 20;

  /// Both diagnostics values are capped at 32 characters server-side, and a
  /// longer one fails the whole submission with `400 VALIDATION_FAILED`.
  /// These two are derived, not typed by anyone, so truncating is the right
  /// call here — unlike `note`/`details`, which the use case rejects so the
  /// user finds out rather than silently losing the end of a sentence.
  static const _diagnosticsMaxLength = 32;

  /// `note` is sent trimmed, and omitted entirely when empty — the API
  /// stores an empty note as null either way, and omitting it keeps the
  /// request honest about what was actually written.
  ///
  /// `diagnostics` is gathered here rather than passed down from the Cubit:
  /// it is the running build and OS, which is a data-layer fact about this
  /// device, not something the user chose. It is best-effort — if
  /// `PackageInfo` throws (it needs a platform channel, which widget tests
  /// do not provide), the rating still goes out, just without a version.
  @override
  Future<FeedbackModel> submitFeedback({
    required FeedbackFeature feature,
    required int rating,
    String? note,
  }) =>
      _guard(() async {
        final trimmedNote = note?.trim();
        final diagnostics = await _diagnostics();
        final res = await _dio.post<Map<String, dynamic>>(
          VersionedEndpoints.feedback(),
          data: <String, dynamic>{
            'featureId': feature.wire,
            'rating': rating,
            if (trimmedNote != null && trimmedNote.isNotEmpty) 'note': trimmedNote,
            if (diagnostics.isNotEmpty) 'diagnostics': diagnostics,
          },
        );
        return FeedbackModel.fromJson(ApiEnvelope.data(res));
      });

  /// `{ appVersion, platform }`, both within the server's 32-character
  /// limit. Any other key would be dropped server-side, so none is sent.
  Future<Map<String, dynamic>> _diagnostics() async {
    String? appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      appVersion = null;
    }
    final platform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
            ? 'ios'
            : Platform.operatingSystem;
    return <String, dynamic>{
      if (appVersion != null && appVersion.isNotEmpty) 'appVersion': _cap(appVersion, _diagnosticsMaxLength),
      'platform': _cap(platform, _diagnosticsMaxLength),
    };
  }

  @override
  Future<({List<FeedbackModel> items, bool hasMore})> getMyFeedback({int page = 0}) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          VersionedEndpoints.myFeedback(),
          queryParameters: {'page': page, 'size': _pageSize},
        );
        final envelope = ApiEnvelope.page(res);
        return (items: envelope.content.map(FeedbackModel.fromJson).toList(), hasMore: envelope.hasMore);
      });

  /// A `status` sent by the client is ignored — a new report always starts
  /// `UNDER_REVIEW` — so none is sent.
  @override
  Future<PostReportModel> reportPost({
    required String postId,
    required ReportReason reason,
    String? details,
  }) =>
      _guard(() async {
        final trimmed = details?.trim();
        final res = await _dio.post<Map<String, dynamic>>(
          VersionedEndpoints.postReports(postId),
          data: <String, dynamic>{
            'reason': reason.wire,
            if (trimmed != null && trimmed.isNotEmpty) 'details': trimmed,
          },
        );
        return PostReportModel.fromJson(ApiEnvelope.data(res));
      });

  @override
  Future<({List<PostReportModel> items, bool hasMore})> getMyReports({int page = 0}) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          VersionedEndpoints.myReports(),
          queryParameters: {'page': page, 'size': _pageSize},
        );
        final envelope = ApiEnvelope.page(res);
        return (items: envelope.content.map(PostReportModel.fromJson).toList(), hasMore: envelope.hasMore);
      });

  @override
  Future<void> muteUser(String userId) => _guard(() => _dio.post<void>(VersionedEndpoints.userMute(userId)));

  @override
  Future<void> unmuteUser(String userId) => _guard(() => _dio.delete<void>(VersionedEndpoints.userMute(userId)));

  @override
  Future<({List<MutedUserModel> items, bool hasMore})> getMutedUsers({int page = 0}) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          VersionedEndpoints.mutedUsers(),
          queryParameters: {'page': page, 'size': _pageSize},
        );
        final envelope = ApiEnvelope.page(res);
        return (items: envelope.content.map(MutedUserModel.fromJson).toList(), hasMore: envelope.hasMore);
      });

  @override
  Future<void> hidePost(String postId) => _guard(() => _dio.post<void>(VersionedEndpoints.postHide(postId)));

  @override
  Future<void> unhidePost(String postId) => _guard(() => _dio.delete<void>(VersionedEndpoints.postHide(postId)));

  String _cap(String value, int max) => value.length <= max ? value : value.substring(0, max);

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : ErrorHandler.fromDioException(e);
    }
  }
}
