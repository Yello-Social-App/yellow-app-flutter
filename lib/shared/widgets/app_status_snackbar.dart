import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'app_icon_button.dart';

/// Full-bleed colored status toasts ("On Snap!" / "Congratulations!") for
/// reporting whether an action succeeded or failed — the app's one and only
/// snackbar style, used in place of the plain default [SnackBar] text
/// Flutter shows out of the box. The [SnackBar] itself is made fully
/// transparent/flat so [_StatusCard] reads as its own floating card rather
/// than a bar.
///
/// This is the standard way to surface a transient result anywhere in the
/// app (save/change confirmations, copy-link confirmations, delete/failure
/// messages, etc.) — never call `ScaffoldMessenger.showSnackBar` with a bare
/// [SnackBar] directly; go through [showSuccess]/[showError] instead so
/// every toast in the app looks and behaves the same.
abstract final class AppStatusSnackbar {
  static void showSuccess(BuildContext context, {required String message, String title = 'Congratulations!'}) {
    _show(context, title: title, message: message, isSuccess: true);
  }

  static void showError(BuildContext context, {required String message, String title = 'On Snap!'}) {
    _show(context, title: title, message: message, isSuccess: false);
  }

  static void _show(BuildContext context, {required String title, required String message, required bool isSuccess}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          padding: EdgeInsets.zero,
          duration: const Duration(seconds: 4),
          content: _StatusCard(
            title: title,
            message: message,
            isSuccess: isSuccess,
            onDismiss: messenger.hideCurrentSnackBar,
          ),
        ),
      );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.title, required this.message, required this.isSuccess, required this.onDismiss});

  final String title;
  final String message;
  final bool isSuccess;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final base = isSuccess ? colors.grn : colors.red;
    // A shade darker than the card fill — used for the icon badge, the
    // dismiss button, and the decorative blob, so the card reads as one
    // hue with a little depth rather than perfectly flat.
    final shade = Color.lerp(base, Colors.black, 0.18)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Material(
        color: base,
        child: Stack(
          children: [
            Positioned(left: -26, bottom: -30, child: _Blob(color: shade.withValues(alpha: 0.55))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: shade, shape: BoxShape.circle),
                    child: Icon(
                      isSuccess ? CupertinoIcons.checkmark : CupertinoIcons.xmark,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTextStyles.titleRow.copyWith(color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(message, style: AppTextStyles.bodySm.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  AppIconButton(
                    icon: const Icon(CupertinoIcons.xmark),
                    onPressed: onDismiss,
                    size: 26,
                    backgroundColor: shade,
                    borderColor: shade,
                    iconColor: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Decorative bottom-left flourish — two overlapping circles rather than a
/// bespoke painted path, clipped by [_StatusCard]'s own [ClipRRect]. Pure
/// background texture, not semantic content.
class _Blob extends StatelessWidget {
  const _Blob({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 90,
      child: Stack(
        children: [
          Positioned(left: 10, top: 20, child: _circle(64)),
          Positioned(left: 46, top: 0, child: _circle(40)),
        ],
      ),
    );
  }

  Widget _circle(double d) => Container(
    width: d,
    height: d,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
