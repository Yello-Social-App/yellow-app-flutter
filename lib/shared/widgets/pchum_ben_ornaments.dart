/// The Pchum Ben theme's ornaments (ADR-057): everything the festival flavor
/// draws beyond its palette, kept in one file so the screens only place them.
///
/// **Every call site is behind `AppStyle.of(context).pchumBen`.** Nothing
/// here checks the flag itself — an ornament that is built is drawn.
///
/// Two kinds of drawing:
///
/// - the lotus-petal frieze and the lotus rosette are [CustomPainter]s,
///   because they have to tile or scale to a box whose size is only known at
///   layout;
/// - the pictures (skyline, scenes, lotus) are SVG strings rendered through
///   `flutter_svg`, built per call so their colors come from the active
///   tokens rather than being baked into an asset.
///
/// All of it is static: no animation, no blur, no shadow. That keeps it clear
/// of the Impeller `BoxShadow` crash (docs/GOTCHAS.md) and costs nothing while
/// a list scrolls under it. None of it takes a tap or is announced — the
/// ornaments are decoration, so they are excluded from semantics.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';

/// Lotus pinks. Illustration colors, not tokens: no widget is ever colored
/// with them, only the petals drawn in this file.
const Color _petalOuter = Color(0xFFF4C2CA);
const Color _petalMid = Color(0xFFEDA3B1);
const Color _petalCore = Color(0xFFE3879A);

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

/// A row of lotus petals, the moulding carved along a pagoda's eaves and
/// plinth. Petals hang down from the top edge by default; [pointUp] stands
/// them on the bottom edge instead.
///
/// The petal is 13 wide at its natural size; the row is stretched by at most
/// half a petal so a whole number of them spans any width.
class PetalFriezePainter extends CustomPainter {
  const PetalFriezePainter({required this.fill, this.stroke, this.vein, this.pointUp = false, this.above = false});

  /// Height of the frieze, whatever the box it is painted in.
  static const double height = 9;

  static const double _petalWidth = 13;

  final Color fill;

  /// Outline of each petal. Null leaves them as flat shapes.
  final Color? stroke;

  /// The inner line that makes a filled petal read as two layers.
  final Color? vein;

  final bool pointUp;

  /// Paints in the [height] strip directly *above* the box instead of inside
  /// it — how the bottom nav grows a plinth without changing its own size.
  final bool above;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final count = math.max(1, (size.width / _petalWidth).round());
    final w = size.width / count;
    final k = w / _petalWidth;

    canvas.save();
    if (above) canvas.translate(0, -height);
    if (pointUp) {
      canvas.translate(0, height);
      canvas.scale(1, -1);
    }

    final petals = Path();
    final veins = Path();
    for (var i = 0; i < count; i++) {
      final x = i * w;
      petals
        ..moveTo(x, 0)
        ..lineTo(x + w, 0)
        ..cubicTo(x + w, 4, x + w - 3.5 * k, 7.5, x + w / 2, height)
        ..cubicTo(x + 3.5 * k, 7.5, x, 4, x, 0)
        ..close();
      veins
        ..moveTo(x + 3.5 * k, 0)
        ..cubicTo(x + 3.5 * k, 2.4, x + 5.1 * k, 4.4, x + 6.5 * k, 5.2)
        ..cubicTo(x + 7.9 * k, 4.4, x + 9.5 * k, 2.4, x + 9.5 * k, 0);
    }

    canvas.drawPath(petals, Paint()..color = fill);
    if (stroke != null) {
      canvas.drawPath(
        petals,
        Paint()
          ..color = stroke!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
    }
    if (vein != null) {
      canvas.drawPath(
        veins,
        Paint()
          ..color = vein!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PetalFriezePainter old) =>
      old.fill != fill || old.stroke != stroke || old.vein != vein || old.pointUp != pointUp || old.above != above;
}

/// [PetalFriezePainter] as a full-width strip, for where the frieze takes up
/// room of its own in a column.
class PetalFrieze extends StatelessWidget {
  const PetalFrieze({super.key, required this.fill, this.stroke, this.vein, this.pointUp = false});

  final Color fill;
  final Color? stroke;
  final Color? vein;
  final bool pointUp;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: double.infinity,
        height: PetalFriezePainter.height,
        child: CustomPaint(
          painter: PetalFriezePainter(fill: fill, stroke: stroke, vein: vein, pointUp: pointUp),
        ),
      ),
    );
  }
}

