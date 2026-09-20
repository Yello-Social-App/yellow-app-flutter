import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'bottom_nav_bar.dart';

/// The "Explore" bottom-nav slot's sheet: the two features that have no
/// router branch of their own — Communities ("Rooms") and Showcase
/// ("Built") — behind one labelled list.
///
/// It lived on the feed app bar until Signals took that spot; moving it to
/// the nav bar kept both destinations reachable, since this sheet is still
/// their only entry point anywhere in the app. Neither is a
/// [StatefulShellBranch], so both rows `push` over the shell rather than
/// `goBranch` — the Explore slot never lights up as an active tab, by
/// design (see [BottomNavBar]).
void showExploreSheet(BuildContext context) {
  final colors = AppColors.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surf,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EXPLORE', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
            const SizedBox(height: 14),
            _ExploreRow(
              emoji: '💬',
              title: 'Rooms',
              subtitle: 'Communities and their threads',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.pushNamed(RouteNames.communities);
              },
            ),
            const SizedBox(height: 10),
            _ExploreRow(
              emoji: '🚀',
              title: 'Built',
              subtitle: 'Projects people have shipped',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.pushNamed(RouteNames.showcase);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _ExploreRow extends StatelessWidget {
  const _ExploreRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.surf2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.line, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleMd.copyWith(color: colors.ink)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppTextStyles.bodySm.copyWith(color: colors.ink2)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: colors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}
