import 'package:dartz/dartz.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../domain/entities/device_entity.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/entities/notification_preferences_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_datasource.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._remote, this._networkInfo, this._secureStorage);

  final NotificationRemoteDataSource _remote;
  final NetworkInfo _networkInfo;

  /// Only used to remember the last successfully-registered push token
  /// (under [AppConstants.secureKeyPushToken]) so `LogoutUseCase` can spend
  /// it on `unregisterDevice` without depending on a live push SDK at
  /// logout time.
  final SecureStorageService _secureStorage;

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
  Future<Either<Failure, NotificationsPage>> getInbox({int size = 20, String? cursor, bool unreadOnly = false}) =>
      _run(() async {
        var nextCursor = cursor;
        final visited = <String>{?cursor};
        do {
          final result = await _remote.getInbox(size: size, cursor: nextCursor, unreadOnly: unreadOnly);
          final items = result.items.where((item) => item.isSignal).toList();
          nextCursor = result.nextCursor;
          if (nextCursor != null && !visited.add(nextCursor)) {
            throw StateError('Notification pagination returned a repeated cursor');
          }
          // Skip chat-only pages so they cannot hide later Signals activity.
          if (items.isNotEmpty || nextCursor == null) {
            return NotificationsPage(items: items, nextCursor: nextCursor);
          }
        } while (true);
      });

  @override
  Future<Either<Failure, int>> getUnreadCount() => _run(() async => (await _unreadSignals()).length);

  // The aggregate count endpoint includes types hidden from Signals.
  // Traverse unread pages so the badge uses exactly the same filter as rows.
  Future<List<NotificationEntity>> _unreadSignals() async {
    final items = <String, NotificationEntity>{};
    final visited = <String>{};
    String? cursor;
    do {
      final page = await _remote.getInbox(cursor: cursor, unreadOnly: true);
      for (final item in page.items) {
        if (item.isSignal && !item.read) items[item.id] = item;
      }
      cursor = page.nextCursor;
      if (cursor != null && !visited.add(cursor)) {
        throw StateError('Notification pagination returned a repeated cursor');
      }
    } while (cursor != null);
    return items.values.toList();
  }

  @override
  Future<Either<Failure, NotificationEntity>> markRead(String id) => _run(() => _remote.markRead(id));

  @override
  Future<Either<Failure, int>> markAllRead() => _run(() async {
    final items = await _unreadSignals();
    for (final item in items) {
      await _remote.markRead(item.id);
    }
    return items.length;
  });

  @override
  Future<Either<Failure, void>> deleteNotification(String id) => _run(() => _remote.deleteNotification(id));

  @override
  Future<Either<Failure, DeviceEntity>> registerDevice({
    required String token,
    required String platform,
    String? appVersion,
    String? locale,
  }) => _run(() async {
    final device = await _remote.registerDevice(token: token, platform: platform, appVersion: appVersion, locale: locale);
    await _secureStorage.write(AppConstants.secureKeyPushToken, token);
    return device;
  });

  @override
  Future<Either<Failure, void>> unregisterDevice(String token) => _run(() async {
    await _remote.unregisterDevice(token);
    await _secureStorage.delete(AppConstants.secureKeyPushToken);
  });

  @override
  Future<Either<Failure, NotificationPreferencesEntity>> getPreferences() => _run(_remote.getPreferences);

  @override
  Future<Either<Failure, NotificationPreferencesEntity>> updatePreferences({
    required bool pushEnabled,
    required List<String> mutedTypes,
  }) => _run(() => _remote.updatePreferences(pushEnabled: pushEnabled, mutedTypes: mutedTypes));
}
