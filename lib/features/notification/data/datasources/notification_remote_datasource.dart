import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_versioning/versioned_endpoints.dart';
import '../models/notification_model.dart';

abstract interface class NotificationRemoteDataSource {
  Future<({List<NotificationModel> items, bool hasMore})> getNotifications({
    required int page,
    required bool unreadOnly,
  });
  Future<int> getUnreadCount();
  Future<void> markAllRead();
  Future<void> markRead(String id);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  NotificationRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  static const _pageSize = 20;

  @override
  Future<({List<NotificationModel> items, bool hasMore})> getNotifications({
    required int page,
    required bool unreadOnly,
  }) =>
      _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          VersionedEndpoints.notifications(),
          queryParameters: {'page': page, 'size': _pageSize, 'unreadOnly': unreadOnly},
        );
        final envelope = ApiEnvelope.page(res);
        return (
          items: envelope.content.map(NotificationModel.fromJson).toList(),
          hasMore: envelope.hasMore,
        );
      });

  @override
  Future<int> getUnreadCount() => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(VersionedEndpoints.notificationsUnreadCount());
        return (ApiEnvelope.data(res)['unread'] as num).toInt();
      });

  @override
  Future<void> markAllRead() => _guard(() => _dio.put<void>(VersionedEndpoints.notificationsReadAll()));

  @override
  Future<void> markRead(String id) => _guard(() => _dio.put<void>(VersionedEndpoints.notificationRead(id)));

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : ErrorHandler.fromDioException(e);
    }
  }
}
