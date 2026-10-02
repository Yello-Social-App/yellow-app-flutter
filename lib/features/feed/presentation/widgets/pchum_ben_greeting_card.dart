import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/pchum_ben_ornaments.dart';

/// The Pchum Ben greeting at the top of the feed: the festival wish in Khmer
/// and English beside an offering table (ADR-057). Feed shows it only under
/// the Pchum Ben theme.
///
/// Decoration, not a control — it takes no tap and holds no state.
///
/// A fixed height, so the feed doesn't jump as fonts load, with both halves
/// fitted to it rather than laid out freely: the picture takes a share of the
/// width (at most its natural 200), and the text is scaled down to whatever is
/// left. That is what keeps it whole on a 320dp phone and at a large text
/// scale, where a free-flowing column would run under the picture or out of
/// the card.
class PchumBenGreetingCard extends StatelessWidget {
  const PchumBenGreetingCard({super.key});

  static const double _height = 120;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(AppRadii.xxl);

    return Container(
      height: _height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: colors.yelb, borderRadius: radius),
      // In `foregroundDecoration`: the picture reaches the card's right and
      // bottom edges and would paint over a border in `decoration`
      // (docs/GOTCHAS.md).
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: colors.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sceneWidth = math.min(200.0, constraints.maxWidth * 0.56);
          return Stack(
            children: [
              Positioned(right: 0, bottom: 0, child: PchumBenOfferingScene(width: sceneWidth)),
              // Pinned on every side: a half-pinned `Positioned` would hand
              // the `FittedBox` an unbounded height (docs/GOTCHAS.md).
              Positioned(
                left: 18,
                top: 17,
                bottom: 10,
                width: math.max(0.0, constraints.maxWidth - sceneWidth - 22),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PCHUM BEN', style: AppTextStyles.metaMono.copyWith(color: colors.yeld)),
                      const SizedBox(height: 5),
                      Text(
                        'រីករាយពិធីបុណ្យ\nភ្ជុំបិណ្ឌ',
                        style: GoogleFonts.moul(fontSize: 14, height: 1.75, color: colors.ink),
                      ),
                      const SizedBox(height: 5),
                      Text('Happy Pchum Ben', style: AppTextStyles.bodySm.copyWith(color: colors.ink2)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
