import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// The **public** profile's loading skeleton — a structural stand-in for the
/// whole `ListView` that `public_profile_page.dart` builds once the user is
/// in, so the real page swaps in without anything jumping. Replaces the
/// centred `CircularProgressIndicator` it used to show, which sat alone on an
/// empty background and then cut to a full page.
///
/// The Profile tab used to share this layout and no longer does — it has its
/// own [ShimmerOwnProfileView] next door. Keep [cardOverlap] / [tabCount]:
/// they are cheap, and the two shapes may converge again.
///
/// Every measurement is copied from that page:
/// the 210px cover with its 90px fade into `bg`; the header card (`surf`
/// fill, `line` border at 1.5, [AppRadii.huge] corners, [AppShadows.card],
/// 14px side margin, 16px side padding) riding up over the cover by
/// [cardOverlap]; inside it the 96px avatar in its 6px `surf` ring pulled up
/// 48 to straddle the card's top edge, then the info column pulled up 34 —
/// name (displayLg 26/1.05 -> 27), 11px, the handle pill (metaMono 14 in a
/// 1px hairline -> 16), 16px, and the 38px-tall action buttons. Below the
/// card, in the page's 14px gutter: the three stat tiles (titleLg 20 + 7 +
/// metaMono 14 inside 14px vertical padding and a 1.5 border), 16px, the
/// segmented tab pill (5px padding around 32px-tall labels), 16px, and the
/// post list — the feed's own [ShimmerPostCard], one of each body shape,
/// since the tabs render real `PostCard`s.
///
/// The `Transform.translate`s are the same ones the real pages use, kept so
/// the card is laid out at the same height; nothing here is tappable, so the
/// hit-test caveat in `docs/GOTCHAS.md` does not apply.
class ShimmerProfileView extends StatelessWidget {
  const ShimmerProfileView({super.key, this.cardOverlap = 25, this.tabCount = 3});

  /// How far the header card rides up over the cover: 25 on the own profile,
  /// 20 on a public one.
  final double cardOverlap;

  /// Post / Shared / Saved on the own profile; a public one has no Saved.
  final int tabCount;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 112),
      children: [
        SizedBox(
          height: 210,
          child: Stack(
            children: [
              const ShimmerBox(height: 210, borderRadius: 0),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 90,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [colors.bg, colors.bg.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: Offset(0, -cardOverlap),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            decoration: BoxDecoration(
              color: colors.surf,
              border: Border.all(color: colors.line, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadii.huge),
              boxShadow: AppShadows.card(context),
            ),
            child: Column(
              children: [
                Transform.translate(
                  offset: const Offset(0, -48),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surf, width: 6),
                    ),
                    child: const ShimmerBox(width: 96, height: 96, borderRadius: 48),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -34),
                  child: const Column(
                    children: [
                      ShimmerBox(width: 168, height: 27),
                      SizedBox(height: 11),
                      ShimmerBox(width: 112, height: 16, borderRadius: AppRadii.pill),
                      SizedBox(height: 16),
                      // Three fixed-width pills come to 268px, which is wider
                      // than the card's interior on a 320dp screen (or a 360dp
                      // one at a larger Display size) — scale the row down
                      // there rather than overflow; at normal widths it is 1:1.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShimmerBox(width: 104, height: 38, borderRadius: AppRadii.pill),
                            SizedBox(width: 8),
                            ShimmerBox(width: 68, height: 38, borderRadius: AppRadii.pill),
                            SizedBox(width: 8),
                            ShimmerBox(width: 80, height: 38, borderRadius: AppRadii.pill),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          child: Column(
            children: [
              const Row(
                children: [
                  _StatTile(),
                  SizedBox(width: 10),
                  _StatTile(),
                  SizedBox(width: 10),
                  _StatTile(),
                ],
              ),
              const SizedBox(height: 16),
              _TabBar(count: tabCount),
              const SizedBox(height: 16),
              const ShimmerPostCard(),
              const ShimmerPostCard(hasImage: false),
            ],
          ),
        ),
      ],
    );
  }
}

/// One stat tile: the same 14px vertical padding, 1.5 hairline and
/// [AppRadii.lg] corners as the real `_StatTile`, around a 20px value and a
/// 14px label 7 apart.
class _StatTile extends StatelessWidget {
  const _StatTile();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: colors.surf,
          border: Border.all(color: colors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: const Column(
          children: [
            ShimmerBox(width: 36, height: 20),
            SizedBox(height: 7),
            ShimmerBox(width: 72, height: 14),
          ],
        ),
      ),
    );
  }
}

/// The segmented tab pill: 5px padding around [count] equal slots, each 11px
/// of padding around a 10px navLabel, so it is exactly the real bar's 45px.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 11),
                child: Center(child: ShimmerBox(width: 52, height: 10)),
              ),
            ),
        ],
      ),
    );
  }
}
