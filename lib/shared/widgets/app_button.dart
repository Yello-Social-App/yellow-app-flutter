import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

enum AppButtonVariant { primary, outline, subtle, danger }

/// Pill-shaped CTA matching the mockup's buttons ("Accept", "Follow",
/// "PUBLISH", "Edit profile", the theme toggle). All three variants share
/// the same 1.5px-bordered pill shape; only fill/border/text color differ.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.trailingIcon,
    this.fullWidth = false,
    this.dense = false,
    this.borderColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? icon;

  /// An icon after the label instead of before it (e.g. "Create Account →").
  final Widget? trailingIcon;
  final bool fullWidth;
  final bool dense;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final disabled = onPressed == null;

    final (Color bg, Color fg, Color border) = switch (variant) {
      AppButtonVariant.primary => (
        disabled ? colors.surf2 : colors.yel,
        disabled ? colors.ink3 : colors.onYel,
        disabled ? colors.line : colors.ink,
      ),
      AppButtonVariant.outline => (Colors.transparent, colors.ink, colors.line),
      AppButtonVariant.subtle => (colors.surf, colors.ink2, colors.line),
      // Destructive confirm actions (logout, delete). Same shallow
      // (non-disabled-aware) treatment as outline/subtle above.
      AppButtonVariant.danger => (colors.red, Colors.white, colors.red),
    };

    final child = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 14 : 18,
        vertical: dense ? 10 : 13,
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 7)],
          // A full-width button's width comes from its parent (an `Expanded`,
          // a stretched Column), so a long label — or a large text scale —
          // has nowhere to go and overflows the pill. Shrink it to fit
          // instead, same treatment the nav bar's labels get. Only for
          // `fullWidth`: a content-sized button can be handed unbounded width
          // by a parent Row, where a flex child would assert.
          if (fullWidth)
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  softWrap: false,
                  maxLines: 1,
                  style: AppTextStyles.button.copyWith(color: fg),
                ),
              ),
            )
          else
            Text(label, style: AppTextStyles.button.copyWith(color: fg)),
          if (trailingIcon != null) ...[
            const SizedBox(width: 7),
            trailingIcon!,
          ],
        ],
      ),
    );

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: BorderSide(color: borderColor ?? border, width: 1.5),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: child,
      ),
    );
  }
}
