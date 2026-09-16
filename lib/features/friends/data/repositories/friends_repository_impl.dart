import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/friendship_entity.dart';
import '../../domain/repositories/friends_repository.dart';
import '../datasources/friends_remote_datasource.dart';

class FriendsRepositoryImpl implements FriendsRepository {
  FriendsRepositoryImpl(this._remote, this._networkInfo);

  final FriendsRemoteDataSource _remote;
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
  Future<Either<Failure, FriendsPage>> getFriends({int page = 0}) => _run(() async {
        final result = await _remote.getFriends(page: page);
        return FriendsPage(friendships: result.items, hasMore: result.hasMore);
      });

  @override
  Future<Either<Failure, FriendsPage>> getRequests({int page = 0, bool sent = false}) => _run(() async {
        final result = await _remote.getRequests(
          page: page,
          direction: sent ? RequestDirection.sent : RequestDirection.received,
        );
        return FriendsPage(friendships: result.items, hasMore: result.hasMore);
      });

  @override
  Future<Either<Failure, FriendsPage>> getBlocked({int page = 0}) => _run(() async {
        final result = await _remote.getBlocked(page: page);
        return FriendsPage(friendships: result.items, hasMore: result.hasMore);
      });

  @override
  Future<Either<Failure, void>> sendRequest(String userId) => _run(() => _remote.sendRequest(userId));

  @override
  Future<Either<Failure, void>> cancelRequest(String userId) => _run(() => _remote.cancelRequest(userId));

  @override
  Future<Either<Failure, FriendshipEntity>> acceptRequest(String userId) =>
      _run(() => _remote.acceptRequest(userId));

  @override
  Future<Either<Failure, void>> declineRequest(String userId) => _run(() => _remote.declineRequest(userId));

  @override
  Future<Either<Failure, void>> unfriend(String userId) => _run(() => _remote.unfriend(userId));

  @override
  Future<Either<Failure, FriendshipEntity>> blockUser(String userId) => _run(() => _remote.blockUser(userId));

  @override
  Future<Either<Failure, FriendshipEntity>> unblockUser(String userId) =>
      _run(() => _remote.unblockUser(userId));
}