/// A lotus seen from above: twelve petals fanned around a centre that the
/// caller covers with its own round button. Fills whatever square it is given;
/// the petals reach the edge and start just inside a button 0.73 of that size.
class LotusRosettePainter extends CustomPainter {
  const LotusRosettePainter({this.edge});

  /// The line between neighbouring petals. Pass the surface the rosette sits
  /// on in dark mode, where the default deep pink would glow.
  final Color? edge;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(side / 62);

    final petal = Path()
      ..moveTo(0, -29)
      ..cubicTo(5, -26, 7, -22, 6, -17)
      ..lineTo(-6, -17)
      ..cubicTo(-7, -22, -5, -26, 0, -29)
      ..close();
    final fill = Paint()..color = _petalOuter;
    final line = Paint()
      ..color = edge ?? _petalCore
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var i = 0; i < 12; i++) {
      canvas.drawPath(petal, fill);
      canvas.drawPath(petal, line);
      canvas.rotate(math.pi / 6);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LotusRosettePainter old) => old.edge != edge;
}

// ---------------------------------------------------------------------------
// SVG fragments
// ---------------------------------------------------------------------------

/// A wat's three-tiered roof on its columns, in a 150 x 92 box.
String _wat(String c) =>
    '''
<path d="M75 10C73.5 6 75 2.5 78.5 0" fill="none" stroke="$c" stroke-width="1.6" stroke-linecap="round"/>
<path d="M99 25c3-.5 4.5-2.5 5-5M51 25c-3-.5-4.5-2.5-5-5M116 38c3-.5 4.5-2.5 5-5M34 38c-3-.5-4.5-2.5-5-5M136 51c3-.5 4.5-2.5 5-5M14 51c-3-.5-4.5-2.5-5-5" fill="none" stroke="$c" stroke-width="1.4" stroke-linecap="round"/>
<path fill="$c" d="M75 10C80 17 88 23 99 25C96 26 94 27 93 29H57C56 27 54 26 51 25C62 23 70 17 75 10Z"/>
<path fill="$c" d="M57 29H93C99 34 106 37 116 38C113 39 111 40 110 42H40C39 40 37 39 34 38C44 37 51 34 57 29Z"/>
<path fill="$c" d="M40 42H110C117 47 125 50 136 51C133 52 131 53 130 55H20C19 53 17 52 14 51C25 50 33 47 40 42Z"/>
<path fill="$c" d="M24 55h4v30h-4zM46 55h4v30h-4zM66 55h4v30h-4zM80 55h4v30h-4zM100 55h4v30h-4zM122 55h4v30h-4zM16 85h118v4H16zM10 89h130v3H10z"/>
''';

/// A sugar palm: its crown is at the origin of [transform] and its trunk runs
/// 20 down from there, leaning one unit to the side [lean] gives.
String _palm(String c, String transform, {int lean = -1}) =>
    '''
<g transform="$transform">
<path d="M0 0L6.5 0M0 0L5.6 -3.25M0 0L3.25 -5.6M0 0L0 -6.5M0 0L-3.25 -5.6M0 0L-5.6 -3.25M0 0L-6.5 0M0 0L-5.6 3.25M0 0L5.6 3.25" fill="none" stroke="$c" stroke-width="1.5" stroke-linecap="round"/>
<path d="M0 0L$lean 20" fill="none" stroke="$c" stroke-width="1.3" stroke-linecap="round"/>
<circle cx="0" cy="0" r="2.4" fill="$c"/>
</g>
''';

/// A stupa standing on the origin of [transform].
String _stupa(String c, String transform) =>
    '<path transform="$transform" fill="$c" '
    'd="M-8 0h16v-3h-16zM-6 -3C-6 -10 -3 -13 0 -13C3 -13 6 -10 6 -3ZM-1.8 -13L0 -25L1.8 -13Z"/>';

