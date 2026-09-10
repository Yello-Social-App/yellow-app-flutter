import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The "yello." wordmark, drawn entirely in code (bold fill + black outline
/// text, plus a separate circular "full stop" dot) rather than loaded from
/// a raster asset — a raster logo will always show some upscale/downscale
/// softness depending on device pixel ratio, however good the source file
/// is; vector-drawn text has no such ceiling.
///
/// Originally lived only on `SplashPage` (as `_YelloWordmark`, at the fixed
/// 52px it was tuned at) before `FeedPage`'s header needed the same mark at
/// a smaller size in place of its old literal "Today." title — pulled out
/// here so both can share one drawing instead of forking it. [fontSize]
/// scales every dimension (stroke width, dot size, gap) off the ratios the
/// original 52px version was tuned at, so the proportions hold at any size.
///
/// The "yello" part's exact style is transcribed straight from the user's
/// Claude Design source (`Yello Logo.dc.html`'s own CSS, pasted directly in
/// chat rather than read live — the live file couldn't be pulled via
/// `DesignSync` in that session, no `/design-login` auth there):
/// ```css
/// font: 900 52px/.86 Geist,sans-serif; letter-spacing: .01em;
/// color: #F4C542; -webkit-text-stroke: 5px var(--ink);
/// paint-order: stroke fill
/// ```
/// `paint-order: stroke fill` paints the stroke *first* and the fill *over*
/// it, so only the outer half of the 5px stroke stays visible (~2.5px) —
/// opposite of a plain outlined-text stack (fill behind, stroke in front,
/// full width visible), hence the `Stack` order below is deliberately
/// stroke-then-fill, not the more common fill-then-stroke.
///
/// No CSS for the "." was given (it's a separate design-canvas element, not
/// part of this span's text content — confirmed by the reference screenshot
/// rendering it as a perfect circle, not a font glyph), so it's still a
/// hand-drawn circle rather than a literal "." character: sized off Geist's
/// measured ascent/descent ratios (not specific to this CSS) and given a
/// border half the text's nominal stroke (2.5 at 52px, not 5) so its
/// *visible* ring matches the text's paint-order-halved one — Flutter's
/// `Container`/`Border.all` has no stroke-then-fill option to replicate the
/// halving directly, so matching the resulting visible width was the
/// simplest way to keep them looking consistent.
///
/// Colors are the same hex values as `AppColors.light.yel`/`.ink` — spelled
/// out as literals rather than pulled through `AppColors.of(context)`
/// because this is the literal brand mark: it's meant to render in fixed
/// brand colors regardless of the system theme (`AppColors.dark.ink` is
/// near-white, which would all but vanish as the mark's outline).
///
/// Not verified on-device in this sandbox (mobile-only environment, no
/// emulator here) — CSS `em`/px values are carried over as Flutter logical
/// pixels 1:1, which is the standard assumption but not something this
/// sandbox can actually confirm renders at the intended size/weight.
class YelloWordmark extends StatelessWidget {
  const YelloWordmark({super.key, this.fontSize = 52});

  final double fontSize;

  static const _fill = Color(0xFFF4C542);
  static const _ink = Color(0xFF14120C);

  // Ratios measured off the original 52px-tuned version — scaled by
  // `fontSize` so proportions hold at any size instead of just 52.
  static const _strokeWidthRatio = 5.0 / 52;
  static const _dotDiameterRatio = 16.4 / 52;
  static const _gapRatio = 4.1 / 52;
  // Geist Black's descent as a fraction of font size (measured off an
  // earlier raster build; independent of line-height, so still applies at
  // any size) — shifts the dot up from a plain bottom-aligned Row so its
  // bottom edge lines up with the text baseline instead of the deeper
  // bottom of the "y"'s descender.
  static const _descentRatio = 0.1575;

  @override
  Widget build(BuildContext context) {
    final strokeWidth = fontSize * _strokeWidthRatio;
    final dotDiameter = fontSize * _dotDiameterRatio;
    final gap = fontSize * _gapRatio;
    // Half the text's nominal stroke, see doc comment.
    final dotStrokeWidth = strokeWidth / 2;

    final base = GoogleFonts.geist(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 0.86,
      letterSpacing: fontSize * 0.01,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Stack(
          children: [
            // Stroke painted first (behind) ...
            Text(
              'yello',
              style: base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = strokeWidth
                  ..strokeJoin = StrokeJoin.round
                  ..color = _ink,
              ),
            ),
            // ... fill painted second (in front, `paint-order: stroke
            // fill`), covering the inner half of the stroke so only a
            // ~2.5px-at-52px outer ring remains visible.
            Text('yello', style: base.copyWith(color: _fill)),
          ],
        ),
        SizedBox(width: gap),
        Container(
          width: dotDiameter,
          height: dotDiameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _fill,
            border: Border.all(color: _ink, width: dotStrokeWidth),
          ),
        ),
      ],
    );
  }
}
