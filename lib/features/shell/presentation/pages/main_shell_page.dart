import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../feed/presentation/bloc/feed_cubit.dart';
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

class _MainShellPageState extends State<MainShellPage> {
  bool _navVisible = true;

  @override
  void didUpdateWidget(covariant MainShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching tabs lands on a fresh (or differently-scrolled) page — always
    // show the bar again rather than leaving it hidden from the last tab.
    if (oldWidget.navigationShell.currentIndex !=
            widget.navigationShell.currentIndex &&
        !_navVisible) {
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
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
          onTabSelected: (index) {
            // The shell's branches are each kept alive across tab switches
            // (that's the whole point of StatefulShellRoute — see class
            // doc), so `FeedPage` itself only ever builds (and calls
            // `FeedCubit.load()`) once, the very first time this branch is
            // activated. Without this, returning to Feed after e.g.
            // accepting a friend request or a friend posting would show
            // whatever (possibly empty) result was fetched the first time,
            // forever — only a manual pull-to-refresh or a full app
            // restart would ever show new content. So: silently re-fetch
            // (same call `RefreshIndicator` uses) whenever switching back
            // into Feed from a different tab. `refresh()` doesn't blank
            // the page while it runs — see its own doc comment.
            if (index == 0 && widget.navigationShell.currentIndex != 0) {
              sl<FeedCubit>().refresh();
            }
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            );
          },
          onCreate: () => context.pushNamed(RouteNames.createPost),
        ),
      ),
    );
  }
}
