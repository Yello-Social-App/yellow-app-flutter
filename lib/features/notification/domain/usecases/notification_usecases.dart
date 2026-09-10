import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/notification_repository.dart';

class GetNotificationsParams extends Equatable {
  const GetNotificationsParams({this.page = 0, this.unreadOnly = false});
  final int page;
  final bool unreadOnly;

  @override
  List<Object?> get props => [page, unreadOnly];
}

class GetNotificationsUseCase implements UseCase<NotificationsPage, GetNotificationsParams> {
  GetNotificationsUseCase(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Either<Failure, NotificationsPage>> call(GetNotificationsParams params) =>
      _repository.getNotifications(page: params.page, unreadOnly: params.unreadOnly);
}

class GetUnreadNotificationCountUseCase implements UseCase<int, NoParams> {
  GetUnreadNotificationCountUseCase(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Either<Failure, int>> call(NoParams params) => _repository.getUnreadCount();
}

class MarkAllNotificationsReadUseCase implements UseCase<void, NoParams> {
  MarkAllNotificationsReadUseCase(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Either<Failure, void>> call(NoParams params) => _repository.markAllRead();
}

class MarkNotificationReadUseCase implements UseCase<void, String> {
  MarkNotificationReadUseCase(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Either<Failure, void>> call(String id) => _repository.markRead(id);
}
