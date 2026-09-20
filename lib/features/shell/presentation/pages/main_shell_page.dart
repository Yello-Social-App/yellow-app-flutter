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

/// Wraps the five bottom-nav tabs (Feed/Circle/Inbox/Signals/Profile) in a
/// [StatefulShellRoute], so each keeps its own scroll position across tab
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pushUpdates = sl<PushNotificationService>().updates.listen((_) => _refreshActivity());
    _notificationTaps = sl<PushNotificationService>().notificationTaps.listen((_) => _openNotificationChat());
    // Also covers notification launches before the shell was mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshActivity();
      _openNotificationChat();
    });
    _startInboxRefreshTimer();
  }

  void _openNotificationChat() {
    if (!mounted || sl<SessionManager>().currentState != SessionState.authenticated) return;
    final conversationId = sl<PushNotificationService>().takePendingConversationId();
    if (conversationId == null) return;
    final router = GoRouter.of(context);
    if (router.state.name == RouteNames.chat && router.state.pathParameters['conversationId'] == conversationId) {
      return;
    }
    // Keep Inbox beneath the chat so Back has a useful destination even
    // after a cold start, and replace any previously opened conversation.
    router.goNamed(RouteNames.messages);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || sl<SessionManager>().currentState != SessionState.authenticated) return;
      unawaited(router.pushNamed(RouteNames.chat, pathParameters: {'conversationId': conversationId}));
    });
  }

  void _startInboxRefreshTimer() {
    _inboxRefreshTimer?.cancel();
    _inboxRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          sl<SessionManager>().currentState != SessionState.authenticated) {
        return;
      }
      unawaited(sl<MessagesCubit>().refresh());
      unawaited(sl<NotificationsCubit>().refreshUnreadCount());
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
    // Switching tabs lands on a fresh (or differently-scrolled) page — always
    // show the bar again rather than leaving it hidden from the last tab.
    if (oldWidget.navigationShell.currentIndex != widget.navigationShell.currentIndex && !_navVisible) {
      setState(() => _navVisible = true);
    }
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
    if (index == 0 && widget.navigationShell.currentIndex != 0) {
      sl<FeedCubit>().refresh();
    }
    // Refresh even when reselecting the current, preserved branch.
    if (index == 2) unawaited(sl<MessagesCubit>().refresh());
    if (index == 3) unawaited(sl<NotificationsCubit>().refresh());
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
