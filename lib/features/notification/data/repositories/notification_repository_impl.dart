import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_datasource.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._remote, this._networkInfo);

  final NotificationRemoteDataSource _remote;
  final NetworkInfo _networkInfo;

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
  Future<Either<Failure, NotificationsPage>> getNotifications({int page = 0, bool unreadOnly = false}) =>
      _run(() async {
        final result = await _remote.getNotifications(page: page, unreadOnly: unreadOnly);
        return NotificationsPage(notifications: result.items, hasMore: result.hasMore);
      });

  @override
  Future<Either<Failure, int>> getUnreadCount() => _run(_remote.getUnreadCount);

  @override
  Future<Either<Failure, void>> markAllRead() => _run(_remote.markAllRead);

  @override
  Future<Either<Failure, void>> markRead(String id) => _run(() => _remote.markRead(id));
}
