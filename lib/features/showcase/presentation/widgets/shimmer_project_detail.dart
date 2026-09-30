import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// A project page's loading skeleton — the header card, "BUILT WITH" pills
/// and the description, shaped like `_Body` (project_detail_page.dart).
///
/// The card: 16px inset, `line` border at 1.5, [AppRadii.xl]; a 54px
/// [AppRadii.sm] emoji tile, 14px, the name (displayLg at 22) over the
/// tagline (bodySm), then 16px and the stats line (metaMono) beside the
/// dense Like button. Below: 18px, the eyebrow, 8px, a wrap of tech pills
/// (metaMono in 10/5 padding), 18px, another eyebrow and body copy.
class ShimmerProjectDetail extends StatelessWidget {
  const ShimmerProjectDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surf,
            border: Border.all(color: colors.line, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 54, height: 54, borderRadius: AppRadii.sm),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 160, height: 20),
                        ShimmerTextLines(
                          lineWidthFactors: [1, 0.66],
                          lineHeight: 12,
                          gap: 6,
                          padding: EdgeInsets.only(top: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Align(alignment: Alignment.centerLeft, child: ShimmerBox(width: 150, height: 10)),
                  ),
                  SizedBox(width: 10),
                  ShimmerBox(width: 76, height: 34, borderRadius: AppRadii.pill),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const ShimmerBox(width: 78, height: 11),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ShimmerBox(width: 64, height: 24, borderRadius: AppRadii.pill),
            ShimmerBox(width: 52, height: 24, borderRadius: AppRadii.pill),
            ShimmerBox(width: 80, height: 24, borderRadius: AppRadii.pill),
            ShimmerBox(width: 58, height: 24, borderRadius: AppRadii.pill),
          ],
        ),
        const SizedBox(height: 18),
        const ShimmerBox(width: 64, height: 11),
        const ShimmerTextLines(lineWidthFactors: [1, 1, 0.9, 0.45], padding: EdgeInsets.only(top: 10)),
      ],
    );
  }
}
