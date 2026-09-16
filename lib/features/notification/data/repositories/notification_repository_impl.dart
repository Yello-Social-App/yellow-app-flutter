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
        final result = await _remote.getInbox(size: size, cursor: cursor, unreadOnly: unreadOnly);
        return NotificationsPage(items: result.items, nextCursor: result.nextCursor);
      });

  @override
  Future<Either<Failure, int>> getUnreadCount() => _run(_remote.getUnreadCount);

  @override
  Future<Either<Failure, NotificationEntity>> markRead(String id) => _run(() => _remote.markRead(id));

  @override
  Future<Either<Failure, int>> markAllRead() => _run(_remote.markAllRead);

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
