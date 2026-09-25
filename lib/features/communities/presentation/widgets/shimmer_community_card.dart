import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// The Discover / Joined tabs' loading skeleton — a structural stand-in for
/// the directory's `_CommunityCard` in `communities_page.dart`, so the
/// communities swap in without the list re-flowing.
///
/// Every measurement is copied from that card: the chrome (`surf` fill,
/// `line` border at 1.5, [AppRadii.xl] corners, [AppShadows.card]), the 68px
/// cover band, the emoji avatar (50px circle in a 3px `surf` ring) sitting at
/// `(14, 40)` so it breaks out of the band, the `fromLTRB(14, 34, 14, 14)`
/// body inset that clears it, then the name (titleCard 16/1.15 -> 18), 4px,
/// the handle (metaMono 10.5/1.3 -> 14), 9px, a two-line tagline (bodySm
/// 13/1.4 -> 18 a line, drawn as 13px bars 5 apart), 12px, and the footer
/// row — 15px people icon, member count, and the 32px-tall dense Join button.
class ShimmerCommunityCard extends StatelessWidget {
  const ShimmerCommunityCard({super.key});

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
      child: Stack(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShimmerBox(height: 68, borderRadius: 0),
              Padding(
                padding: EdgeInsets.fromLTRB(14, 34, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 148, height: 18),
                    SizedBox(height: 4),
                    ShimmerBox(width: 88, height: 14),
                    SizedBox(height: 9),
                    ShimmerBox(height: 13),
                    SizedBox(height: 5),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.68,
                      child: ShimmerBox(height: 13),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        ShimmerBox(width: 15, height: 15, borderRadius: 7.5),
                        SizedBox(width: 6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ShimmerBox(width: 112, height: 14),
                          ),
                        ),
                        SizedBox(width: 8),
                        ShimmerBox(
                          width: 62,
                          height: 32,
                          borderRadius: AppRadii.pill,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 14,
            top: 40,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surf,
              ),
              child: const ShimmerBox(width: 50, height: 50, borderRadius: 25),
            ),
          ),
        ],
      ),
    );
  }
}
