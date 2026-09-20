import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

/// Pill-shaped filter chip in the design's flat, 1.5px-bordered style —
/// the sort / scope / membership / tech rows all use this.
///
/// Distinct from `AppButton`: a chip is a *selection* that reads as on or off
/// and sits in a scrolling row of siblings, not a call to action, so it is
/// smaller, uses the mono meta type, and shows its selected state as a yellow
/// tint rather than a filled brand button.
class FilterChipPill extends StatelessWidget {
  const FilterChipPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Optional suffix inside the same pill, e.g. a count — kept as a string so
  /// the chip never has to lay out arbitrary widgets at this size.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foreground = selected ? colors.yeld : colors.ink2;

    return Material(
      color: selected ? colors.yelb : colors.surf,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: BorderSide(color: selected ? colors.yel : colors.line, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Text(
                label.toUpperCase(),
                style: AppTextStyles.metaMono.copyWith(color: foreground),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 5),
                Text(
                  trailing!,
                  style: AppTextStyles.metaMono.copyWith(color: colors.ink3, fontSize: 9),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