/// The filled lotus, its base on the origin of the enclosing group.
String _lotus(String leaf, String edge) =>
    '''
<ellipse cx="0" cy="1.5" rx="16" ry="3.5" fill="$leaf"/>
<g stroke="$edge" stroke-width=".8">
<path d="M0 0C-10 0 -17 -6 -19 -15C-12 -15 -5 -11 0 0Z" fill="${_hex(_petalOuter)}"/>
<path d="M0 0C10 0 17 -6 19 -15C12 -15 5 -11 0 0Z" fill="${_hex(_petalOuter)}"/>
<path d="M0 0C-8 -4 -12 -13 -10 -23C-4 -19 0 -11 0 0Z" fill="${_hex(_petalMid)}"/>
<path d="M0 0C8 -4 12 -13 10 -23C4 -19 0 -11 0 0Z" fill="${_hex(_petalMid)}"/>
<path d="M0 0C-6 -7 -6 -20 0 -28C6 -20 6 -7 0 0Z" fill="${_hex(_petalCore)}"/>
</g>
''';

String _svg(String viewBox, String body) => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$viewBox">$body</svg>';

// ---------------------------------------------------------------------------
// Pictures
// ---------------------------------------------------------------------------

/// Sugar palms, a stupa and a wat roof on one ground line — the strip beside
/// Feed's date and under a finished Signals list. 5:1; [width] sets its size.
class PchumBenSkyline extends StatelessWidget {
  const PchumBenSkyline({super.key, this.width = 150});

  final double width;

  @override
  Widget build(BuildContext context) {
    final c = _hex(AppColors.of(context).yel);
    return SvgPicture.string(
      _svg(
        '0 0 150 30',
        '<g opacity=".6">'
            '<g transform="translate(60 .56) scale(.32)">${_wat(c)}</g>'
            '${_stupa(c, 'translate(38 30)')}'
            '${_palm(c, 'translate(13 10)')}'
            '${_palm(c, 'translate(120 6) scale(1.2)', lean: 1)}'
            '${_palm(c, 'translate(138 14) scale(.8)')}'
            '<path d="M0 29.6H150" fill="none" stroke="$c" stroke-width=".8"/>'
            '</g>',
      ),
      width: width,
      height: width / 5,
      excludeFromSemantics: true,
    );
  }
}

/// The wat and two palms, faint, for the top-right of Chat's dark slab.
///
/// Drawn in the dark set's gold whatever the active brightness: the slab is
/// dark in both themes (ADR-009). A fixed 390 x 140 — the caller pins its top
/// right corner, so on a narrower phone the empty left part slides off.
class PchumBenSlabScene extends StatelessWidget {
  const PchumBenSlabScene({super.key});

  static const Size size = Size(390, 140);

  @override
  Widget build(BuildContext context) {
    final c = _hex(AppColors.pchumBenDark.yel);
    return SvgPicture.string(
      _svg(
        '0 0 390 140',
        '<g opacity=".2">'
            '<g transform="translate(236 36)">${_wat(c)}</g>'
            '${_palm(c, 'translate(226 98) scale(1.5)')}'
            '${_palm(c, 'translate(206 108)', lean: 1)}'
            '</g>',
      ),
      width: size.width,
      height: size.height,
      excludeFromSemantics: true,
    );
  }
}

/// Dawn at the wat, for a profile with no cover photo: the temple on the
/// left, a stupa and palms in front of the rising sun on the right.
///
/// Covers whatever box it is given, anchored to the bottom so the ground line
/// stays put while a wider phone crops the sky.
class PchumBenCoverScene extends StatelessWidget {
  const PchumBenCoverScene({super.key});

  @override
  Widget build(BuildContext context) {
    final c = _hex(AppColors.of(context).yel);
    return SvgPicture.string(
      _svg(
        '0 0 390 196',
        '<circle cx="306" cy="124" r="44" fill="$c" fill-opacity=".28"/>'
            '<g opacity=".55">'
            '<g transform="translate(18 62)">${_wat(c)}</g>'
            '${_stupa(c, 'translate(274 154) scale(1.7)')}'
            '${_palm(c, 'translate(320 118) scale(1.8)')}'
            '${_palm(c, 'translate(348 128) scale(1.3)', lean: 1)}'
            '${_palm(c, 'translate(372 122) scale(1.6)')}'
            '<path d="M0 154.5H390" fill="none" stroke="$c"/>'
            '</g>',
      ),
      fit: BoxFit.cover,
      alignment: Alignment.bottomCenter,
      excludeFromSemantics: true,
    );
  }
}

/// The wat and palms standing on the auth header's wave.
///
/// Laid out in the header's own 390 x 260 box and stretched to it with
/// [BoxFit.fill]: the wave is defined in fractions of the header's width, so
/// stretching the picture the same way is what keeps the palms on the line.
/// The cost is a wat up to a tenth wider or narrower than drawn.
class PchumBenWaveScene extends StatelessWidget {
  const PchumBenWaveScene({super.key});

