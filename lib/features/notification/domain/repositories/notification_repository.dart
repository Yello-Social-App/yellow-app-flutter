import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/notification_entity.dart';

class NotificationsPage {
  const NotificationsPage({required this.notifications, required this.hasMore});
  final List<NotificationEntity> notifications;
  final bool hasMore;
}

abstract interface class NotificationRepository {
  Future<Either<Failure, NotificationsPage>> getNotifications({int page = 0, bool unreadOnly = false});
  Future<Either<Failure, int>> getUnreadCount();
  Future<Either<Failure, void>> markAllRead();
  Future<Either<Failure, void>> markRead(String id);
}
