import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../../friends/domain/repositories/friends_repository.dart';
import '../../../friends/domain/usecases/friends_usecases.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/usecases/notification_usecases.dart';

enum NotificationsStatus { initial, loading, loaded, error }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.items = const [],
    this.nextCursor,
    this.isLoadingMore = false,
    this.unreadCount = 0,
    this.errorMessage,
    this.busyRequestIds = const {},
    this.respondedRequestIds = const {},
  });

  final NotificationsStatus status;
  final List<NotificationEntity> items;
  final String? nextCursor;
  final bool isLoadingMore;

  /// From `GET /unread-count` — kept as its own field rather than derived
  /// from [items] because the badge must be right (and paintable) before
  /// any inbox page has loaded, and chat pushes are excluded from this
  /// count server-side, something a locally-derived count could never know.
  final int unreadCount;

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

  bool get hasMore => nextCursor != null;

  /// `nextCursor: null` has to mean "no more pages" — see `MessagesState`'s
  /// identical `_unset` sentinel for why a plain `??` default can't do that.
  static const Object _unset = Object();

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<NotificationEntity>? items,
    Object? nextCursor = _unset,
    bool? isLoadingMore,
    int? unreadCount,
    String? errorMessage,
    Set<String>? busyRequestIds,
    Map<String, bool>? respondedRequestIds,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      items: items ?? this.items,
      nextCursor: identical(nextCursor, _unset) ? this.nextCursor : nextCursor as String?,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      unreadCount: unreadCount ?? this.unreadCount,
      errorMessage: errorMessage,
      busyRequestIds: busyRequestIds ?? this.busyRequestIds,
      respondedRequestIds: respondedRequestIds ?? this.respondedRequestIds,
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    nextCursor,
    isLoadingMore,
    unreadCount,
    errorMessage,
    busyRequestIds,
    respondedRequestIds,
  ];
}

