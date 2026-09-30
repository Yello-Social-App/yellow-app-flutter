import 'package:flutter/widgets.dart';

/// The app's one "send" glyph — a folded paper plane, nose to the top right.
/// Every control that sends text uses it: the chat composer, both comment
/// composers, the story reply, and the post/thread publish buttons.
///
/// Drawn from a path rather than an [IconData] so it can sit in any slot that
/// takes an `Icon` and still pick up that slot's colour and size from the
/// ambient [IconTheme], exactly as an `Icon` would.
class SendIcon extends StatelessWidget {
  const SendIcon({super.key, this.size, this.color, this.semanticLabel});

  /// Defaults to the ambient [IconTheme]'s size, then 24.
  final double? size;

  /// Defaults to the ambient [IconTheme]'s colour.
  final Color? color;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final dimension = size ?? iconTheme.size ?? 24;
    final ink = color ?? iconTheme.color ?? const Color(0xFF000000);
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: dimension,
          child: CustomPaint(painter: _SendIconPainter(ink)),
        ),
      ),
    );
  }
}

class _SendIconPainter extends CustomPainter {
  const _SendIconPainter(this.color);

  final Color color;

  /// Traced on a 24-unit grid. The one sharp point is the fold's notch at
  /// (14.6, 9.6); every outer corner is rounded.
  static final Path _glyph = Path()
    ..moveTo(21.79, 1.70)
    ..quadraticBezierTo(23.00, 1.00, 22.72, 2.37)
    ..lineTo(19.34, 19.22)
    ..quadraticBezierTo(19.10, 20.40, 17.91, 20.23)
    ..lineTo(14.19, 19.69)
    ..quadraticBezierTo(13.60, 19.60, 13.13, 19.97)
    ..lineTo(9.76, 22.62)
    ..quadraticBezierTo(8.90, 23.30, 8.86, 22.20)
    ..lineTo(8.72, 18.10)
    ..quadraticBezierTo(8.70, 17.60, 9.00, 17.20)
    ..lineTo(14.60, 9.60)
    ..lineTo(6.09, 15.46)
    ..quadraticBezierTo(5.60, 15.80, 5.05, 15.56)
    ..lineTo(2.09, 14.23)
    ..quadraticBezierTo(0.90, 13.70, 2.03, 13.05)
    ..close();

  /// The glyph fills its grid edge to edge; Cupertino glyphs leave some air,
  /// so it is drawn slightly inset to sit at the same optical weight.
  static const double _inset = 0.88;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24 * _inset;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale)
      ..translate(-12, -12)
      ..drawPath(_glyph, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_SendIconPainter oldDelegate) => oldDelegate.color != color;
}
