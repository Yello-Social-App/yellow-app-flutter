import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// The Latest-posts tab's loading skeleton — a structural stand-in for a real
/// [CommunityPostCard], so threads swap in without the list re-flowing.
///
/// Every measurement is copied from [CommunityPostCard]'s own subtree: the
/// card chrome (`surf` fill, `line` border at 1.5, [AppRadii.xl] corners,
/// [AppShadows.card]), the `fromLTRB(5, 12, 5, 12)` inset, the 30px-wide vote
/// column (two 30×26 arrow slots around a 12px score padded 10 above and
/// below) centred against the row, the 10px gap, then the content column:
/// the community chip and tag pill (metaMono 10.5/1.3 -> 14; pill 20 tall),
/// 8px, the title (titleCard 16/1.15 -> 18 a line, drawn as two 16px bars 4
/// apart), an optional body (body 15/1.5 -> 22.5 a line, drawn as 15px bars
/// 7 apart like the feed skeleton), 10px, and the author row — 24px avatar,
/// handle, timestamp, comment count and the 24px-tall reaction pill.
class ShimmerCommunityPostCard extends StatelessWidget {
  const ShimmerCommunityPostCard({super.key, this.hasBody = true, this.showCommunity = true});

  /// Mirrors `post.hasBody`: `true` draws two body lines under the title,
  /// `false` only the title. The tab renders one of each so the skeleton
  /// reads like a mixed timeline rather than two identical tiles.
  final bool hasBody;

  /// Mirrors [CommunityPostCard.showCommunity]: a single community's own
  /// screen hides the chip, since every row there is from that community.
  final bool showCommunity;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.card(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 12, 5, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _VoteColumn(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (showCommunity) ...[
                        const ShimmerBox(width: 108, height: 14),
                        const SizedBox(width: 8),
                      ],
                      const ShimmerBox(width: 48, height: 20, borderRadius: AppRadii.pill),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const ShimmerBox(height: 16),
                  const SizedBox(height: 4),
                  const FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.62,
                    child: ShimmerBox(height: 16),
                  ),
                  if (hasBody) ...[
                    const SizedBox(height: 6),
                    const ShimmerBox(height: 15),
                    const SizedBox(height: 7),
                    const FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.84,
                      child: ShimmerBox(height: 15),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      ShimmerBox(width: 24, height: 24, borderRadius: 12),
                      SizedBox(width: 7),
                      ShimmerBox(width: 72, height: 14),
                      SizedBox(width: 8),
                      ShimmerBox(width: 22, height: 14),
                      Spacer(),
                      ShimmerBox(width: 34, height: 14),
                      SizedBox(width: 6),
                      ShimmerBox(width: 44, height: 24, borderRadius: AppRadii.pill),
                    ],
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

/// Up / score / down, the same 30×26 arrow slots and 10px score padding as
/// the real `_VoteColumn`, so the row is exactly as tall as it will be.
class _VoteColumn extends StatelessWidget {
  const _VoteColumn();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 30, height: 26, child: Center(child: ShimmerBox(width: 22, height: 22, borderRadius: 11))),
        Padding(padding: EdgeInsets.symmetric(vertical: 10), child: ShimmerBox(width: 22, height: 12)),
        SizedBox(width: 30, height: 26, child: Center(child: ShimmerBox(width: 22, height: 22, borderRadius: 11))),
      ],
    );
  }
}