  @override
  Widget build(BuildContext context) {
    final c = _hex(AppColors.pchumBenDark.yel);
    return SvgPicture.string(
      _svg(
        '0 0 390 260',
        '<g opacity=".3">'
            '<g transform="translate(60 146)">${_wat(c)}</g>'
            '${_palm(c, 'translate(40 178) scale(1.7)')}'
            '${_palm(c, 'translate(216 184) scale(1.6)', lean: 1)}'
            '${_palm(c, 'translate(238 178) scale(1.3)')}'
            '</g>',
      ),
      fit: BoxFit.fill,
      excludeFromSemantics: true,
    );
  }
}

/// The offering table of the greeting card: a tiered food carrier, sticky
/// rice cakes, the bay ben rice balls, a lotus, candles and incense, in front
/// of a faint wat with jasmine garlands hanging from the card's top edge.
/// 5:3; [width] sets its size.
class PchumBenOfferingScene extends StatelessWidget {
  const PchumBenOfferingScene({super.key, this.width = 200});

  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gold = _hex(colors.yel);
    // On the light card the drawing is outlined in turmeric; on the dark one
    // turmeric would sink into the card, so the outline goes to lacquer and
    // the carrier's frame — a line with nothing behind it — to gold.
    final outline = _hex(isDark ? colors.onYel : colors.yeld);
    final frame = isDark ? gold : outline;
    final cream = _hex(isDark ? colors.ink : colors.surf);
    final wick = _hex(isDark ? colors.onYel : colors.ink);
    final tie = _hex(isDark ? colors.ink : colors.yelb);
    final leaf = _hex(colors.grn);
    final leafEdge = isDark ? '#1f5a2b' : '#24602c';
    final petalEdge = _hex(isDark ? colors.yelb : colors.surf);
    final smoke = _hex(isDark ? colors.ink : colors.ink2);
    final red = _hex(colors.red);

    String garland(int x) =>
        '''
<g transform="translate($x 0)" fill="none" stroke-linecap="round">
<path d="M-9 0C-9 20 9 20 9 0M0 15V26" stroke="$outline" stroke-opacity=".55" stroke-width="4.8" stroke-dasharray="0.1 4.6"/>
<path d="M-9 0C-9 20 9 20 9 0M0 15V26" stroke="$cream" stroke-width="3.6" stroke-dasharray="0.1 4.6"/>
<circle cx="0" cy="30" r="3.6" fill="${_hex(_petalCore)}"/>
<path d="M0 33.5L-3 43M0 33.5V44.5M0 33.5L3 43" stroke="$gold" stroke-width="1.2"/>
</g>
''';

    final cake =
        '<rect x="-17" y="-11" width="34" height="11" rx="5.5" fill="$leaf" stroke="$leafEdge" stroke-width=".9"/>'
        '<path d="M-10 -11V0M-3.3 -11V0M3.3 -11V0M10 -11V0" fill="none" stroke="$tie" stroke-width="1.4"/>';

    String candle(int x, int body) {
      final top = -body;
      return '''
<g transform="translate($x 108)">
<rect x="-3" y="$top" width="6" height="$body" rx="1.5" fill="$cream" stroke="$outline"/>
<path d="M0 ${top}V${top - 3}" fill="none" stroke="$wick"/>
<g transform="translate(0 ${26 - body})">
<path d="M0 -42C3.5 -37.5 5 -34.5 5 -32A5 5 0 0 1 -5 -32C-5 -34.5 -3.5 -37.5 0 -42Z" fill="$gold"/>
<path d="M0 -36C1.8 -33.8 2.5 -32.5 2.5 -31.2A2.5 2.5 0 0 1 -2.5 -31.2C-2.5 -32.5 -1.8 -33.8 0 -36Z" fill="#ffe9a3"/>
</g>
</g>
''';
    }

