import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'active_tab_indicator_painter.dart';

/// A pinned, full-width tab row with the bottom nav's sliding yellow
/// indicator — Feed's Feed / Community and Circle's Friends / Requests.
///
/// A [SliverPersistentHeaderDelegate] rather than a widget: both screens pin
/// it under their header inside a `CustomScrollView`, so switching tabs stays
/// one tap however deep into the list you are. Contrast `SegmentedTabs`, the
/// pill switcher for choices that sit inside a page rather than split it.
class UnderlineTabsDelegate<T> extends SliverPersistentHeaderDelegate {
  UnderlineTabsDelegate({
    required this.values,
    required this.current,
    required this.labelOf,
    required this.onSelect,
    required this.colors,
  });

  final List<T> values;
  final T current;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelect;

  /// Passed in rather than read in [build] so [shouldRebuild] sees a theme
  /// switch.
  final AppColors colors;

  static const _height = 46.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border(bottom: BorderSide(color: colors.line, width: 1.5)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = constraints.maxWidth / values.length;
          return Stack(
            children: [
              Row(
                children: [
                  for (final value in values)
                    Expanded(
                      child: _UnderlineTabButton(
                        label: labelOf(value),
                        selected: value == current,
                        onTap: () => onSelect(value),
                      ),
                    ),
                ],
              ),
              // Same timing as the bottom nav, so the two indicators slide
              // alike.
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: slotWidth * (values.indexOf(current) + 0.5)),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    builder: (context, center, _) => CustomPaint(
                      painter: ActiveTabIndicatorPainter(
                        selectedCenter: center,
                        slotWidth: slotWidth,
                        color: colors.yel,
                        atBottom: true,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Labels are compared too: Circle's Requests tab carries a live count.
  @override
  bool shouldRebuild(UnderlineTabsDelegate<T> oldDelegate) =>
      oldDelegate.current != current || oldDelegate.colors != colors || !_sameLabels(oldDelegate);

  bool _sameLabels(UnderlineTabsDelegate<T> other) {
    if (other.values.length != values.length) return false;
    for (var i = 0; i < values.length; i++) {
      if (other.labelOf(other.values[i]) != labelOf(values[i])) return false;
    }
    return true;
  }
}

/// One tab: bold ink when selected, dimmed otherwise. The active tab's
/// glowing line and arrow are painted by [UnderlineTabsDelegate] across the
/// whole row, so it can slide between tabs the way the bottom nav's does.
class _UnderlineTabButton extends StatelessWidget {
  const _UnderlineTabButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.buttonLg.copyWith(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? colors.ink : colors.ink3,
            ),
          ),
        ),
      ),
    );
  }
}
