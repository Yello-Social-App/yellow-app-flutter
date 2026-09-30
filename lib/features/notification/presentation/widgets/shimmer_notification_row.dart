import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// The inbox's loading skeleton — a structural stand-in for a read
/// `_NotificationRow` (notifications_page.dart), so rows land where the
/// placeholders were.
///
/// Geometry copied from the row: 10px bottom gap, a 13px-inset box with a
/// `line` border at 1.5 and [AppRadii.lg] corners (transparent, like a read
/// row), a 40px icon circle, 12px, then the title (titleMd 14/1.15), 3px,
/// the body (bodySm 13/1.4, up to two lines), 7px, and the timestamp
/// (metaMono 10.5/1.3). Bars are drawn at font size with the line's leading
/// folded into the gaps, so the block is the same height as the text.
class ShimmerNotificationRow extends StatelessWidget {
  const ShimmerNotificationRow({super.key, this.titleWidth = 150, this.bodyLines = 2});

  final double titleWidth;

  /// 0, 1 or 2 — how many body lines the row it stands in for carries.
  final int bodyLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.of(context).line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(width: 40, height: 40, borderRadius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: titleWidth, height: 14),
                    if (bodyLines > 0)
                      ShimmerTextLines(
                        lineWidthFactors: [if (bodyLines > 1) 1, 0.62],
                        lineHeight: 13,
                        gap: 5,
                        padding: const EdgeInsets.only(top: 7),
                      ),
                    const SizedBox(height: 11),
                    const ShimmerBox(width: 34, height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