/// Owns the Signals tab's inbox *and* the bottom-nav unread badge — a
/// long-lived singleton (like `MessagesCubit`/`FeedCubit`) so the badge
/// stays live across tab switches instead of resetting to a fresh, empty
/// state every time `BottomNavBar` resolves it via `sl<NotificationsCubit>()`.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({
    required GetInboxUseCase getInbox,
    required GetUnreadNotificationCountUseCase getUnreadCount,
    required MarkNotificationReadUseCase markRead,
    required MarkAllNotificationsReadUseCase markAllRead,
    required DeleteNotificationUseCase deleteNotification,
    required AcceptFriendRequestUseCase acceptFriendRequest,
    required DeclineFriendRequestUseCase declineFriendRequest,
    required GetFriendRequestsUseCase getFriendRequests,
    required GetFriendsUseCase getFriends,
  }) : _getInbox = getInbox,
       _getUnreadCount = getUnreadCount,
       _markRead = markRead,
       _markAllRead = markAllRead,
       _deleteNotification = deleteNotification,
       _acceptFriendRequest = acceptFriendRequest,
       _declineFriendRequest = declineFriendRequest,
       _getFriendRequests = getFriendRequests,
       _getFriends = getFriends,
       super(const NotificationsState());

  final GetInboxUseCase _getInbox;
  final GetUnreadNotificationCountUseCase _getUnreadCount;
  final MarkNotificationReadUseCase _markRead;
  final MarkAllNotificationsReadUseCase _markAllRead;
  final DeleteNotificationUseCase _deleteNotification;
  final AcceptFriendRequestUseCase _acceptFriendRequest;
  final DeclineFriendRequestUseCase _declineFriendRequest;

  /// Same `GET /friends/requests` call the Circle tab uses — needed here to
  /// resolve a notification's *real* friendship/request id. See
  /// [_resolveRequestId].
  final GetFriendRequestsUseCase _getFriendRequests;

  /// Same `GET /friends` call the Circle tab uses — needed here so
  /// [_precomputeRespondedIds] can tell whether a friend-request
  /// notification's request has *already* been resolved (typically via the
  /// Circle tab, since its notification row is never removed/updated by the
  /// backend on its own — see [NotificationsState.respondedRequestIds]).
  final GetFriendsUseCase _getFriends;

  static const _pageSize = 20;

  Future<void> load() async {
    if (state.status == NotificationsStatus.loaded) return;
    await refresh();
  }

  /// Client flow per the service's own docs: paint the badge from a cheap
  /// `unread-count` call, then load the first inbox page — done together
  /// here since this cubit backs both the badge and the Signals screen.
  Future<void> refresh() async {
    emit(state.copyWith(status: NotificationsStatus.loading));

    final results = await Future.wait<dynamic>([
      _getUnreadCount(const NoParams()),
      _getInbox(const GetInboxParams(size: _pageSize)),
    ]);
    // A pop while this is in flight closes this factory-turned-singleton's
    // subscribers, but not the cubit itself — still guard against emitting
    // into a disposed instance the same way every other cubit here does.
    if (isClosed) return;

    final countResult = results[0] as Either<Failure, int>;
    final pageResult = results[1] as Either<Failure, NotificationsPage>;

    NotificationsPage? page;
    Failure? failure;
    pageResult.fold((l) => failure = l, (r) => page = r);
    final unread = countResult.fold((_) => state.unreadCount, (count) => count);

    if (page == null) {
      emit(state.copyWith(status: NotificationsStatus.error, errorMessage: failure?.message, unreadCount: unread));
      return;
    }

    final alreadyResponded = await _precomputeRespondedIds(page!.items);
    if (isClosed) return;
    emit(
      state.copyWith(
        status: NotificationsStatus.loaded,
        items: page!.items,
        nextCursor: page!.nextCursor,
        unreadCount: unread,
        respondedRequestIds: alreadyResponded,
      ),
    );
  }

  /// Just the badge — cheap enough to call from anywhere the count might
  /// have gone stale (e.g. a future app-foreground hook) without pulling a
  /// full inbox page along with it.
  Future<void> refreshUnreadCount() async {
    final result = await _getUnreadCount(const NoParams());
    if (isClosed) return;
    result.fold(
      (failure) => appLogger.w('refreshUnreadCount failed — ${failure.message}'),
      (count) => emit(state.copyWith(unreadCount: count)),
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true));

    final result = await _getInbox(GetInboxParams(size: _pageSize, cursor: state.nextCursor));
    if (isClosed) return;
    result.fold(
      (_) => emit(state.copyWith(isLoadingMore: false)),
      (page) => emit(
        state.copyWith(
          items: _dedupeAppend(state.items, page.items),
          nextCursor: page.nextCursor,
          isLoadingMore: false,
        ),
      ),
    );
  }

  /// Appends [incoming] after [existing], dropping any id already present.
  /// Aggregation can bump a row to the top of the *server's* ordering
  /// between two page fetches during a cursor walk, which would otherwise
  /// surface the same id twice — see `NotificationEntity.updatedAt`'s doc.
  List<NotificationEntity> _dedupeAppend(List<NotificationEntity> existing, List<NotificationEntity> incoming) {
    final seenIds = existing.map((n) => n.id).toSet();
    return [...existing, ...incoming.where((n) => seenIds.add(n.id))];
  }

  /// For every friend-request notification in [items], checks whether its
  /// actor is already an accepted friend — true whenever that request was
  /// resolved through some other path (almost always the Circle tab) before
  /// or after its notification showed up here. Without this, a stale
  /// notification would keep showing live Accept/Decline buttons that can
  /// only ever fail. One `GET /friends` call covers every notification in
  /// the list, rather than one call per row.
  Future<Map<String, bool>> _precomputeRespondedIds(List<NotificationEntity> items) async {
    final requests = items.where((n) => n.isFriendRequestReceived);
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
        if (n.actorId != null && acceptedActorIds.contains(n.actorId)) n.id: true,
    };
  }

  Future<void> markAllRead() async {
    final result = await _markAllRead(const NoParams());
    if (isClosed) return;
    result.fold(
      (_) {},
      // `updated` counts only rows that *were* unread — the badge goes to
      // exactly 0 either way, so it's set directly rather than by
      // subtracting `updated` (which the client-flow doc calls out
      // explicitly: "Set the badge to 0 locally rather than re-fetching").
      (_) => emit(
        state.copyWith(
          items: state.items.map((n) => n.read ? n : n.copyWith(read: true)).toList(),
          unreadCount: 0,
        ),
      ),
    );
  }

  /// Marks [notification] read on tap. A no-op for an already-read row —
  /// marking read is idempotent server-side too, but skipping the call
  /// entirely avoids spending write-rate-limit budget (120/minute, shared
  /// with every other mutating call) on an idle user re-tapping old rows.
  Future<void> openNotification(NotificationEntity notification) async {
    if (notification.read) return;
    final result = await _markRead(notification.id);
    if (isClosed) return;
    result.fold((_) {}, (updated) {
      final next = state.items.map((n) => n.id == notification.id ? updated : n).toList();
      emit(state.copyWith(items: next, unreadCount: _decrement(state.unreadCount)));
    });
  }

  /// Swipe-to-dismiss. Removing the row locally on success rather than
  /// refetching — a repeat delete of the same id is a real 404 (unlike
  /// device unregister), so this must not be called twice for one swipe.
  Future<bool> deleteNotification(NotificationEntity notification) async {
    final result = await _deleteNotification(notification.id);
    if (isClosed) return false;
    return result.fold((failure) {
      appLogger.w('deleteNotification(${notification.id}) failed — ${failure.message}');
      return false;
    }, (_) {
      final wasUnread = !notification.read;
      emit(
        state.copyWith(
          items: state.items.where((n) => n.id != notification.id).toList(),
          unreadCount: wasUnread ? _decrement(state.unreadCount) : state.unreadCount,
        ),
      );
      return true;
    });
  }

  int _decrement(int count) => count > 0 ? count - 1 : 0;

  /// Accepts the friend request behind a `FRIEND_REQUEST_RECEIVED`
  /// [notification]. **Does not trust `notification.data['requestId']`** —
  /// the spec documents no such field, only `actorId`, so this resolves the
  /// real friendship/request id itself via [_resolveRequestId]. Normally
  /// only reached for requests still genuinely pending — one already
  /// resolved elsewhere is caught earlier by [_precomputeRespondedIds] on
  /// load. Returns `false` (leaving the row's buttons in place) if there's
  /// nothing to act on or the call fails, so the page can show a
  /// retry-hinting snackbar.
  Future<bool> acceptFriendRequest(NotificationEntity notification) => _respondToRequest(notification, accept: true);

  /// Declines the friend request behind [notification]. See
  /// [acceptFriendRequest] for why this doesn't trust the `data` map for an
  /// id.
  Future<bool> declineFriendRequest(NotificationEntity notification) => _respondToRequest(notification, accept: false);

  Future<bool> _respondToRequest(NotificationEntity notification, {required bool accept}) async {
    await openNotification(notification);
    if (isClosed) return false;
    emit(state.copyWith(busyRequestIds: {...state.busyRequestIds, notification.id}));

    final actorId = notification.actorId;
    final requestId = actorId == null ? null : await _resolveRequestId(actorId);
    if (isClosed) return false;
    var ok = false;
    if (requestId != null) {
      final result = accept
          ? await _acceptFriendRequest(RequestIdParams(requestId))
          : await _declineFriendRequest(RequestIdParams(requestId));
      result.fold(
        (failure) => appLogger.w('respondToRequest: ${accept ? "accept" : "decline"}($requestId) failed — ${failure.message}'),
        (_) {},
      );
      ok = result.fold((_) => false, (_) => true);
    }

    if (isClosed) return ok;
    if (ok) {
      emit(state.copyWith(respondedRequestIds: {...state.respondedRequestIds, notification.id: accept}));
    }
    emit(state.copyWith(busyRequestIds: {...state.busyRequestIds}..remove(notification.id)));
    return ok;
  }

  /// Finds the pending request sent by [actorId] and returns its real
  /// `FriendshipEntity.id` — the id `POST /friends/requests/{id}/accept|
  /// decline` actually expects — by walking `GET /friends/requests` (the
  /// same call `FriendsCubit`/the Circle tab already uses). Friend-request
  /// lists are small in practice, so paging all the way through here is
  /// cheap; capped defensively so a backend `hasMore` bug can't spin
  /// forever. Returns `null` if no match turns up — either the request was
  /// already resolved (see [_precomputeRespondedIds], which should
  /// normally have caught that case before this is ever called) or it
  /// genuinely no longer exists.
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