    return SvgPicture.string(
      _svg('0 0 200 120', '''
<g opacity=".3" transform="translate(56 14)">${_wat(gold)}</g>
${garland(40)}${garland(184)}
<path d="M4 108.5H198" fill="none" stroke="$frame" stroke-opacity=".35"/>
<g transform="translate(18 108)">
<path d="M-13.5 -2V-34C-13.5 -41 13.5 -41 13.5 -34V-2" fill="none" stroke="$frame" stroke-width="1.6" stroke-linecap="round"/>
<path d="M-5 -39.2H5" fill="none" stroke="$frame" stroke-width="3" stroke-linecap="round"/>
<rect x="-11" y="-9" width="22" height="8" rx="2.5" fill="$cream" stroke="$outline"/>
<rect x="-11" y="-18" width="22" height="8" rx="2.5" fill="$cream" stroke="$outline"/>
<rect x="-11" y="-27" width="22" height="8" rx="2.5" fill="$cream" stroke="$outline"/>
<path d="M-10.5 -5.5H10.5M-10.5 -14.5H10.5M-10.5 -23.5H10.5" fill="none" stroke="$gold" stroke-width="2"/>
<path d="M-11 -28C-11 -33 11 -33 11 -28Z" fill="$gold" stroke="$outline"/>
<circle cx="0" cy="-33.2" r="1.8" fill="$outline"/>
</g>
<g transform="translate(52 108)">$cake<g transform="translate(1 -11.5) rotate(-7)">$cake</g></g>
<g transform="translate(92 108)">
<path d="M-9 0H9L6 -4H-6Z" fill="$outline"/>
<rect x="-3" y="-9" width="6" height="5" fill="$outline"/>
<ellipse cx="0" cy="-10" rx="18" ry="3.5" fill="$gold" stroke="$outline"/>
<g fill="$cream" stroke="$outline" stroke-width=".9">
<circle cx="-8.4" cy="-14.5" r="4.2"/><circle cx="0" cy="-14.5" r="4.2"/><circle cx="8.4" cy="-14.5" r="4.2"/>
<circle cx="-4.2" cy="-21.5" r="4.2"/><circle cx="4.2" cy="-21.5" r="4.2"/>
<circle cx="0" cy="-28.5" r="4.2"/>
</g>
</g>
<g transform="translate(134 107)">${_lotus(leaf, petalEdge)}</g>
${candle(162, 26)}
<g transform="translate(176 108)">
<path d="M-3 -9L-6.5 -30M0 -9V-32M3 -9L6.5 -30" fill="none" stroke="$red" stroke-width="1.2" stroke-linecap="round"/>
<circle cx="-6.5" cy="-30.5" r="1.3" fill="$gold"/><circle cx="0" cy="-32.5" r="1.3" fill="$gold"/><circle cx="6.5" cy="-30.5" r="1.3" fill="$gold"/>
<path d="M0 -35c-3-3 3-5 0-8c-3-3 3-5 0-8" fill="none" stroke="$smoke" stroke-opacity=".5" stroke-linecap="round"/>
<path d="M-6 0H6L8 -9H-8Z" fill="$outline"/>
</g>
${candle(190, 17)}
'''),
      width: width,
      height: width * 0.6,
      excludeFromSemantics: true,
    );
  }
}

/// The small outline lotus that marks a Pchum Ben heading. Square; [size] is
/// its side. Defaults to the `yeld` token, the accent that holds as a line on
/// either ground.
class LotusMark extends StatelessWidget {
  const LotusMark({super.key, this.size = 16, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = _hex(color ?? AppColors.of(context).yeld);
    return SvgPicture.string(
      _svg(
        '0 0 20 20',
        '<g fill="none" stroke="$c" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round">'
            '<path d="M10 3C7.4 6 7.4 10.6 10 14C12.6 10.6 12.6 6 10 3Z"/>'
            '<path d="M9.2 13.6C6 13.4 3.6 11 3 7.6C5.4 7.7 7.2 8.8 8.2 10.4"/>'
            '<path d="M10.8 13.6C14 13.4 16.4 11 17 7.6C14.6 7.7 12.8 8.8 11.8 10.4"/>'
            '<path d="M5 16.5H15"/>'
            '</g>',
      ),
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}

/// A pink lotus on its leaf, seen from the side. [edge] is the line between
/// petals — pass the color of whatever it sits on.
class LotusFlower extends StatelessWidget {
  const LotusFlower({super.key, this.width = 31, required this.edge});

  final double width;
  final Color edge;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _svg('-22 -30 44 34', _lotus(_hex(AppColors.of(context).grn), _hex(edge))),
      width: width,
      height: width * 34 / 44,
      excludeFromSemantics: true,
    );
  }
}
