import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../../friends/domain/repositories/friends_repository.dart';
import '../../../friends/domain/usecases/friends_usecases.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/usecases/notification_usecases.dart';

enum NotificationsStatus { initial, loading, loaded, error }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.notifications = const [],
    this.errorMessage,
    this.busyRequestIds = const {},
    this.respondedRequestIds = const {},
  });

  final NotificationsStatus status;
  final List<NotificationEntity> notifications;
  final String? errorMessage;

  /// Notification ids with an in-flight accept/decline call — disables
  /// that row's buttons instead of a full-screen spinner (mirrors
  /// `FriendsState.busyIds`).
  final Set<String> busyRequestIds;

  /// Notification ids the viewer has accepted (`true`) or declined
  /// (`false`) *this session*. The backend has no per-notification
  /// "already responded" field, so this is purely local UI state used to
  /// swap a friend-request row's buttons for a status chip once acted on.
  final Map<String, bool> respondedRequestIds;

  int get unreadCount => notifications.where((n) => !n.read).length;

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<NotificationEntity>? notifications,
    String? errorMessage,
    Set<String>? busyRequestIds,
    Map<String, bool>? respondedRequestIds,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      errorMessage: errorMessage,
      busyRequestIds: busyRequestIds ?? this.busyRequestIds,
      respondedRequestIds: respondedRequestIds ?? this.respondedRequestIds,
    );
  }

  @override
  List<Object?> get props =>
      [status, notifications, errorMessage, busyRequestIds, respondedRequestIds];
}

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({
    required GetNotificationsUseCase getNotifications,
    required MarkAllNotificationsReadUseCase markAllRead,
    required MarkNotificationReadUseCase markRead,
    required AcceptFriendRequestUseCase acceptFriendRequest,
    required DeclineFriendRequestUseCase declineFriendRequest,
    required GetFriendRequestsUseCase getFriendRequests,
    required GetFriendsUseCase getFriends,
  })  : _getNotifications = getNotifications,
        _markAllRead = markAllRead,
        _markRead = markRead,
        _acceptFriendRequest = acceptFriendRequest,
        _declineFriendRequest = declineFriendRequest,
        _getFriendRequests = getFriendRequests,
        _getFriends = getFriends,
        super(const NotificationsState());

  final GetNotificationsUseCase _getNotifications;
  final MarkAllNotificationsReadUseCase _markAllRead;
  final MarkNotificationReadUseCase _markRead;
  final AcceptFriendRequestUseCase _acceptFriendRequest;
  final DeclineFriendRequestUseCase _declineFriendRequest;

  /// Same `GET /friends/requests` call the Circle tab uses — needed here to
  /// resolve a notification's *real* friendship/request id. See
  /// [_resolveRequestId].
  final GetFriendRequestsUseCase _getFriendRequests;

  /// Same `GET /friends` call the Circle tab uses — needed here so
  /// [_precomputeRespondedIds] can tell whether a friend-request
  /// notification's request has *already* been resolved (typically via the
  /// Circle tab, since its notification never gets updated/removed — see
  /// [NotificationsState.respondedRequestIds]).
  final GetFriendsUseCase _getFriends;

  Future<void> load() async {
    if (state.status == NotificationsStatus.loaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    emit(state.copyWith(status: NotificationsStatus.loading));
    final result = await _getNotifications(const GetNotificationsParams());

    NotificationsPage? page;
    Failure? failure;
    result.fold((l) => failure = l, (r) => page = r);

    if (page == null) {
      emit(state.copyWith(status: NotificationsStatus.error, errorMessage: failure?.message));
      return;
    }

    final alreadyResponded = await _precomputeRespondedIds(page!.notifications);
    emit(state.copyWith(
      status: NotificationsStatus.loaded,
      notifications: page!.notifications,
      respondedRequestIds: alreadyResponded,
    ));
  }

  /// For every friend-request notification in [notifications], checks
  /// whether its actor is already an accepted friend — true whenever that
  /// request was resolved through some other path (almost always the
  /// Circle tab) before or after its notification showed up here. Without
  /// this, a stale notification would keep showing live Accept/Decline
  /// buttons that can only ever fail (confirmed 2026-09-07: exactly this
  /// happened with a request that turned out to already be accepted). One
  /// `GET /friends` call covers every notification in the list, rather
  /// than one call per row.
  Future<Map<String, bool>> _precomputeRespondedIds(List<NotificationEntity> notifications) async {
    final requests = notifications.where((n) => n.isFriendRequestType);
    if (requests.isEmpty) return const {};

    final result = await _getFriends(const PageParams());
    Set<String> acceptedActorIds = const {};
    result.fold(
      (failure) => appLogger.w('precomputeRespondedIds: GET /friends failed — ${failure.message}'),
      (page) => acceptedActorIds = page.friendships.map((f) => f.userId).toSet(),
    );
    if (acceptedActorIds.isEmpty) return const {};

    return {
      for (final n in requests)
        if (acceptedActorIds.contains(n.actorId)) n.id: true,
    };
  }

  Future<void> markAllRead() async {
    final result = await _markAllRead(const NoParams());
    result.fold((_) {}, (_) {
      emit(state.copyWith(notifications: state.notifications.map((n) => n.copyWith(read: true)).toList()));
    });
  }

  Future<void> openNotification(NotificationEntity notification) async {
    if (notification.read) return;
    final result = await _markRead(notification.id);
    result.fold((_) {}, (_) {
      final next = state.notifications
          .map((n) => n.id == notification.id ? n.copyWith(read: true) : n)
          .toList();
      emit(state.copyWith(notifications: next));
    });
  }

  /// Accepts the friend request behind a FOLLOW/FRIEND_REQUEST
  /// [notification]. **Does not trust `notification.targetId`** as the
  /// friendship/request id — that assumption was flagged unverified, then
  /// confirmed wrong on 2026-09-07 (a real "Could not accept request."
  /// failure on-device; the live spec has never actually documented what
  /// `targetId` is — no field description at all, just `uuid`). Instead
  /// this resolves the real id itself via [_resolveRequestId]. Normally
  /// this is only reached for requests still genuinely pending — a request
  /// already resolved elsewhere gets caught earlier by
  /// [_precomputeRespondedIds] on load, which is what the original bug
  /// report turned out to be (hsomonor's request had already been accepted
  /// via the Circle tab; Signals just never learned that). Returns `false`
  /// (leaving the row's buttons in place) if there's nothing to act on or
  /// the call fails, so the page can show a retry-hinting snackbar.
  Future<bool> acceptFriendRequest(NotificationEntity notification) =>
      _respondToRequest(notification, accept: true);

  /// Declines the friend request behind [notification]. See
  /// [acceptFriendRequest] for why this doesn't use `targetId` directly.
  Future<bool> declineFriendRequest(NotificationEntity notification) =>
      _respondToRequest(notification, accept: false);

  Future<bool> _respondToRequest(NotificationEntity notification, {required bool accept}) async {
    await openNotification(notification);
    emit(state.copyWith(busyRequestIds: {...state.busyRequestIds, notification.id}));

    final requestId = await _resolveRequestId(notification.actorId);
    var ok = false;
    if (requestId != null) {
      if (accept) {
        final result = await _acceptFriendRequest(RequestIdParams(requestId));
        result.fold(
          (failure) => appLogger.w('respondToRequest: accept($requestId) failed — ${failure.message}'),
          (_) {},
        );
        ok = result.fold((_) => false, (_) => true);
      } else {
        final result = await _declineFriendRequest(RequestIdParams(requestId));
        result.fold(
          (failure) => appLogger.w('respondToRequest: decline($requestId) failed — ${failure.message}'),
          (_) {},
        );
        ok = result.fold((_) => false, (_) => true);
      }
    }

    if (ok) {
      emit(state.copyWith(
        respondedRequestIds: {...state.respondedRequestIds, notification.id: accept},
      ));
    }
    emit(state.copyWith(busyRequestIds: {...state.busyRequestIds}..remove(notification.id)));
    return ok;
  }

  /// Finds the pending request sent by [actorId] and returns its real
  /// `FriendshipEntity.id` — the id `PUT /friends/requests/{id}/accept|
  /// decline` actually expects — by walking `GET /friends/requests` (the
  /// same call `FriendsCubit`/the Circle tab already uses) instead of
  /// trusting the notification's own `targetId`. Friend-request lists are
  /// small in practice, so paging all the way through here is cheap;
  /// capped defensively so a backend `hasMore` bug can't spin forever.
  /// Returns `null` if no match turns up — either the request was already
  /// resolved (see [_precomputeRespondedIds], which should normally have
  /// caught that case before this is ever called) or it genuinely no
  /// longer exists.
  Future<String?> _resolveRequestId(String actorId) async {
    for (var page = 0; page < 25; page++) {
      final result = await _getFriendRequests(PageParams(page: page));
      FriendsPage? friendsPage;
      result.fold(
        (failure) => appLogger.w('resolveRequestId: page $page fetch failed — ${failure.message}'),
        (p) => friendsPage = p,
      );
      if (friendsPage == null) return null;

      for (final request in friendsPage!.friendships) {
        if (request.userId == actorId) return request.id;
      }
      if (!friendsPage!.hasMore) return null;
    }
    appLogger.w('resolveRequestId: gave up after 25 pages, no match for actorId=$actorId');
    return null;
  }
}
