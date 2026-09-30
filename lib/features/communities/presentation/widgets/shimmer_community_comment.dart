import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// A thread's comment skeleton — a stand-in for `_CommentTile`
/// (community_post_page.dart).
///
/// Geometry copied from the tile: 8px bottom margin, `fromLTRB(12, 10, 12,
/// 10)` padding, `surf` fill, `line2` border at 1.5, [AppRadii.md]; a 28px
/// avatar, 10px, then the handle (titleSm) beside the timestamp
/// (metaMonoSm), 5px, the copy (bodySm 13/1.4), 6px, and the text actions.
class ShimmerCommunityComment extends StatelessWidget {
  const ShimmerCommunityComment({super.key, this.handleWidth = 82, this.lineWidthFactors = const [1, 0.6]});

  final double handleWidth;
  final List<double> lineWidthFactors;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line2, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 28, height: 28, borderRadius: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: ShimmerBox(width: handleWidth, height: 11)),
                    const SizedBox(width: 8),
                    const ShimmerBox(width: 22, height: 9),
                  ],
                ),
                ShimmerTextLines(
                  lineWidthFactors: lineWidthFactors,
                  lineHeight: 12,
                  gap: 6,
                  padding: const EdgeInsets.only(top: 8),
                ),
                const SizedBox(height: 10),
                const ShimmerBox(width: 36, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
