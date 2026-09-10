import 'package:flutter/material.dart';

/// Window-size breakpoints (logical px width), matching Material 3's own
/// compact/medium/expanded window size classes — used app-wide so a phone-
/// designed screen doesn't just stretch edge-to-edge on a tablet.
abstract final class AppBreakpoints {
  /// Below this: a phone in portrait — the layouts in this app are
  /// designed at this width and below, unconstrained.
  static const double compact = 600;

  /// Below this: a small/medium tablet or a phone in landscape.
  static const double medium = 840;

  /// The width phone-first content is capped at once the screen is wider
  /// than [compact] (see [ResponsiveContent] in
  /// `shared/widgets/responsive_content.dart`) — centers a comfortable,
  /// phone-proportioned column instead of letting cards, feeds, and the
  /// bottom nav sprawl across a tablet's full width. 600 doubles as a
  /// generous "large phone" cap and the low end of a comfortable tablet
  /// reading column.
  static const double maxContentWidth = 600;
}

extension ResponsiveContextX on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// True once the viewport is at least tablet-width (or a foldable/
  /// desktop window at that size) — [AppBreakpoints.compact] and up.
  bool get isTabletWidth => screenWidth >= AppBreakpoints.compact;
}
