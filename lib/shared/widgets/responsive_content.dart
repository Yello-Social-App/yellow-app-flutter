import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';

/// Caps the app's content at [AppBreakpoints.maxContentWidth] and centers
/// it once the viewport is wider than a phone — applied once, at the app
/// root (see `MaterialApp.router`'s `builder` in `app.dart`), so every
/// screen (every `Scaffold`, the bottom nav, dialogs, bottom sheets) gets
/// this for free instead of each page handling it individually.
///
/// Below [AppBreakpoints.compact] this is a no-op (full width, unchanged)
/// — every screen in this app is designed at phone width first, so nothing
/// changes for the common case. Above it, the phone-proportioned layout
/// centers in a fixed-width column with the theme background filling the
/// rest of the screen, rather than every card/list/nav-bar stretching to
/// an uncomfortable tablet-width line length.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ColoredBox(
      color: colors.bg,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.maxContentWidth,
          ),
          child: child,
        ),
      ),
    );
  }
}
