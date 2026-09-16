import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/friendship_entity.dart';
import '../repositories/friends_repository.dart';

class PageParams extends Equatable {
  const PageParams({this.page = 0, this.sent = false});

  final int page;

  /// Only meaningful for [GetFriendRequestsUseCase]: false lists requests
  /// waiting on you, true the ones you sent. Ignored elsewhere.
  final bool sent;

  @override
  List<Object?> get props => [page, sent];
}

class GetFriendsUseCase implements UseCase<FriendsPage, PageParams> {
  GetFriendsUseCase(this._repository);
  final FriendsRepository _repository;

  @override
  Future<Either<Failure, FriendsPage>> call(PageParams params) => _repository.getFriends(page: params.page);
}

class GetFriendRequestsUseCase implements UseCase<FriendsPage, PageParams> {
  GetFriendRequestsUseCase(this._repository);
  final FriendsRepository _repository;

  @override
  Future<Either<Failure, FriendsPage>> call(PageParams params) =>
      _repository.getRequests(page: params.page, sent: params.sent);
}

class GetBlockedUsersUseCase implements UseCase<FriendsPage, PageParams> {
  GetBlockedUsersUseCase(this._repository);
  final FriendsRepository _repository;

  @override
  Future<Either<Failure, FriendsPage>> call(PageParams params) => _repository.getBlocked(page: params.page);
}

class UserIdParams extends Equatable {
  const UserIdParams(this.userId);
  final String userId;

  @override
  List<Object?> get props => [userId];
}

class SendFriendRequestUseCase implements UseCase<void, UserIdParams> {
  SendFriendRequestUseCase(this._repository);
  final FriendsRepository _repository;

  @override
  Future<Either<Failure, void>> call(UserIdParams params) => _repository.sendRequest(params.userId);
}

class CancelFriendRequestUseCase implements UseCase<void, UserIdParams> {
  CancelFriendRequestUseCase(this._repository);
  final FriendsRepository _repository;

  @override
  Future<Either<Failure, void>> call(UserIdParams params) => _repository.cancelRequest(params.userId);
}

/// Despite the name, [requestId] is the **other user's id** — the API has no
/// friendship-row id and addresses every request route by user. The name is
/// kept so existing call sites in `FriendsCubit` and `PublicProfileCubit`
/// keep compiling; both already pass `FriendshipEntity.id`, which is that
/// user's id.
class RequestIdParams extends Equatable {
  const RequestIdParams(this.requestId);
  final String requestId;

  @override
  List<Object?> get props => [requestId];
}

class AcceptFriendRequestUseCase implements UseCase<FriendshipEntity, RequestIdParams> {
  AcceptFriendRequestUseCase(this._repository);
  final FriendsRepository _repository;

  @override
  Future<Either<Failure, FriendshipEntity>> call(RequestIdParams params) =>
      _repository.acceptRequest(params.requestId);
}

class DeclineFriendRequestUseCase implements UseCase<void, RequestIdParams> {
  DeclineFriendRequestUseCase(this._repository);
  final FriendsRepository _repository;

  @override
  Future<Either<Failure, void>> call(RequestIdParams params) => _repository.declineRequest(params.requestId);
}

class UnfriendUseCase implements UseCase<void, UserIdParams> {
  UnfriendUseCase(this._repository);
  final FriendsRepository _repository;

  @override
  Future<Either<Failure, void>> call(UserIdParams params) => _repository.unfriend(params.userId);
}

class BlockUserUseCase implements UseCase<FriendshipEntity, UserIdParams> {
  BlockUserUseCase(this._repository);
  final FriendsRepository _repository;

  @override
  Future<Either<Failure, FriendshipEntity>> call(UserIdParams params) => _repository.blockUser(params.userId);
}

class UnblockUserUseCase implements UseCase<FriendshipEntity, UserIdParams> {
  UnblockUserUseCase(this._repository);
  final FriendsRepository _repository;

  @override
  Future<Either<Failure, FriendshipEntity>> call(UserIdParams params) =>
      _repository.unblockUser(params.userId);
}
