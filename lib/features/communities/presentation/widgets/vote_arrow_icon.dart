import 'package:flutter/material.dart';

import '../../../../core/constants/asset_constants.dart';

/// The up / down vote arrow, as one of four authored PNGs: outline when the
/// viewer has not voted that way, filled when they have.
///
/// Drawn **untinted**. The four files already ship in the brand yellow, so
/// running them through `Image.asset`'s `color` would throw away the artwork's
/// own shading and reduce them to flat silhouettes — the reason there are four
/// files rather than one tinted glyph. [dimmed] is therefore an opacity knock
/// back rather than a color swap, which is what a write already in flight
/// (`busy`) needs to look like.
///
/// Shared by the thread card's vertical vote column and the thread header's
/// horizontal pill so the two can never drift apart.
class VoteArrowIcon extends StatelessWidget {
  const VoteArrowIcon({
    super.key,
    required this.up,
    required this.active,
    this.dimmed = false,
    this.size = 20,
  });

  /// Up arrow when true, down arrow when false. A plain bool rather than
  /// `CommunityVote`, because that enum's third value (`none`) describes the
  /// viewer's *state*, not a direction an arrow can point.
  final bool up;

  /// The viewer's vote currently points this way — draws the filled variant.
  final bool active;

  /// A vote is in flight, so the control is inert.
  final bool dimmed;

  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = up
        ? (active ? AssetConstants.voteUpArrowActive : AssetConstants.voteUpArrow)
        : (active ? AssetConstants.voteDownArrowActive : AssetConstants.voteDownArrow);

    return Opacity(
      opacity: dimmed ? 0.4 : 1,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        // The sources are 32px squares drawn at 18-20, so let the engine
        // decode at the size actually painted rather than full resolution.
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      ),
    );
  }
}
