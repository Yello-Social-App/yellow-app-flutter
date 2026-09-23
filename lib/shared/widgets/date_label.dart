import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// The uppercase "today" eyebrow every tab's landing screen wears directly
/// above its title — `WEDNESDAY · SEP 22`.
///
/// Lives in `shared/` rather than on any one page because Feed, Explore
/// (Communities and Showcase) and Inbox all carry it; it started out private
/// to `feed_page.dart` and was being reached for across feature boundaries.
///
/// On Feed it is a plain, ordinary (non-sticky) sliver sitting above the
/// `SliverAppBar` rather than living inside it — it scrolls away normally
/// with the rest of the feed content. That split came out of three separate
/// on-device bugs from trying to keep both this label and the wordmark inside
/// one `SliverAppBar` (wordmark-in-title-with-date-below it overlapping;
/// date-and-wordmark-together-in-`flexibleSpace` making the wordmark
/// disappear on scroll instead of acting like a persistent app-bar identity;
/// a parallax drift/jitter chase on top of that). A `SliverAppBar`'s toolbar
/// is the one truly fixed, always-visible part of the widget, so the wordmark
/// belongs there and nowhere else — which leaves no good place left *inside*
/// the app bar for the date. As its own separate sliver it is just normal
/// scrolling content, with no toolbar/`flexibleSpace` interaction to get
/// backwards.
class DateLabel extends StatelessWidget {
  const DateLabel({super.key, this.color, this.trailing, this.now});

  /// Overrides the default `ink2`. For surfaces that do not take the active
  /// token set: Inbox's header slab is dark in *both* themes, so it passes
  /// `AppColors.dark.ink2` rather than letting a light theme paint a dark
  /// grey on it.
  final Color? color;

  /// An extra fact appended behind the same `·` the date itself uses, so a
  /// screen can carry one on this line instead of stacking a second mono row
  /// under it (Inbox's unread count). Uppercased with the rest of the line.
  final String? trailing;

  /// The clock, for tests that need a fixed weekday/month. Null — every
  /// caller in the app — means [DateTime.now] at build time.
  final DateTime? now;

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec', //
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final now = this.now ?? DateTime.now();
    final date = '${_weekdays[now.weekday - 1]} · ${_months[now.month - 1]} ${now.day}';
    final label = trailing == null ? date : '$date · $trailing';

    return Text(label.toUpperCase(), style: AppTextStyles.metaMono.copyWith(color: color ?? colors.ink2));
  }
}
