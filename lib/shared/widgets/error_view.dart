import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'app_button.dart';

/// Generic inline error state with a retry action — used wherever a Cubit
/// surfaces a [Failure] (feed load, conversation load, etc). Styled after
/// the mockup's dashed "empty state" cards.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 135,
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surf2,
                border: Border.all(color: colors.line, width: 1.5),
              ),
              child: Icon(Icons.error_outline, size: 18, color: colors.ink2),
            ),
            const SizedBox(height: 12),
            Text(
              'SOMETHING WENT WRONG',
              style: AppTextStyles.eyebrow.copyWith(color: colors.ink2),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              AppButton(
                label: 'Retry',
                variant: AppButtonVariant.outline,
                onPressed: onRetry,
                dense: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dashed empty-state card ("CAUGHT UP", "NOTHING SAVED YET", etc).
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({super.key, required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        border: Border.all(
          color: colors.line,
          width: 1.5,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.ink, width: 1.5),
              color: colors.yel,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTextStyles.eyebrow.copyWith(color: colors.ink2),
          ),
          const SizedBox(height: 7),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm.copyWith(color: colors.ink3),
          ),
        ],
      ),
    );
  }
}
