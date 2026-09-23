import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'yello_wordmark.dart';

/// The two screens behind the bottom nav's Explore slot. Communities is the
/// slot's landing screen; Showcase is reached from the title menu on it.
enum ExploreDestination {
  communities(
    title: 'Communities',
    emoji: '💬',
    subtitle: 'Communities and their threads',
    routeName: RouteNames.communities,
  ),
  showcase(
    title: 'Showcase',
    emoji: '🚀',
    subtitle: 'Projects people have shipped',
    routeName: RouteNames.showcase,
  );

  const ExploreDestination({
    required this.title,
    required this.emoji,
    required this.subtitle,
    required this.routeName,
  });

  final String title;
  final String emoji;
  final String subtitle;
  final String routeName;
}

/// A page title that doubles as the switch between the Explore destinations:
/// the usual [YelloWordmark] title with a chevron after it, opening a small
/// anchored menu listing both screens with the current one ticked.
///
/// The Explore tab lands on Communities; this title is the only place the
/// Showcase choice is offered. It sits on both screens so the pair reads as
/// one section with two views rather than a landing screen and a dead end.
///
/// Both screens are routes of the same [StatefulShellBranch], so picking the
/// other one is a `go`, not a push: the branch's page is swapped in place,
/// the bottom nav stays where it is with Explore still lit, and Back keeps
/// meaning "hop to Feed" exactly as it does on every other tab.
class ExploreTitleMenu extends StatelessWidget {
  const ExploreTitleMenu({
    super.key,
    required this.current,
    this.fontSize = AppTextStyles.displayXlFontSize,
  });

  final ExploreDestination current;

  /// Passed straight through to the [YelloWordmark]; the chevron scales off
  /// it so the two stay in proportion.
  final double fontSize;

  void _select(BuildContext context, ExploreDestination destination) {
    if (destination == current) return;
    context.goNamed(destination.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return MenuAnchor(
      // A tap outside the menu only closes it — it must not also land on
      // whatever tab or card happened to be under the finger.
      consumeOutsideTap: true,
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surf),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(6),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            side: BorderSide(color: colors.line, width: 1.5),
          ),
        ),
      ),
      menuChildren: [
        for (final destination in ExploreDestination.values)
          MenuItemButton(
            onPressed: () => _select(context, destination),
            style: MenuItemButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              overlayColor: colors.yel,
            ),
            child: _MenuRow(
              destination: destination,
              selected: destination == current,
            ),
          ),
      ],
      builder: (context, controller, _) => Semantics(
        button: true,
        child: InkWell(
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          borderRadius: BorderRadius.circular(AppRadii.xs),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 2, 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                YelloWordmark(fontSize: fontSize, text: current.title),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: fontSize * 0.8,
                  color: colors.ink2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.destination, required this.selected});

  final ExploreDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(destination.emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(destination.title, style: AppTextStyles.titleMd.copyWith(color: colors.ink)),
            const SizedBox(height: 2),
            Text(destination.subtitle, style: AppTextStyles.bodySm.copyWith(color: colors.ink2)),
          ],
        ),
        const SizedBox(width: 20),
        // Reserved even when unticked so both rows line up at the same width.
        Icon(
          Icons.check_rounded,
          size: 18,
          color: selected ? colors.yeld : Colors.transparent,
        ),
      ],
    );
  }
}
