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
    this.sentRequests = const [],
    this.blocked = const [],
    this.errorMessage,
    this.busyIds = const {},
  });

  final FriendsStatus status;
  final List<FriendshipEntity> friends;

  /// Requests waiting on the viewer (`direction=received`).
  final List<FriendshipEntity> requests;

  /// Requests the viewer sent that are still pending (`direction=sent`).
  final List<FriendshipEntity> sentRequests;

  /// People the viewer blocked (`GET /friends/blocked`). Only ever blocks
  /// *by* the viewer — the API never reveals being blocked.
  final List<FriendshipEntity> blocked;

  final String? errorMessage;

  /// Request/friend ids with an in-flight accept/decline/cancel/unfriend/unblock call —
  /// used to disable that row's buttons instead of a full-screen spinner.
  final Set<String> busyIds;

  FriendsState copyWith({
    FriendsStatus? status,
    List<FriendshipEntity>? friends,
    List<FriendshipEntity>? requests,
    List<FriendshipEntity>? sentRequests,
    List<FriendshipEntity>? blocked,
    String? errorMessage,
    Set<String>? busyIds,
  }) {
    return FriendsState(
      status: status ?? this.status,
      friends: friends ?? this.friends,
      requests: requests ?? this.requests,
      sentRequests: sentRequests ?? this.sentRequests,
      blocked: blocked ?? this.blocked,
      errorMessage: errorMessage,
      busyIds: busyIds ?? this.busyIds,
    );
  }

  @override
  List<Object?> get props => [status, friends, requests, sentRequests, blocked, errorMessage, busyIds];
}

class FriendsCubit extends Cubit<FriendsState> {
  FriendsCubit({
    required GetFriendsUseCase getFriends,
    required GetFriendRequestsUseCase getRequests,
    required AcceptFriendRequestUseCase acceptRequest,
    required DeclineFriendRequestUseCase declineRequest,
    required CancelFriendRequestUseCase cancelRequest,
    required UnfriendUseCase unfriend,
    required GetBlockedUsersUseCase getBlocked,
    required UnblockUserUseCase unblock,
  }) : _getFriends = getFriends,
       _getRequests = getRequests,
       _acceptRequest = acceptRequest,
       _declineRequest = declineRequest,
       _cancelRequest = cancelRequest,
       _unfriend = unfriend,
       _getBlocked = getBlocked,
       _unblock = unblock,
       super(const FriendsState());

  final GetFriendsUseCase _getFriends;
  final GetFriendRequestsUseCase _getRequests;
  final AcceptFriendRequestUseCase _acceptRequest;
  final DeclineFriendRequestUseCase _declineRequest;
  final CancelFriendRequestUseCase _cancelRequest;
  final UnfriendUseCase _unfriend;
  final GetBlockedUsersUseCase _getBlocked;
  final UnblockUserUseCase _unblock;

  Future<void> load() async {
    if (state.status == FriendsStatus.loaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    emit(state.copyWith(status: FriendsStatus.loading));

    Failure? failure;
    List<FriendshipEntity> friends = state.friends;
    List<FriendshipEntity> requests = state.requests;
    List<FriendshipEntity> sentRequests = state.sentRequests;
    List<FriendshipEntity> blocked = state.blocked;

    // Four independent reads, fetched together rather than back to back.
    final results = await Future.wait([
      _getFriends(const PageParams()),
      _getRequests(const PageParams()),
      _getRequests(const PageParams(sent: true)),
      _getBlocked(const PageParams()),
    ]);
    // A pop (or leaving the Circle branch's page) while this is in flight
    // can close this factory cubit before it resolves. Same guard
    // `ReactorsCubit.load()` documents.
    if (isClosed) return;
    results[0].fold((l) => failure = l, (r) => friends = r.friendships);
    results[1].fold((l) => failure ??= l, (r) => requests = r.friendships);
    results[2].fold((l) => failure ??= l, (r) => sentRequests = r.friendships);
    results[3].fold((l) => failure ??= l, (r) => blocked = r.friendships);

    if (failure != null) {
      emit(state.copyWith(status: FriendsStatus.error, errorMessage: failure!.message));
      return;
    }
    emit(
      state.copyWith(
        status: FriendsStatus.loaded,
        friends: friends,
        requests: requests,
        sentRequests: sentRequests,
        blocked: blocked,
      ),
    );
  }

  Future<void> accept(String requestId) async {
    emit(state.copyWith(busyIds: {...state.busyIds, requestId}));
    final result = await _acceptRequest(RequestIdParams(requestId));
    if (isClosed) return;
    result.fold((_) {}, (accepted) {
      emit(
        state.copyWith(
          requests: state.requests.where((r) => r.id != requestId).toList(),
          friends: [accepted, ...state.friends],
        ),
      );
    });
    emit(state.copyWith(busyIds: {...state.busyIds}..remove(requestId)));
  }

  Future<void> decline(String requestId) async {
    emit(state.copyWith(busyIds: {...state.busyIds, requestId}));
    final result = await _declineRequest(RequestIdParams(requestId));
    if (isClosed) return;
    result.fold((_) {}, (_) {
      emit(state.copyWith(requests: state.requests.where((r) => r.id != requestId).toList()));
    });
    emit(state.copyWith(busyIds: {...state.busyIds}..remove(requestId)));
  }

  /// Withdraws a request the viewer sent. Keyed by the other user's id, like
  /// every friendship route.
  Future<void> cancel(String userId) async {
    emit(state.copyWith(busyIds: {...state.busyIds, userId}));
    final result = await _cancelRequest(UserIdParams(userId));
    if (isClosed) return;
    result.fold((_) {}, (_) {
      emit(state.copyWith(sentRequests: state.sentRequests.where((r) => r.userId != userId).toList()));
    });
    emit(state.copyWith(busyIds: {...state.busyIds}..remove(userId)));
  }

  Future<void> unfriend(String userId) async {
    emit(state.copyWith(busyIds: {...state.busyIds, userId}));
    final result = await _unfriend(UserIdParams(userId));
    if (isClosed) return;
    result.fold((_) {}, (_) {
      emit(state.copyWith(friends: state.friends.where((f) => f.userId != userId).toList()));
    });
    emit(state.copyWith(busyIds: {...state.busyIds}..remove(userId)));
  }

  Future<void> unblock(String userId) async {
    emit(state.copyWith(busyIds: {...state.busyIds, userId}));
    final result = await _unblock(UserIdParams(userId));
    if (isClosed) return;
    result.fold((_) {}, (_) {
      emit(state.copyWith(blocked: state.blocked.where((b) => b.userId != userId).toList()));
    });
    emit(state.copyWith(busyIds: {...state.busyIds}..remove(userId)));
  }
}
