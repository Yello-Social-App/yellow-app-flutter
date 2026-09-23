import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// The showcase's loading skeleton — a structural stand-in for a real
/// [ProjectCard] in its standard shape, so projects swap in without the grid
/// re-flowing. (A featured hero is taller; one per list at most, so the
/// skeleton mirrors the common row.)
///
/// Every measurement is copied from [ProjectCard]'s own subtree: the chrome
/// (`surf` fill, `line` border at 1.5, [AppRadii.xl] corners,
/// [AppShadows.card]), the `EdgeInsets.all(14)` inset, the header row — a
/// 44px [AppRadii.xs] emoji tile, 12px, the name (titleCard 16/1.15 -> 18)
/// over a two-line tagline (bodySm 13/1.4 -> 18 a line, drawn as 13px bars 5
/// apart) — then 12px, a row of three 20px-tall tech pills 6 apart, 12px, and
/// the footer: a 22px avatar, 7px, the handle, then on the right the 29px
/// like pill (14px icon in 10/6 padding plus a 1.5 border), 8px, and the
/// views stat.
class ShimmerProjectCard extends StatelessWidget {
  const ShimmerProjectCard({super.key});

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
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 44, height: 44, borderRadius: AppRadii.xs),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 136, height: 18),
                      SizedBox(height: 4),
                      ShimmerBox(height: 13),
                      SizedBox(height: 5),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.6,
                        child: ShimmerBox(height: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                ShimmerBox(width: 52, height: 20, borderRadius: AppRadii.pill),
                SizedBox(width: 6),
                ShimmerBox(width: 66, height: 20, borderRadius: AppRadii.pill),
                SizedBox(width: 6),
                ShimmerBox(width: 44, height: 20, borderRadius: AppRadii.pill),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                ShimmerBox(width: 22, height: 22, borderRadius: 11),
                SizedBox(width: 7),
                Flexible(child: ShimmerBox(width: 72, height: 14)),
                Spacer(),
                ShimmerBox(width: 44, height: 29, borderRadius: AppRadii.pill),
                SizedBox(width: 8),
                ShimmerBox(width: 30, height: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
