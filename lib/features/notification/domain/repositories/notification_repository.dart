import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/device_entity.dart';
import '../entities/notification_entity.dart';
import '../entities/notification_preferences_entity.dart';

abstract interface class NotificationRepository {
  Future<Either<Failure, NotificationsPage>> getInbox({int size = 20, String? cursor, bool unreadOnly = false});
  Future<Either<Failure, int>> getUnreadCount();
  Future<Either<Failure, NotificationEntity>> markRead(String id);
  Future<Either<Failure, int>> markAllRead();
  Future<Either<Failure, void>> deleteNotification(String id);

  /// Registers/refreshes this device's push token. On success, the token is
  /// cached locally (see impl) so [unregisterDevice] can be called with it
  /// on logout without needing a fresh read from the push SDK at that
  /// moment.
  Future<Either<Failure, DeviceEntity>> registerDevice({
    required String token,
    required String platform,
    String? appVersion,
    String? locale,
  });

  Future<Either<Failure, void>> unregisterDevice(String token);

  Future<Either<Failure, NotificationPreferencesEntity>> getPreferences();
  Future<Either<Failure, NotificationPreferencesEntity>> updatePreferences({
    required bool pushEnabled,
    required List<String> mutedTypes,
  });
}
