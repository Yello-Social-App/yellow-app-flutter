import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// The post screen's loading skeleton — the post card, the "COMMENTS · N"
/// heading and a few comments, in place of a centred spinner
/// (post_detail_page.dart).
///
/// Laid out in `_Loaded`'s own `fromLTRB(14, 14, 14, 96)` list padding.
/// `_PostHeaderCard`: `surf` fill, `line` border at 1.5, [AppRadii.xxl], card
/// shadow; a 14px-inset header with a 44px avatar, 11px, the name (titleRow)
/// over the handle line (metaMono) 4px apart; body copy in the usual
/// `fromLTRB(14, 0, 14, 12)` inset; and the `EdgeInsets.all(12)` action row
/// of 33px pills. The heading sits in `fromLTRB(4, 18, 4, 10)`, then
/// [ShimmerCommentRow]s.
class ShimmerPostDetail extends StatelessWidget {
  const ShimmerPostDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
      children: [
        Container(
          decoration: BoxDecoration(
            color: colors.surf,
            border: Border.all(color: colors.line, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadii.xxl),
            boxShadow: AppShadows.card(context),
          ),
          clipBehavior: Clip.antiAlias,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerListTile(
                padding: EdgeInsets.all(14),
                avatarSize: 44,
                gap: 11,
                titleWidth: 124,
                titleHeight: 15,
                subtitleWidth: 150,
                subtitleHeight: 10,
                lineGap: 8,
              ),
              ShimmerTextLines(lineWidthFactors: [1, 0.94, 0.58]),
              Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    ShimmerBox(width: 62, height: 33, borderRadius: AppRadii.pill),
                    SizedBox(width: 8),
                    ShimmerBox(width: 58, height: 33, borderRadius: AppRadii.pill),
                    Spacer(),
                    Flexible(child: ShimmerBox(width: 70, height: 33, borderRadius: AppRadii.pill)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 18, 4, 10),
          child: Align(alignment: Alignment.centerLeft, child: ShimmerBox(width: 96, height: 11)),
        ),
        const ShimmerCommentRow(nameWidth: 84, lineWidthFactors: [1, 0.7]),
        const ShimmerCommentRow(nameWidth: 110, lineWidthFactors: [0.55]),
        const ShimmerCommentRow(nameWidth: 72, lineWidthFactors: [1, 0.86, 0.4]),
      ],
    );
  }
}

/// A stand-in for one top-level `_CommentRow`: a 38px avatar, 11px, then a
/// bubble — 14/12 padding, `surf` fill, `line` border at 1.5, [AppRadii.md]
/// — holding the author (titleSm), the copy (bodySm 13/1.4 a line) and the
/// reaction / reply actions. 10px below each row.
class ShimmerCommentRow extends StatelessWidget {
  const ShimmerCommentRow({super.key, this.nameWidth = 90, this.lineWidthFactors = const [1, 0.64]});

  final double nameWidth;
  final List<double> lineWidthFactors;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 38, height: 38, borderRadius: 19),
          const SizedBox(width: 11),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surf,
                border: Border.all(color: colors.line, width: 1.5),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: nameWidth, height: 11),
                  ShimmerTextLines(
                    lineWidthFactors: lineWidthFactors,
                    lineHeight: 12,
                    gap: 6,
                    padding: const EdgeInsets.only(top: 9),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      ShimmerBox(width: 30, height: 10),
                      SizedBox(width: 16),
                      ShimmerBox(width: 34, height: 10),
                      SizedBox(width: 16),
                      ShimmerBox(width: 22, height: 10),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
