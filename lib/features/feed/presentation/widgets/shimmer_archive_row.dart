import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// The story archive's loading skeleton — a stand-in for `_ArchiveRow`
/// (story_archive_page.dart).
///
/// Geometry copied from the row: a 10px-inset box with a `line` border at
/// 1.5 and [AppRadii.lg] corners, the 52px [AppRadii.md] thumbnail, 12px,
/// then the caption (body 15/1.5), 6px, and the meta line — timestamp
/// (metaMonoSm), the 12px visibility glyph and the LIVE pill — with the
/// delete button's 40px circle on the trailing edge.
class ShimmerArchiveRow extends StatelessWidget {
  const ShimmerArchiveRow({super.key, this.captionWidth = 170});

  final double captionWidth;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          const ShimmerBox(width: 52, height: 52, borderRadius: AppRadii.md),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: captionWidth, height: 14),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    ShimmerBox(width: 28, height: 9),
                    SizedBox(width: 8),
                    ShimmerBox(width: 12, height: 12, borderRadius: 6),
                    SizedBox(width: 8),
                    ShimmerBox(width: 34, height: 16, borderRadius: AppRadii.pill),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const ShimmerBox(width: 40, height: 40, borderRadius: 20),
        ],
      ),
    );
  }
}
