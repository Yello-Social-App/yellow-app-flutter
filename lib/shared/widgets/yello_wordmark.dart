import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The "yello." wordmark, drawn entirely in code rather than loaded from a
/// raster asset — vector-drawn text stays sharp at any device pixel ratio.
///
/// The style is transcribed from the web/desktop design system's
/// `.brand-wordmark` rule (`globals.css`, used by `brand-logo.tsx`):
/// ```css
/// .brand-wordmark {
///   font-family: 'Fredoka'; font-weight: 700; line-height: 1;
///   letter-spacing: -0.01em; color: #fcdb02;
///   text-shadow: 0.035em 0.05em 0 #b39700, 0.07em 0.1em 0 #6b5a00;
/// }
/// :root[data-theme='light'] .brand-wordmark {
///   -webkit-text-stroke: 0.1em #1c1a12; paint-order: stroke fill;
///   text-shadow: 0.05em 0.08em 0 #1c1a12;
/// }
/// ```
/// plus the `pb-[0.08em]` the logo component puts on the span. Every `em` is
/// a multiple of [fontSize], so the mark scales as one piece.
///
/// - **Dark**: a two-step darker-yellow extrusion — hard (zero-blur) text
///   shadows, listed deepest-first because Flutter paints `shadows` in list
///   order (last on top), the reverse of CSS `text-shadow`.
/// - **Light**: a dark outline painted *under* the fill (`paint-order: stroke
///   fill`, so only the outer half of the 0.1em stroke shows) and a hard drop
///   shadow of the whole outlined glyph. Flutter's text shadow is the bare
///   fill silhouette (it ignores the stroke), so the shadow is drawn as its
///   own offset stroke + fill pair instead of through `TextStyle.shadows`.
///
/// The "." is Fredoka's own full stop, part of the text as on the web — no
/// longer a hand-drawn circle.
///
/// The web keys the variant off the page theme; here it follows
/// `Theme.of(context).brightness` unless [brightness] overrides it — pass
/// `Brightness.dark` where the mark sits on a surface that is dark in both
/// themes (the auth header, the Chat slab).
///
/// The shadows are zero-blur `Shadow`s on text, not blurred `BoxShadow`s, so
/// the Impeller crash in GOTCHAS doesn't apply.
class YelloWordmark extends StatelessWidget {
  const YelloWordmark({super.key, this.fontSize = 52, this.text = 'yello', this.brightness});

  final double fontSize;

  /// The word this mark draws, before its full stop. Defaults to the literal
  /// brand wordmark ('yello'); other screens (Signals, Chat) pass their own
  /// page title here to get the same brand treatment.
  final String text;

  /// Which `.brand-wordmark` variant to draw. Null follows the ambient theme.
  final Brightness? brightness;

  static const _fill = Color(0xFFFCDB02);
  static const _extrudeNear = Color(0xFFB39700);
  static const _extrudeFar = Color(0xFF6B5A00);
  static const _ink = Color(0xFF1C1A12);

  @override
  Widget build(BuildContext context) {
    final label = '$text.';
    final base = GoogleFonts.fredoka(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: fontSize * -0.01,
      color: _fill,
    );
    final isLight = (brightness ?? Theme.of(context).brightness) == Brightness.light;

    final Widget mark;
    if (isLight) {
      final stroke = base.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = fontSize * 0.1
          ..strokeJoin = StrokeJoin.round
          ..color = _ink,
      );
      final dx = fontSize * 0.05;
      final dy = fontSize * 0.08;
      mark = Stack(
        // The shadow hangs outside the text box, as CSS shadows and strokes
        // don't take up layout space either.
        clipBehavior: Clip.none,
        children: [
          Positioned(left: dx, top: dy, child: Text(label, style: stroke)),
          Positioned(left: dx, top: dy, child: Text(label, style: base.copyWith(color: _ink))),
          Text(label, style: stroke),
          Text(label, style: base),
        ],
      );
    } else {
      mark = Text(
        label,
        style: base.copyWith(
          shadows: [
            Shadow(offset: Offset(fontSize * 0.07, fontSize * 0.1), color: _extrudeFar),
            Shadow(offset: Offset(fontSize * 0.035, fontSize * 0.05), color: _extrudeNear),
          ],
        ),
      );
    }

    // One label for the stacked layers, so a screen reader reads it once.
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Padding(padding: EdgeInsets.only(bottom: fontSize * 0.08), child: mark),
      ),
    );
  }
}
