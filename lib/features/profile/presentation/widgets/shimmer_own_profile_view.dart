import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// Loading skeleton for the **Profile tab** (`profile_page.dart`), following
/// ADR-013: a structural stand-in for the real `ListView`, kept beside the
/// widgets it mirrors.
///
/// `ShimmerProfileView` next door still serves `public_profile_page.dart`,
/// which uses a header card of its own proportions; this screen's layout is
/// close but not identical, so it keeps its own skeleton rather than flashing
/// the other shape.
///
/// Measurements copied from [ProfileHeader] and [ProfileDetailsCard]: the
/// 196px cover with its 84px fade into `bg`, the identity card whose top edge
/// rises 25px into the cover, the 112px avatar in a 5px ring straddling that
/// edge (half above it, half inside the card), then 14 — name (displayLg
/// 26/1.05 -> 27) beside the 40px chevron, 10, the counts line (metaMono ->
/// 14), 12, the facts row (15px icons + 13px text -> 17), 12, the connections
/// row (a 30px face beside its label, 6px vertical padding -> 42), 14, the two
/// 38px action buttons, 18 to the card's bottom edge, 20, the details card
/// (eyebrow 11 + 10 + four rows of a 32px icon tile in 13px vertical
/// padding), 20, the segmented switcher (navLabel 10 in 11px vertical
/// padding, inside a 5px inset and a 1.5px border -> 45),
/// 16, and the post list, which renders real `PostCard`s and so borrows the
/// feed's [ShimmerPostCard].
class ShimmerOwnProfileView extends StatelessWidget {
  const ShimmerOwnProfileView({super.key});

  static const double _coverHeight = 196;
  static const double _avatarSize = 112;
  static const double _avatarRing = 5;
  static const double _cardOverlap = 25;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const avatarOuter = _avatarSize + _avatarRing * 2;
    const cardTop = _coverHeight - _cardOverlap;
    const avatarTop = cardTop - avatarOuter / 2;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 112),
      children: [
        Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: _coverHeight,
              child: ShimmerBox(height: _coverHeight, borderRadius: 0),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: _coverHeight - 84,
              height: 84,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [colors.bg, colors.bg.withValues(alpha: 0.75), colors.bg.withValues(alpha: 0)],
                    stops: const [0, 0.35, 1],
                  ),
                ),
              ),
            ),
            // The card is the Stack's only non-positioned child, so it is
            // what gives the Stack its height — same arrangement as the real
            // header.
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.only(top: cardTop),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: colors.surf,
                    border: Border.all(color: colors.line, width: 1.5),
                    borderRadius: BorderRadius.circular(AppRadii.huge),
                    boxShadow: AppShadows.card(context),
                  ),
                  child: const Column(
                    children: [
                      SizedBox(height: avatarOuter / 2 + 14),
                      Center(child: ShimmerBox(width: 168, height: 27)),
                      SizedBox(height: 10),
                      Center(child: ShimmerBox(width: 148, height: 14)),
                      SizedBox(height: 12),
                      Center(child: ShimmerBox(width: 210, height: 17, borderRadius: AppRadii.pill)),
                      SizedBox(height: 12),
                      Center(child: ShimmerBox(width: 136, height: 30, borderRadius: AppRadii.pill)),
                      SizedBox(height: 14),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Expanded(child: ShimmerBox(height: 38, borderRadius: AppRadii.pill)),
                            SizedBox(width: 10),
                            Expanded(child: ShimmerBox(height: 38, borderRadius: AppRadii.pill)),
                          ],
                        ),
                      ),
                      SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: avatarTop,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(_avatarRing),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors.surf),
                  child: const ShimmerBox(width: _avatarSize, height: _avatarSize, borderRadius: _avatarSize / 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  ShimmerBox(width: 124, height: 11),
                  Spacer(),
                  ShimmerBox(width: 34, height: 34, borderRadius: 17),
                ],
              ),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surf,
                  border: Border.all(color: colors.line, width: 1.5),
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  boxShadow: AppShadows.card(context),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) Divider(height: 1, thickness: 1, color: colors.line2),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        child: Row(
                          children: [
                            ShimmerBox(width: 32, height: 32),
                            SizedBox(width: 12),
                            Expanded(child: ShimmerBox(height: 14)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          // One full-width pill, not three: `SegmentedTabs` is a single
          // control with its segments inside it, so three separate boxes
          // would skeleton a switcher this screen no longer has. Width still
          // comes from the parent rather than a fixed number — fixed ones
          // overflow at 320dp, which is the whole point of the skeleton test.
          child: SizedBox(
            width: double.infinity,
            child: ShimmerBox(height: 45, borderRadius: AppRadii.pill),
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Column(children: [ShimmerPostCard(), ShimmerPostCard(hasImage: false)]),
        ),
      ],
    );
  }
}
