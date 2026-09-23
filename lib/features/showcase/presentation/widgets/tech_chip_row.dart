import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/filter_chip_pill.dart';
import '../../domain/entities/project_entity.dart';

/// How many facets the row shows. The vocabulary from `GET /projects/tech` is
/// open-ended; the row is a shortcut to the most-used tags, and the sheet
/// behind the trailing button is the complete list.
const int kTechChipRowMax = 8;

/// The showcase's tech filter as a row: an "All" chip, the busiest facets, and
/// a trailing button that opens the full sheet (`showTechFilterSheet`, which
/// also owns the Featured toggle).
///
/// A chip row on its own was the first shape here and was dropped because
/// anything past the third chip was off-screen — a filter the user cannot see
/// is one they cannot use. This is the row *plus* the sheet: the chips make
/// the common filters one tap and visible; the sheet keeps every facet and its
/// count reachable. A tag chosen from the sheet that is not among the busiest
/// is inserted at the front of the row so the active filter is always on
/// screen and clearable in place.
class TechChipRow extends StatelessWidget {
  const TechChipRow({
    super.key,
    required this.tech,
    required this.selected,
    required this.onSelect,
    required this.onOpenSheet,
    required this.sheetActive,
  });

  /// The facets, in the server's order; the row re-sorts by project count.
  final List<TechCountEntity> tech;

  /// The tag currently filtering the grid, or null for all.
  final String? selected;

  /// Called with the tapped tag, or null for "All". Tapping the selected tag
  /// clears it — `ShowcaseCubit.setTech` already treats a repeat as a clear.
  final ValueChanged<String?> onSelect;
  final VoidCallback onOpenSheet;

  /// Whether a filter that only the sheet can show (Featured only) is on, so
  /// the trailing button tints the way an active chip would.
  final bool sheetActive;

  List<String> _visible() {
    final sorted = [...tech]..sort((a, b) => b.projectCount.compareTo(a.projectCount));
    final names = sorted.take(kTechChipRowMax).map((facet) => facet.name).toList();
    if (selected != null && !names.contains(selected)) names.insert(0, selected!);
    return names;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final names = _visible();

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 14),
            child: Row(
              children: [
                FilterChipPill(label: 'All', selected: selected == null, onTap: () => onSelect(null)),
                for (final name in names) ...[
                  const SizedBox(width: 8),
                  FilterChipPill(label: name, selected: name == selected, onTap: () => onSelect(name)),
                ],
                // Breathing room so the last chip is not flush against the
                // button when the row is scrolled all the way.
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Semantics(
            label: 'More filters',
            child: AppIconButton(
              icon: const Icon(Icons.tune_rounded),
              size: 36,
              onPressed: onOpenSheet,
              backgroundColor: sheetActive ? colors.yelb : null,
              borderColor: sheetActive ? colors.yel : null,
              iconColor: sheetActive ? colors.yeld : null,
            ),
          ),
        ),
      ],
    );
  }
}
