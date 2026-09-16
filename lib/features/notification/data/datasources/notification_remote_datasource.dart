import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_envelope.dart';
import '../models/device_model.dart';
import '../models/notification_model.dart';
import '../models/notification_preferences_model.dart';

/// Routes for `yello-notify`, a **separate service** from yello-api (the
/// FastAPI notification worker — base `https://api.yello.cachewraith.com/notifications/v1`).
///
/// It shares the host and the bearer token but not `VersionedEndpoints`'
/// URL shape: the version segment sits *after* the resource name
/// (`/notifications/v1`, not `/v1/notifications`), so routing these through
/// `EndpointResolver` would prepend a `/v1` and produce a 404. Same
/// reasoning as `ChatRoutes` for `yello-chat` (see that class's doc). The
/// envelope shape (`{success, data, timestamp}` / error `{success, code,
/// message, fieldErrors, path, timestamp}`) does match yello-api's, though,
/// so `ApiEnvelope`/`ErrorHandler` are reused as-is.
abstract final class NotifyRoutes {
  static const String _root = '/notifications/v1';

  static const String inbox = _root;
  static const String unreadCount = '$_root/unread-count';
  static String read(String id) => '$_root/$id/read';
  static const String readAll = '$_root/read-all';
  static String notification(String id) => '$_root/$id';
  static const String devices = '$_root/devices';
  static const String unregisterDevice = '$_root/devices/unregister';
  static const String preferences = '$_root/preferences';

  /// Sits beside `/v1`, not under it, and needs no auth. Not called from
  /// the app today — kept for parity with the service's documented surface
  /// (e.g. a future in-app diagnostics screen).
  static const String health = '/notifications/health';
}

/// `{ items, nextCursor }` — this service's own cursor-page shape, distinct
/// from `ApiEnvelope.cursorPage`'s `{content, hasMore, nextCursor}` (used by
/// `/feed`) and `ApiEnvelope.page`'s `{content, page, ...}` (friends/
/// comments), so it's parsed locally here rather than forcing it through
/// either shared helper.
class NotificationInboxPageResult {
  const NotificationInboxPageResult({required this.items, required this.nextCursor});
  final List<NotificationModel> items;
  final String? nextCursor;
}

abstract interface class NotificationRemoteDataSource {
  Future<NotificationInboxPageResult> getInbox({int size = 20, String? cursor, bool unreadOnly = false});
  Future<int> getUnreadCount();
  Future<NotificationModel> markRead(String id);
  Future<int> markAllRead();
  Future<void> deleteNotification(String id);

  Future<DeviceModel> registerDevice({
    required String token,
    required String platform,
    String? appVersion,
    String? locale,
  });

  /// A repeat call, or a token the backend no longer recognizes, both
  /// answer `404 RESOURCE_NOT_FOUND` — treated as success here (per the
  /// endpoint's own contract: "that token is not registered to you —
  /// including a repeat call, so treat 404 here as success"), so callers
  /// never need their own special case for a double logout or a token-
  /// rotation race.
  Future<void> unregisterDevice(String token);

  Future<NotificationPreferencesModel> getPreferences();
  Future<NotificationPreferencesModel> updatePreferences({required bool pushEnabled, required List<String> mutedTypes});
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  NotificationRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  @override
  Future<NotificationInboxPageResult> getInbox({int size = 20, String? cursor, bool unreadOnly = false}) =>
      _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          NotifyRoutes.inbox,
          queryParameters: {'size': size, 'unread': unreadOnly, 'cursor': ?cursor},
        );
        final data = ApiEnvelope.data(res);
        final items = (data['items'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(NotificationModel.fromJson)
            .toList();
        return NotificationInboxPageResult(items: items, nextCursor: data['nextCursor'] as String?);
      });

  @override
  Future<int> getUnreadCount() => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(NotifyRoutes.unreadCount);
    return (ApiEnvelope.data(res)['count'] as num).toInt();
  });

  /// Idempotent server-side (a row already read keeps its original `readAt`
  /// and still answers 200) — no special-casing needed here.
  @override
  Future<NotificationModel> markRead(String id) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(NotifyRoutes.read(id));
    return NotificationModel.fromJson(ApiEnvelope.data(res));
  });

  @override
  Future<int> markAllRead() => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(NotifyRoutes.readAll);
    return (ApiEnvelope.data(res)['updated'] as num).toInt();
  });

  /// **Not** idempotent — a second delete of the same row is a real 404,
  /// unlike [unregisterDevice]. Let it surface as a normal failure.
  @override
  Future<void> deleteNotification(String id) => _guard(() => _dio.delete<void>(NotifyRoutes.notification(id)));

  @override
  Future<DeviceModel> registerDevice({
    required String token,
    required String platform,
    String? appVersion,
    String? locale,
  }) => _guard(() async {
    final res = await _dio.put<Map<String, dynamic>>(
      NotifyRoutes.devices,
      data: {'token': token, 'platform': platform, 'appVersion': ?appVersion, 'locale': ?locale},
    );
    return DeviceModel.fromJson(ApiEnvelope.data(res));
  });

  @override
  Future<void> unregisterDevice(String token) async {
    try {
      await _dio.post<void>(NotifyRoutes.unregisterDevice, data: {'token': token});
    } on DioException catch (e) {
      final error = e.error is AppException ? e.error as AppException : ErrorHandler.fromDioException(e);
      if (error.code == 'RESOURCE_NOT_FOUND') return;
      throw error;
    }
  }

  @override
  Future<NotificationPreferencesModel> getPreferences() => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(NotifyRoutes.preferences);
    return NotificationPreferencesModel.fromJson(ApiEnvelope.data(res));
  });

  /// `PUT` replaces the whole record — callers must always send the
  /// complete desired state, never just the field that changed (an omitted
  /// field would reset to its default, not keep its stored value).
  @override
  Future<NotificationPreferencesModel> updatePreferences({
    required bool pushEnabled,
    required List<String> mutedTypes,
  }) => _guard(() async {
    final res = await _dio.put<Map<String, dynamic>>(
      NotifyRoutes.preferences,
      data: {'pushEnabled': pushEnabled, 'mutedTypes': mutedTypes},
    );
    return NotificationPreferencesModel.fromJson(ApiEnvelope.data(res));
  });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : ErrorHandler.fromDioException(e);
    }
  }
}
