import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// Loading skeleton for the **Profile tab** (`profile_page.dart`), following
/// ADR-013: a structural stand-in for the real `ListView`, kept beside the
/// widgets it mirrors.
///
/// `ShimmerProfileView` next door still serves `public_profile_page.dart`,
/// which kept the header-card layout; this screen's own layout diverged from
/// it, so it needs its own skeleton rather than flashing the other shape.
///
/// Measurements copied from [ProfileHeader] and [ProfileDetailsCard]: the
/// 196px cover with its 84px fade into `bg`, the 112px avatar in a 5px ring
/// hanging 66px below the cover, then 14 — name (displayLg 26/1.05 -> 27)
/// beside the 40px chevron, 10, the counts line (metaMono -> 14), 12, the
/// facts row (15px icons + 13px text -> 17), 12, the connections row (a
/// 30px face beside its label, 6px vertical padding -> 42), 14, the two
/// 38px action buttons, 20, the details card (eyebrow 11 + 10 + three rows
/// of a 32px icon tile in 13px vertical padding), 20, the filter chips
/// (button 13 in 10px vertical padding -> 36), 16, and the post list, which
/// renders real `PostCard`s and so borrows the feed's [ShimmerPostCard].
class ShimmerOwnProfileView extends StatelessWidget {
  const ShimmerOwnProfileView({super.key});

  static const double _coverHeight = 196;
  static const double _avatarSize = 112;
  static const double _avatarRing = 5;
  static const double _avatarOverhang = 66;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const avatarOuter = _avatarSize + _avatarRing * 2;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 112),
      children: [
        SizedBox(
          height: _coverHeight + _avatarOverhang,
          child: Stack(
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
                bottom: _avatarOverhang,
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
              Positioned(
                left: 0,
                right: 0,
                top: _coverHeight - (avatarOuter - _avatarOverhang),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(_avatarRing),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: colors.bg),
                    child: const ShimmerBox(
                      width: _avatarSize,
                      height: _avatarSize,
                      borderRadius: _avatarSize / 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Center(child: ShimmerBox(width: 168, height: 27)),
        const SizedBox(height: 10),
        const Center(child: ShimmerBox(width: 148, height: 14)),
        const SizedBox(height: 12),
        const Center(child: ShimmerBox(width: 210, height: 17, borderRadius: AppRadii.pill)),
        const SizedBox(height: 12),
        const Center(child: ShimmerBox(width: 136, height: 30, borderRadius: AppRadii.pill)),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(child: ShimmerBox(height: 38, borderRadius: AppRadii.pill)),
              SizedBox(width: 10),
              Expanded(child: ShimmerBox(height: 38, borderRadius: AppRadii.pill)),
            ],
          ),
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
                    for (var i = 0; i < 3; i++) ...[
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
          // Flexible rather than fixed chip widths: fixed ones overflow at
          // 320dp, which is the whole point of the skeleton test.
          child: Row(
            children: [
              Expanded(child: ShimmerBox(height: 36, borderRadius: AppRadii.pill)),
              SizedBox(width: 8),
              Expanded(child: ShimmerBox(height: 36, borderRadius: AppRadii.pill)),
              SizedBox(width: 8),
              Expanded(child: ShimmerBox(height: 36, borderRadius: AppRadii.pill)),
            ],
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
