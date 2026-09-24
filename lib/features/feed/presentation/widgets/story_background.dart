import 'package:flutter/material.dart';

import '../../domain/entities/story_entity.dart';

/// The eight gradients `cover-0` … `cover-7` render as.
///
/// The backend stores only the **key** — it has no notion of a colour, and
/// never sends CSS — so this table is the whole definition of what a text
/// story looks like. Changing a pair here restyles every existing story of
/// that cover, including archived ones, with no migration.
///
/// Each pair is dark enough for white text at the app's story type sizes;
/// `cover-1` is the brand yellow and is the one exception, so it carries
/// ink-coloured text instead (see [storyBackgroundForeground]).
const List<(Color, Color)> kStoryCoverGradients = [
  (Color(0xFF2B2A24), Color(0xFF14120C)), // cover-0 — ink
  (Color(0xFFFFD86B), Color(0xFFF4A93C)), // cover-1 — brand yellow
  (Color(0xFF4A3AA8), Color(0xFF7E5BEF)), // cover-2 — violet
  (Color(0xFF0E6E5B), Color(0xFF2E9E5B)), // cover-3 — pine
  (Color(0xFFB83A54), Color(0xFFE4574F)), // cover-4 — rose
  (Color(0xFF15466E), Color(0xFF2E8BC0)), // cover-5 — deep blue
  (Color(0xFF6B4423), Color(0xFFB07A3C)), // cover-6 — amber clay
  (Color(0xFF3D2350), Color(0xFF8A4FA8)), // cover-7 — plum
];

/// The brand-yellow cover is the only light one — dark ink text on it,
/// white on every other.
const Color _storyInk = Color(0xFF14120C);

Color storyBackgroundForeground(StoryBackground? background) =>
    background == StoryBackground.cover1 ? _storyInk : Colors.white;

LinearGradient storyBackgroundGradient(StoryBackground? background) {
  final (from, to) = kStoryCoverGradients[(background ?? StoryBackground.cover0).index];
  return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [from, to]);
}

/// A cover swatch — the composer's background picker, and the archive's
/// thumbnail for a text story.
class StoryCoverSwatch extends StatelessWidget {
  const StoryCoverSwatch({
    super.key,
    required this.background,
    this.selected = false,
    this.size = 44,
    this.borderRadius,
    this.onTap,
    this.child,
  });

  final StoryBackground background;
  final bool selected;
  final double size;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size / 3);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: storyBackgroundGradient(background),
          borderRadius: radius,
          border: Border.all(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.35),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: child,
      ),
    );
  }
}
