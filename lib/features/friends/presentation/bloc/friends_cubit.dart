import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/friendship_entity.dart';
import '../../domain/usecases/friends_usecases.dart';

enum FriendsStatus { initial, loading, loaded, error }

class FriendsState extends Equatable {
  const FriendsState({
    this.status = FriendsStatus.initial,
    this.friends = const [],
    this.requests = const [],
    this.errorMessage,
    this.busyIds = const {},
  });

  final FriendsStatus status;
  final List<FriendshipEntity> friends;
  final List<FriendshipEntity> requests;
  final String? errorMessage;

  /// Request/friend ids with an in-flight accept/decline/unfriend call —
  /// used to disable that row's buttons instead of a full-screen spinner.
  final Set<String> busyIds;

  FriendsState copyWith({
    FriendsStatus? status,
    List<FriendshipEntity>? friends,
    List<FriendshipEntity>? requests,
    String? errorMessage,
    Set<String>? busyIds,
  }) {
    return FriendsState(
      status: status ?? this.status,
      friends: friends ?? this.friends,
      requests: requests ?? this.requests,
      errorMessage: errorMessage,
      busyIds: busyIds ?? this.busyIds,
    );
  }

  @override
  List<Object?> get props => [status, friends, requests, errorMessage, busyIds];
}

class FriendsCubit extends Cubit<FriendsState> {
  FriendsCubit({
    required GetFriendsUseCase getFriends,
    required GetFriendRequestsUseCase getRequests,
    required AcceptFriendRequestUseCase acceptRequest,
    required DeclineFriendRequestUseCase declineRequest,
    required UnfriendUseCase unfriend,
  })  : _getFriends = getFriends,
        _getRequests = getRequests,
        _acceptRequest = acceptRequest,
        _declineRequest = declineRequest,
        _unfriend = unfriend,
        super(const FriendsState());

  final GetFriendsUseCase _getFriends;
  final GetFriendRequestsUseCase _getRequests;
  final AcceptFriendRequestUseCase _acceptRequest;
  final DeclineFriendRequestUseCase _declineRequest;
  final UnfriendUseCase _unfriend;

  Future<void> load() async {
    if (state.status == FriendsStatus.loaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    emit(state.copyWith(status: FriendsStatus.loading));

    Failure? failure;
    List<FriendshipEntity> friends = state.friends;
    List<FriendshipEntity> requests = state.requests;

    (await _getFriends(const PageParams())).fold((l) => failure = l, (r) => friends = r.friendships);
    (await _getRequests(const PageParams())).fold((l) => failure ??= l, (r) => requests = r.friendships);

    if (failure != null) {
      emit(state.copyWith(status: FriendsStatus.error, errorMessage: failure!.message));
      return;
    }
    emit(state.copyWith(status: FriendsStatus.loaded, friends: friends, requests: requests));
  }

  Future<void> accept(String requestId) async {
    emit(state.copyWith(busyIds: {...state.busyIds, requestId}));
    final result = await _acceptRequest(RequestIdParams(requestId));
    result.fold((_) {}, (accepted) {
      emit(state.copyWith(
        requests: state.requests.where((r) => r.id != requestId).toList(),
        friends: [accepted, ...state.friends],
      ));
    });
    emit(state.copyWith(busyIds: {...state.busyIds}..remove(requestId)));
  }

  Future<void> decline(String requestId) async {
    emit(state.copyWith(busyIds: {...state.busyIds, requestId}));
    final result = await _declineRequest(RequestIdParams(requestId));
    result.fold((_) {}, (_) {
      emit(state.copyWith(requests: state.requests.where((r) => r.id != requestId).toList()));
    });
    emit(state.copyWith(busyIds: {...state.busyIds}..remove(requestId)));
  }

  Future<void> unfriend(String userId) async {
    emit(state.copyWith(busyIds: {...state.busyIds, userId}));
    final result = await _unfriend(UserIdParams(userId));
    result.fold((_) {}, (_) {
      emit(state.copyWith(friends: state.friends.where((f) => f.userId != userId).toList()));
    });
    emit(state.copyWith(busyIds: {...state.busyIds}..remove(userId)));
  }
}
