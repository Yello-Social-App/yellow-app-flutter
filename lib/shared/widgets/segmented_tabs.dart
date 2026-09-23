import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

/// Segmented pill switcher — one control with one active segment, for a choice
/// that is exclusive and always made: `ProfilePage`'s Post / Shared / Saved,
/// the Communities sort rows, the Showcase sort row.
///
/// A `FilterChipPill` row says something different — independent toggles, any
/// of which may be off — so the two are not interchangeable. Segments split
/// the available width evenly, so keep the value list short (three or four)
/// and the labels short with it; anything longer belongs in a chip row or
/// behind a dropdown.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.values,
    required this.current,
    required this.labelOf,
    required this.onSelect,
  });

  final List<T> values;
  final T current;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: Material(
                color: value == current ? colors.yel : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  onTap: () => onSelect(value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Center(
                      child: Text(
                        labelOf(value).toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.navLabel.copyWith(
                          color: value == current ? colors.onYel : colors.ink2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
