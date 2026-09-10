import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/post_entity.dart';

/// Opens the long-press reaction picker — a row of the 6 backend reaction
/// types, matching the app's existing `showModalBottomSheet` pattern (see
/// `post_detail_page.dart`'s post-menu/edit sheets) rather than a floating
/// popover, since there's no mockup reference for this control. Returns the
/// tapped [ReactionType], or null if dismissed without picking one.
Future<ReactionType?> showReactionPicker(BuildContext context, {ReactionType? current}) {
  final colors = AppColors.of(context);
  return showModalBottomSheet<ReactionType>(
    context: context,
    // Long-pressed from a post card while the floating pill nav bar is on
    // screen — see `post_options_sheet.dart`'s `showPostOptionsSheet` for
    // why this needs the root navigator rather than the branch's own
    // nested one, or the sheet paints behind that bar instead of over it.
    useRootNavigator: true,
    backgroundColor: colors.surf,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('REACT', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final type in ReactionType.values)
                  _ReactionOption(
                    type: type,
                    selected: type == current,
                    onTap: () => Navigator.of(sheetContext).pop(type),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReactionOption extends StatelessWidget {
  const _ReactionOption({required this.type, required this.selected, required this.onTap});

  final ReactionType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: selected ? colors.yelb : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: BorderSide(color: selected ? colors.yel : colors.line, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Text(type.emoji, style: const TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}
