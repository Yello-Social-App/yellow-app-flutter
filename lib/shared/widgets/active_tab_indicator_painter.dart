import 'package:flutter/material.dart';

/// Paints the active-tab indicator shared by the bottom nav and the Feed /
/// Community tab row: a short glowing accent line on one edge of the bar,
/// centred on the selected slot, with a small arrowhead popping out of it
/// toward that tab's icon or label.
///
/// [atBottom] picks the edge: `false` (the bottom nav) sits the line on the
/// bar's top edge with the arrow pointing down; `true` (a header tab row)
/// sits it on the bottom edge with the arrow pointing up.
///
/// The glow is a `MaskFilter.blur` on a `Paint`, never a blurred `BoxShadow`
/// — a blurred `BoxShadow` on a rebuilding widget crashed this project's
/// Impeller renderer on-device (`docs/GOTCHAS.md`), while this painter has
/// been driven from a running animation since the bottom bar shipped.
class ActiveTabIndicatorPainter extends CustomPainter {
  const ActiveTabIndicatorPainter({
    required this.selectedCenter,
    required this.slotWidth,
    required this.color,
    this.atBottom = false,
    this.lotus = false,
  });

  final double selectedCenter;
  final double slotWidth;
  final Color color;
  final bool atBottom;

  /// Draws a lotus bud on the line in place of the arrowhead — the Pchum Ben
  /// theme's marker (ADR-057).
  final bool lotus;

  @override
  void paint(Canvas canvas, Size size) {
    const outerInset = 2.0;
    final lineY = atBottom ? size.height - outerInset : outerInset;

    final lineHalfWidth = slotWidth * .2;
    final lineStart = Offset(selectedCenter - lineHalfWidth, lineY);
    final lineEnd = Offset(selectedCenter + lineHalfWidth, lineY);

    final glowLinePaint = Paint()
      ..color = color.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(lineStart, lineEnd, glowLinePaint);
    canvas.drawLine(lineStart, lineEnd, linePaint);

    if (lotus) {
      _paintLotusBud(canvas, lineY);
      return;
    }

    // Small arrowhead on the line, tip pointing away from the edge — base
    // overlaps the line slightly so it reads as popping out of it.
    const arrowHalfWidth = 5.0;
    const arrowHeight = 6.0;
    final direction = atBottom ? -1.0 : 1.0;
    final arrowBaseY = lineY + direction;
    final arrowTipY = arrowBaseY + direction * arrowHeight;
    final arrowPath = Path()
      ..moveTo(selectedCenter - arrowHalfWidth, arrowBaseY)
      ..lineTo(selectedCenter, arrowTipY)
      ..lineTo(selectedCenter + arrowHalfWidth, arrowBaseY)
      ..close();

    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = color.withValues(alpha: .55)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(arrowPath, Paint()..color = color);
  }

  /// Three petals opening away from the line — the Pchum Ben marker. Flat
  /// fills with no glow: the bud is small enough that a blur would only
  /// smear the gaps between its petals.
  void _paintLotusBud(Canvas canvas, double lineY) {
    final cx = selectedCenter;
    // Petal coordinates are distances *away from the line*; `d` is which way
    // that is — up from a header tab row's bottom edge, down from the bottom
    // nav's top edge. Same convention as the arrowhead above.
    final d = atBottom ? -1.0 : 1.0;
    final base = lineY + d;
    Offset at(double dx, double dy) => Offset(cx + dx, base + d * dy);

    Path petal(List<Offset> p) => Path()
      ..moveTo(p[0].dx, p[0].dy)
      ..cubicTo(p[1].dx, p[1].dy, p[2].dx, p[2].dy, p[3].dx, p[3].dy)
      ..cubicTo(p[4].dx, p[4].dy, p[5].dx, p[5].dy, p[0].dx, p[0].dy)
      ..close();

    final paint = Paint()..color = color;
    for (final side in const [-1.0, 1.0]) {
      canvas.drawPath(
        petal([
          at(0, 0),
          at(side * 4, 0),
          at(side * 7, 2),
          at(side * 8, 5.5),
          at(side * 4.5, 5.5),
          at(side * 1.5, 3.5),
        ]),
        paint,
      );
    }
    canvas.drawPath(petal([at(0, 0), at(-3, 2.5), at(-3, 6.5), at(0, 10), at(3, 6.5), at(3, 2.5)]), paint);
  }

  @override
  bool shouldRepaint(ActiveTabIndicatorPainter oldDelegate) =>
      oldDelegate.selectedCenter != selectedCenter ||
      oldDelegate.slotWidth != slotWidth ||
      oldDelegate.color != color ||
      oldDelegate.atBottom != atBottom ||
      oldDelegate.lotus != lotus;
}
