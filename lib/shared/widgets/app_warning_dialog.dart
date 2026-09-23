import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'app_button.dart';

/// A designed confirmation card for actions that deserve a deliberate
/// second tap before they happen — currently wired to the Log-out button
/// on `profile_page.dart`. Renders as a fully custom card (rounded corners,
/// warning icon badge, pill actions from the app's own [AppButton]) rather
/// than Material's bare default [AlertDialog] chrome, which several other
/// confirmations in this app still use as-is (e.g. `post_detail_page.dart`'s
/// `_confirmDeletePost`/`_confirmDeleteComment`, `friends_page.dart`'s
/// unfriend confirm) — worth migrating those to this same component later
/// if a consistent "warning card" look is wanted everywhere, not just here.
class AppWarningDialog extends StatelessWidget {
  const AppWarningDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.icon = Icons.warning_rounded,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;

  /// Shows the card and resolves `true` only if [confirmLabel] was tapped —
  /// cancel, a tap outside, or a back-gesture dismissal all resolve `false`.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    IconData icon = Icons.warning_rounded,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AppWarningDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: colors.surf,
          borderRadius: BorderRadius.circular(AppRadii.xxl),
          border: Border.all(color: colors.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: colors.yelb, shape: BoxShape.circle),
              child: Icon(icon, color: colors.yeld, size: 28),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLg.copyWith(color: colors.ink),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd.copyWith(color: colors.ink2),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: cancelLabel,
                    variant: AppButtonVariant.outline,
                    fullWidth: true,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: confirmLabel,
                    variant: AppButtonVariant.danger,
                    fullWidth: true,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
