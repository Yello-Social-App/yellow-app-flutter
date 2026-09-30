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
  });

  final double selectedCenter;
  final double slotWidth;
  final Color color;
  final bool atBottom;

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

  @override
  bool shouldRepaint(ActiveTabIndicatorPainter oldDelegate) =>
      oldDelegate.selectedCenter != selectedCenter ||
      oldDelegate.slotWidth != slotWidth ||
      oldDelegate.color != color ||
      oldDelegate.atBottom != atBottom;
}
