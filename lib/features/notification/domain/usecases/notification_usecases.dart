import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/device_entity.dart';
import '../entities/notification_entity.dart';
import '../entities/notification_preferences_entity.dart';
import '../repositories/notification_repository.dart';

class GetInboxParams extends Equatable {
  const GetInboxParams({this.size = 20, this.cursor, this.unreadOnly = false});
  final int size;
  final String? cursor;
  final bool unreadOnly;

  @override
  List<Object?> get props => [size, cursor, unreadOnly];
}

class GetInboxUseCase implements UseCase<NotificationsPage, GetInboxParams> {
  GetInboxUseCase(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Either<Failure, NotificationsPage>> call(GetInboxParams params) =>
      _repository.getInbox(size: params.size, cursor: params.cursor, unreadOnly: params.unreadOnly);
}

class GetUnreadNotificationCountUseCase implements UseCase<int, NoParams> {
  GetUnreadNotificationCountUseCase(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Either<Failure, int>> call(NoParams params) => _repository.getUnreadCount();
}

class MarkNotificationReadUseCase implements UseCase<NotificationEntity, String> {
  MarkNotificationReadUseCase(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Either<Failure, NotificationEntity>> call(String id) => _repository.markRead(id);
}

class MarkAllNotificationsReadUseCase implements UseCase<int, NoParams> {
  MarkAllNotificationsReadUseCase(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Either<Failure, int>> call(NoParams params) => _repository.markAllRead();
}

class DeleteNotificationUseCase implements UseCase<void, String> {
  DeleteNotificationUseCase(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Either<Failure, void>> call(String id) => _repository.deleteNotification(id);
}

class RegisterDeviceParams extends Equatable {
  const RegisterDeviceParams({required this.token, required this.platform, this.appVersion, this.locale});
  final String token;
  final String platform;
  final String? appVersion;
  final String? locale;

  @override
  List<Object?> get props => [token, platform, appVersion, locale];
}

class RegisterDeviceUseCase implements UseCase<DeviceEntity, RegisterDeviceParams> {
  RegisterDeviceUseCase(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Either<Failure, DeviceEntity>> call(RegisterDeviceParams params) => _repository.registerDevice(
    token: params.token,
    platform: params.platform,
    appVersion: params.appVersion,
    locale: params.locale,
  );
}

class UnregisterDeviceUseCase implements UseCase<void, String> {
  UnregisterDeviceUseCase(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Either<Failure, void>> call(String token) => _repository.unregisterDevice(token);
}

class GetNotificationPreferencesUseCase implements UseCase<NotificationPreferencesEntity, NoParams> {
  GetNotificationPreferencesUseCase(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Either<Failure, NotificationPreferencesEntity>> call(NoParams params) => _repository.getPreferences();
}

class UpdateNotificationPreferencesParams extends Equatable {
  const UpdateNotificationPreferencesParams({required this.pushEnabled, required this.mutedTypes});
  final bool pushEnabled;
  final List<String> mutedTypes;

  @override
  List<Object?> get props => [pushEnabled, mutedTypes];
}

class UpdateNotificationPreferencesUseCase
    implements UseCase<NotificationPreferencesEntity, UpdateNotificationPreferencesParams> {
  UpdateNotificationPreferencesUseCase(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Either<Failure, NotificationPreferencesEntity>> call(UpdateNotificationPreferencesParams params) =>
      _repository.updatePreferences(pushEnabled: params.pushEnabled, mutedTypes: params.mutedTypes);
}
