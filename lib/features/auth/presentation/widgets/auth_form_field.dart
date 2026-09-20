import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';

/// Icon-prefixed pill text field for the auth screens — [label] is used as
/// the placeholder (when [placeholder] isn't given separately) and as the
/// screen-reader label; there's no separate caption drawn above the field,
/// matching the reference's plain icon+placeholder input style.
/// [borderColor]/[helperText]/[helperColor] drive the success/error states
/// the register screen's email and confirm-password fields use.
class AuthFormField extends StatelessWidget {
  const AuthFormField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.helperText,
    this.helperColor,
    this.borderColor,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.leadingIcon,
    this.trailing,
    this.placeholder,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;

  /// Small message below the field (e.g. "Looks good." / "Passwords do not
  /// match.") — paired with [helperColor].
  final String? helperText;
  final Color? helperColor;

  /// Overrides the field's border color (green for a validated email, red
  /// for a mismatched confirm-password) — null uses the normal hairline.
  final Color? borderColor;

  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  final IconData? leadingIcon;

  /// A trailing widget slot — a validation glyph or a visibility-toggle
  /// button, sized and centered to match the field's own icon.
  final Widget? trailing;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final border = borderColor ?? colors.line;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          textField: true,
          label: label,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surf2,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Row(
              children: [
                const SizedBox(width: 18),
                if (leadingIcon != null)
                  Icon(leadingIcon, size: 19, color: colors.ink3),
                if (leadingIcon != null) const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    obscureText: obscureText,
                    keyboardType: keyboardType,
                    autofillHints: autofillHints,
                    textInputAction: textInputAction,
                    onSubmitted: onSubmitted,
                    onChanged: onChanged,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 15,
                      color: colors.ink,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 7.5),
                      hintText: placeholder ?? label,
                      hintStyle: AppTextStyles.body.copyWith(
                        fontSize: 15,
                        color: colors.ink3,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  trailing!,
                  const SizedBox(width: 18),
                ] else
                  const SizedBox(width: 18),
              ],
            ),
          ),
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 7, 18, 0),
            child: Text(
              helperText!,
              style: AppTextStyles.metaMono.copyWith(
                color: helperColor ?? colors.ink2,
                fontSize: 10.5,
              ),
            ),
          ),
      ],
    );
  }
}
