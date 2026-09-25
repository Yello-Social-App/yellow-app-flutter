import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

/// A `FilterChipPill` that opens a picker instead of toggling in place — same
/// pill, plus a chevron so it reads as "there is more behind this".
///
/// Use it where the vocabulary is open-ended or server-supplied (the showcase's
/// languages, say): a chip row has to either scroll off-screen or wrap, and
/// both hide options the user is meant to be choosing between. A closed set of
/// three or four values belongs in `SegmentedTabs`, not here.
class FilterDropdownPill extends StatelessWidget {
  const FilterDropdownPill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  /// What is currently chosen, or the name of the facet when nothing is.
  final String label;

  /// Whether a filter is actually applied — drives the yellow tint, exactly as
  /// `selected` does on a chip.
  final bool active;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foreground = active ? colors.yeld : colors.ink2;

    return Material(
      color: active ? colors.yelb : colors.surf,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: BorderSide(color: active ? colors.yel : colors.line, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.metaMono.copyWith(color: foreground),
                ),
              ),
              const SizedBox(width: 2),
              Icon(CupertinoIcons.chevron_down, size: 16, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}
