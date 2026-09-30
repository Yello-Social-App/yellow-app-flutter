import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_style.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

/// The app's button hierarchy. Pick by importance, not by look:
///
/// - [primary]: the one action the screen or card is for ("Sign Up",
///   "Publish", "Accept", "Save"). Brand yellow. At most one per group.
/// - [secondary]: every other action beside or instead of it ("Cancel",
///   "Edit profile", "Message", "Retry", "Load more", a toggled-on state
///   like "Leave" or "Liked"). Transparent with a hairline border.
/// - [danger]: the confirm step of something destructive (log out, delete,
///   remove). Only on the second tap — the first entry point is [secondary].
enum AppButtonVariant { primary, secondary, danger }

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
    final style = AppStyle.of(context);
    final disabled = onPressed == null;

    final (Color bg, Color fg, Color border) = switch (variant) {
      // Disabled keeps the variant's shape (filled vs. outlined) but drops
      // its color, so a busy "Save" doesn't read as a different button.
      AppButtonVariant.secondary when disabled => (Colors.transparent, colors.ink3, colors.line),
      _ when disabled => (colors.surf2, colors.ink3, colors.line),
      AppButtonVariant.primary => (colors.yel, colors.onYel, colors.ink),
      // Under ink outline a secondary button sits on a solid hard shadow, so
      // it needs an opaque face: transparent, the shadow (the `ink` color,
      // same as the label) shows through and swallows the label.
      AppButtonVariant.secondary => (style.outlined ? colors.surf : Colors.transparent, colors.ink, colors.line),
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

    final button = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        // Ink outline draws every enabled variant in ink, danger included,
        // so a red button still sits on the same drawn edge as its neighbours.
        side: BorderSide(
          color: borderColor ?? (style.outlined && !disabled ? colors.ink : border),
          width: style.borderWidth,
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: child,
      ),
    );

    // A disabled button stays flat: losing its shadow is part of how it
    // reads as not pressable.
    if (!style.outlined || disabled) return button;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: style.hardShadow(colors, AppStyle.buttonOffset),
      ),
      child: button,
    );
  }
}
