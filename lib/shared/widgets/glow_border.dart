import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps [child] in a glowing outline: a soft blurred halo under a crisp
/// stroke, both following [borderRadius].
///
/// Painted with `MaskFilter.blur` in a `CustomPainter` on purpose, never as a
/// blurred `BoxShadow`. A blurred shadow in a decoration that rebuilds on
/// Cubit state crashed this project's Impeller renderer (`docs/GOTCHAS.md`);
/// a blurred `Paint` is the pattern `ActiveTabIndicatorPainter` has shipped
/// safely all along. The halo spills past the child's box, so the parent must
/// not clip (lists don't; give it a few pixels of room where it matters).
class GlowBorder extends StatelessWidget {
  const GlowBorder({
    super.key,
    required this.color,
    required this.borderRadius,
    required this.child,
    this.width = 1.5,
    this.blur = 5,
    this.glowOpacity = 0.55,
  });

  final Color color;
  final BorderRadius borderRadius;
  final Widget child;

  /// Width of the crisp stroke.
  final double width;

  /// Blur sigma of the halo. Zero draws the crisp stroke alone.
  final double blur;

  /// Alpha of the halo relative to [color].
  final double glowOpacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: GlowBorderPainter(
        color: color,
        borderRadius: borderRadius,
        width: width,
        blur: blur,
        glowOpacity: glowOpacity,
      ),
      child: child,
    );
  }
}

class GlowBorderPainter extends CustomPainter {
  const GlowBorderPainter({
    required this.color,
    required this.borderRadius,
    this.width = 1.5,
    this.blur = 5,
    this.glowOpacity = 0.55,
  });

  final Color color;
  final BorderRadius borderRadius;
  final double width;
  final double blur;
  final double glowOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by half the stroke so the crisp line sits inside the box, where
    // a `Border` would have drawn it.
    final rrect = borderRadius.toRRect(Offset.zero & size).deflate(width / 2);
    paintHalo(canvas, rrect, color: color, width: width, blur: blur, opacity: glowOpacity);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  /// The soft halo alone, centred on [rrect]'s outline. Shared with
  /// [GlowInputBorder] so a field outlined through `InputDecoration` glows
  /// exactly like one wrapped in [GlowBorder].
  static void paintHalo(
    Canvas canvas,
    RRect rrect, {
    required Color color,
    required double width,
    required double blur,
    required double opacity,
  }) {
    if (blur <= 0 || opacity <= 0) return;
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 2.5
        ..color = color.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  @override
  bool shouldRepaint(GlowBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.width != width ||
      oldDelegate.blur != blur ||
      oldDelegate.glowOpacity != glowOpacity;
}

/// An [OutlineInputBorder] with [GlowBorder]'s halo around its stroke, for
/// fields whose outline comes from their `InputDecoration` rather than a
/// wrapping shell. Give it as the decoration's `focusedBorder`: the decorator
/// tweens from the enabled border into this one, so the glow grows in over
/// the same animation that recolours the stroke.
///
/// Painted with a blurred `Paint` like [GlowBorder] — never a blurred
/// `BoxShadow`, which crashed this project's renderer on a rebuilding widget
/// (`docs/GOTCHAS.md`).
class GlowInputBorder extends OutlineInputBorder {
  const GlowInputBorder({
    super.borderSide,
    super.borderRadius,
    super.gapPadding,
    this.blur = 5,
    this.glowOpacity = 0.55,
  });

  /// Blur sigma of the halo.
  final double blur;

  /// Alpha of the halo relative to the stroke's colour.
  final double glowOpacity;

  @override
  GlowInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
    double? blur,
    double? glowOpacity,
  }) {
    return GlowInputBorder(
      borderSide: borderSide ?? this.borderSide,
      borderRadius: borderRadius ?? this.borderRadius,
      gapPadding: gapPadding ?? this.gapPadding,
      blur: blur ?? this.blur,
      glowOpacity: glowOpacity ?? this.glowOpacity,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is OutlineInputBorder) {
      return GlowInputBorder(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
        gapPadding: _lerp(a.gapPadding, gapPadding, t),
        blur: blur,
        // From a plain outline the halo grows in from nothing.
        glowOpacity: a is GlowInputBorder ? _lerp(a.glowOpacity, glowOpacity, t) : glowOpacity * t,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  GlowInputBorder scale(double t) =>
      copyWith(borderSide: borderSide.scale(t), borderRadius: borderRadius * t, gapPadding: gapPadding * t);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    final center = borderRadius.toRRect(rect).deflate(borderSide.width / 2);
    canvas.save();
    // Keep the halo out of a floating label's notch, the same span the
    // stroke itself leaves open.
    if (gapStart != null && gapPercentage > 0) {
      final extent = _lerp(0, gapExtent + gapPadding * 2, gapPercentage);
      final start = textDirection == TextDirection.rtl
          ? math.max(0.0, gapStart + gapPadding - extent)
          : math.max(0.0, gapStart - gapPadding);
      final reach = blur * 3 + borderSide.width;
      canvas.clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(rect.inflate(reach)),
          Path()
            ..addRect(Rect.fromLTRB(rect.left + start, rect.top - reach, rect.left + start + extent, rect.top + reach)),
        ),
      );
    }
    GlowBorderPainter.paintHalo(
      canvas,
      center,
      color: borderSide.color,
      width: borderSide.width,
      blur: blur,
      opacity: glowOpacity,
    );
    canvas.restore();
    super.paint(
      canvas,
      rect,
      gapStart: gapStart,
      gapExtent: gapExtent,
      gapPercentage: gapPercentage,
      textDirection: textDirection,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlowInputBorder && super == other && other.blur == blur && other.glowOpacity == glowOpacity;

  @override
  int get hashCode => Object.hash(super.hashCode, blur, glowOpacity);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
