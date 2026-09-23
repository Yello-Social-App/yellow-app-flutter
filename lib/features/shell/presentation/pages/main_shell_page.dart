import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../feed/presentation/bloc/feed_cubit.dart';
import '../../../chat/presentation/bloc/messages_cubit.dart';
import '../../../notification/presentation/bloc/notifications_cubit.dart';
import '../widgets/bottom_nav_bar.dart';

/// Wraps the bottom-nav tabs (Feed/Circle/Inbox/Signals/Profile/Explore) in
/// a [StatefulShellRoute], so each keeps its own scroll position across tab
/// switches — the go_router-idiomatic equivalent of the mockup's single
/// always-mounted page with a `tab` flag.
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> with WidgetsBindingObserver {
  bool _navVisible = true;
  StreamSubscription<void>? _pushUpdates;
  StreamSubscription<void>? _notificationTaps;
  Timer? _inboxRefreshTimer;

  /// Router *branch* indexes, as wired in `AppRouter`'s [StatefulShellRoute].
  static const int _feedBranch = 0;
  static const int _inboxBranch = 2;
  static const int _signalsBranch = 3;

  /// How often the Inbox/Signals badges are re-polled while the shell is
  /// mounted, foregrounded and authenticated.
  ///
  /// Two cadences, because a tick's cost is fixed but what it buys depends on
  /// where the user is: on the Inbox tab the conversation *list* is on screen,
  /// so staleness is visible; everywhere else only the bottom bar's unread dot
  /// is, and that moves rarely. This was a flat 5s, which meant ~24 requests a
  /// minute sitting idle on Feed — see ADR-010 in `docs/DECISIONS.md`.
  static const Duration _pollFast = Duration(seconds: 10);
  static const Duration _pollSlow = Duration(seconds: 30);

  Duration get _pollInterval => widget.navigationShell.currentIndex == _inboxBranch ? _pollFast : _pollSlow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pushUpdates = sl<PushNotificationService>().updates.listen((_) => _refreshActivity());
    _notificationTaps = sl<PushNotificationService>().notificationTaps.listen((_) => _openPushDestination());
    // Also covers notification launches before the shell was mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshActivity();
      _openPushDestination();
    });
    _startInboxRefreshTimer();
  }

  /// Follows a tapped push to the screen its `data` names — a conversation,
  /// a post, or a profile (see `PushDestination`). The tab that owns that
  /// screen is selected first so Back has a useful destination even after a
  /// cold start, and the overlay is pushed on the next frame, replacing any
  /// previously opened one.
  void _openPushDestination() {
    if (!mounted || sl<SessionManager>().currentState != SessionState.authenticated) return;
    final destination = sl<PushNotificationService>().takePendingDestination();
    if (destination == null) return;
    final router = GoRouter.of(context);

    final (String tab, String overlay, Map<String, String> params) = switch (destination) {
      ConversationDestination(:final conversationId) => (
          RouteNames.messages,
          RouteNames.chat,
          {'conversationId': conversationId},
        ),
      // `commentId` rides along unused: the post screen has no scroll-to-
      // comment yet, so the post itself opens.
      PostDestination(:final postId) => (RouteNames.feed, RouteNames.postDetail, {'postId': postId}),
      ProfileDestination(:final userId) => (RouteNames.friends, RouteNames.userProfile, {'userId': userId}),
      // A resolved report. `reportId` rides along unused: the push
      // deliberately names neither the post nor its author, so there is no
      // per-report screen to open — Privacy & safety re-reads
      // `GET /v1/reports/me` and the outcome is in the list.
      ReportsDestination() => (RouteNames.profile, RouteNames.privacySafety, <String, String>{}),
    };

    final current = router.state;
    if (current.name == overlay && params.entries.every((e) => current.pathParameters[e.key] == e.value)) {
      return;
    }
    router.goNamed(tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || sl<SessionManager>().currentState != SessionState.authenticated) return;
      unawaited(router.pushNamed(overlay, pathParameters: params));
    });
  }

  void _startInboxRefreshTimer() {
    _inboxRefreshTimer?.cancel();
    _inboxRefreshTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          sl<SessionManager>().currentState != SessionState.authenticated ||
          // A full-screen overlay (a chat, a post, a profile, a composer) is
          // covering the shell: neither the Inbox list nor the bottom bar's
          // dot is on screen, so a tick would buy nothing. The chat screen
          // polls its own conversation, refreshes this list once when it
          // closes, and a push still fires `_refreshActivity` meanwhile.
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      // The Inbox unread dot lives in `BottomNavBar`, so it is on screen from
      // every tab and has to keep moving on all of them.
      unawaited(sl<MessagesCubit>().refresh());
      // The Signals dot does not: it sits in the feed app bar (`_SignalsAction`,
      // branch 0), and branch 3 *is* the Signals list. Nothing else reads this
      // count, and it is by far the expensive half of a tick — the repository
      // walks every unread page so the badge applies the same `isSignal` filter
      // the rows do (`notification_repository_impl.dart`, `getUnreadCount`).
      // Don't pay for it on a tab that cannot show it; `_selectBranch` brings
      // it current as the feed app bar comes back.
      final branch = widget.navigationShell.currentIndex;
      if (branch == _feedBranch || branch == _signalsBranch) {
        unawaited(sl<NotificationsCubit>().refreshUnreadCount());
      }
    });
  }

  void _refreshActivity() {
    if (!mounted || sl<SessionManager>().currentState != SessionState.authenticated) return;
    unawaited(sl<MessagesCubit>().refresh(queueIfLoading: true));
    unawaited(sl<NotificationsCubit>().refresh(queueIfLoading: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshActivity();
      _startInboxRefreshTimer();
    } else {
      _inboxRefreshTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pushUpdates?.cancel();
    _notificationTaps?.cancel();
    _inboxRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MainShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.navigationShell.currentIndex;
    final current = widget.navigationShell.currentIndex;
    if (previous == current) return;
    // The poll cadence is branch-dependent, so re-arm when crossing between
    // the fast (Inbox) and slow (everywhere else) tier.
    if ((previous == _inboxBranch) != (current == _inboxBranch)) _startInboxRefreshTimer();
    // Switching tabs lands on a fresh (or differently-scrolled) page — always
    // show the bar again rather than leaving it hidden from the last tab.
    if (!_navVisible) setState(() => _navVisible = true);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    // Ignore horizontal scrollers nested inside the page (e.g. the stories
    // rail) — only the page's own vertical scroll should toggle the bar.
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is UserScrollNotification) {
      final direction = notification.direction;
      if (direction == ScrollDirection.reverse && _navVisible) {
        setState(() => _navVisible = false);
      } else if (direction == ScrollDirection.forward && !_navVisible) {
        setState(() => _navVisible = true);
      }
    } else if (notification is ScrollEndNotification &&
        notification.metrics.pixels <= notification.metrics.minScrollExtent &&
        !_navVisible) {
      // Snapped back to the top (e.g. pull-to-refresh) — make sure the bar
      // is showing again.
      setState(() => _navVisible = true);
    }
    return false;
  }

  void _selectBranch(int index) {
    // The shell's branches are each kept alive across tab switches (that's
    // the whole point of StatefulShellRoute — see class doc), so `FeedPage`
    // itself only ever builds (and calls `FeedCubit.load()`) once, the very
    // first time this branch is activated. Without this, returning to Feed
    // after e.g. accepting a friend request or a friend posting would show
    // whatever (possibly empty) result was fetched the first time, forever —
    // only a manual pull-to-refresh or a full app restart would ever show
    // new content. So: silently re-fetch (same call `RefreshIndicator`
    // uses) whenever switching back into Feed from a different tab.
    // `refresh()` doesn't blank the page while it runs — see its own doc
    // comment.
    if (index == _feedBranch && widget.navigationShell.currentIndex != _feedBranch) {
      sl<FeedCubit>().refresh();
      // Signals' unread count is only polled while it can be seen (see
      // [_startInboxRefreshTimer]) — bring it current as its app bar returns,
      // rather than letting the dot lag a whole slow tick behind.
      unawaited(sl<NotificationsCubit>().refreshUnreadCount());
    }
    // Refresh even when reselecting the current, preserved branch.
    if (index == _inboxBranch) unawaited(sl<MessagesCubit>().refresh());
    if (index == _signalsBranch) unawaited(sl<NotificationsCubit>().refresh());
    widget.navigationShell.goBranch(index, initialLocation: index == widget.navigationShell.currentIndex);
  }

  /// Android's system Back on a non-Feed tab used to fall straight through
  /// to the engine and close the app, because every branch's stack is one
  /// route deep (this app's pushed routes live on the *root* navigator, not
  /// inside a branch) — so Back on Inbox was indistinguishable from Back on
  /// Feed. Now Feed is the app's single back-stop: Back anywhere else hops
  /// there first, and only a second Back from Feed exits, which is the
  /// convention Android users expect from a tabbed home.
  ///
  /// Routed through [_selectBranch] rather than a bare `goBranch(0)` so
  /// arriving via Back refreshes the feed exactly like tapping the tab does.
  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop) return;
    _selectBranch(0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // `canPop` is only consulted for pops that reach *this* route — a pushed
    // page (chat, post detail, the create sheet) sits above the shell on the
    // root navigator and still handles its own Back normally.
    return PopScope<Object?>(
      canPop: widget.navigationShell.currentIndex == 0,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        backgroundColor: colors.bg,
        extendBody: true,
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: widget.navigationShell,
        ),
        bottomNavigationBar: AnimatedSlide(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          offset: _navVisible ? Offset.zero : const Offset(0, 1.4),
          child: BottomNavBar(
            currentIndex: widget.navigationShell.currentIndex,
            onTabSelected: _selectBranch,
            onCreate: () => context.pushNamed(RouteNames.createPost),
          ),
        ),
      ),
    );
  }
}
