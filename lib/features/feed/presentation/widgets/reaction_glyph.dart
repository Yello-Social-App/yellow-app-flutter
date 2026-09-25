import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../domain/entities/post_entity.dart';

/// A **fixed-size** square slot for one reaction glyph.
///
/// The fixed box is the whole point of this widget. A reaction affordance
/// swaps its glyph between an [Icon] and a [Text] emoji, and those have
/// different intrinsic sizes — and differ again *per emoji*, since `❤️` is a
/// text-presentation glyph with a narrow advance while `😆`/`😮` are wide
/// pictographic ones. Laid out at their natural size, every reaction change
/// resized the pill around them, which read on-device as the like button
/// shrinking and growing depending on which reaction was active.
///
/// [BoxFit.scaleDown] keeps a glyph that happens to measure larger than
/// [size] inside the box (an emoji font can report an advance wider than its
/// em) instead of letting it overflow or get clipped, without scaling the
/// smaller glyphs up.
class ReactionGlyphSlot extends StatelessWidget {
  const ReactionGlyphSlot({super.key, required this.size, required this.child});

  /// Side of the square slot, in logical pixels.
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Center(
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    ),
  );
}

/// The viewer's current [reaction] drawn inside a [ReactionGlyphSlot]: an
/// outlined heart when they haven't reacted, a filled heart for
/// [ReactionType.like] (this app's quick-like renders as a heart rather than
/// 👍 — see `_Actions` in `post_card.dart`), and the reaction's own emoji for
/// the other five types.
///
/// [color] tints the heart only; an emoji carries its own colors.
class ReactionGlyph extends StatelessWidget {
  const ReactionGlyph({super.key, required this.reaction, required this.color, this.size = 16, this.animate = false});

  final ReactionType? reaction;
  final Color color;

  /// Side of the fixed slot, and the heart icon's own size.
  final double size;

  /// Scale-transitions between glyphs when [reaction] changes. Off by
  /// default — only the feed card's pill animates today.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final glyph = reaction == null || reaction == ReactionType.like
        ? Icon(
            reaction == null ? CupertinoIcons.heart : CupertinoIcons.heart_fill,
            key: ValueKey(reaction),
            size: size,
            color: color,
          )
        : Text(
            reaction!.emoji,
            key: ValueKey(reaction),
            // Slightly under the slot (and `height: 1`, so the font's own
            // line spacing doesn't pad the box) to match the optical weight
            // of the heart icon at the same [size].
            style: TextStyle(fontSize: size * 0.85, height: 1),
          );
    return ReactionGlyphSlot(
      size: size,
      child: animate
          ? AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: glyph,
            )
          : glyph,
    );
  }
}
