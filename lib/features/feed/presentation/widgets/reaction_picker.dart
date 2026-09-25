import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/post_entity.dart';
import 'reaction_glyph.dart';

/// Square tap target per reaction tile.
const double _tileExtent = 44;

/// Inset around the row of tiles.
const double _railPadding = 5;

/// Gap between the rail and the button it's anchored to.
const double _anchorGap = 8;

/// Keep-off margin from the screen edges, on top of the safe area.
const double _screenMargin = 10;

/// The rail's height is fixed and known before layout, so the side it goes
/// on can be decided in `buildPage` rather than after measuring.
const double _railHeight = _tileExtent + _railPadding * 2;

/// Opens the long-press reaction picker: a floating rail of the 6 backend
/// reaction types anchored **directly above the button that was pressed**
/// (below it instead when there isn't room above), the way social apps draw
/// this control. It used to be a `showModalBottomSheet`, which put the
/// reactions at the far end of the screen from the thumb that had just
/// long-pressed.
///
/// [anchorContext] must be the button's own context — its `RenderBox` is
/// what the rail is positioned against, so pass the context of the pill
/// itself, not of the row or the card containing it. A `Builder` wrapped
/// around the button is the cheapest way to get one.
///
/// Returns the tapped [ReactionType], or null if the rail was dismissed by
/// tapping outside it or going back.
///
/// Every tile is a real backend reaction — there is no decorative one. The
/// 🖕 tile is `LOVE` wearing a different glyph (see [ReactionType.emoji]);
/// the backend enum is closed at six values, so a 7th type would have
/// nowhere to be stored, counted or listed back.
Future<ReactionType?> showReactionPicker(BuildContext anchorContext, {ReactionType? current}) {
  // Root navigator for the same reason the sheet needed it: a post card can
  // be long-pressed while the floating pill nav bar is on screen, and a
  // branch-local route paints behind that bar.
  final navigator = Navigator.of(anchorContext, rootNavigator: true);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final box = anchorContext.findRenderObject()! as RenderBox;
  // Anchor in the overlay's own coordinate space — the same space the
  // route's full-screen layout works in, so the two can't disagree about
  // where the button is (they would with raw global coordinates if the
  // overlay didn't happen to start at 0,0).
  final anchor = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;

  return navigator.push(_ReactionRailRoute(anchor: anchor, current: current));
}

class _ReactionRailRoute extends PopupRoute<ReactionType> {
  _ReactionRailRoute({required this.anchor, required this.current});

  final Rect anchor;
  final ReactionType? current;

  /// Light enough that the post stays readable behind the rail, dark enough
  /// that the rail reads as floating over it — which is the job a drop
  /// shadow would normally do (see [_ReactionRail] for why there isn't one).
  @override
  Color get barrierColor => Colors.black.withValues(alpha: 0.10);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => MaterialLocalizations.of(navigator!.context).modalBarrierDismissLabel;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 170);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 110);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final padding = MediaQuery.paddingOf(context) + const EdgeInsets.all(_screenMargin);
    final above = anchor.top - _anchorGap - _railHeight >= padding.top;
    return CustomSingleChildLayout(
      delegate: _RailLayout(anchor: anchor, padding: padding, above: above),
      child: _ReactionRail(current: current, animation: animation, above: above),
    );
  }
}

/// Places the rail centred on the anchor and just above it, flipping below
/// when it doesn't fit and sliding along the screen when centring would push
/// it past an edge (a like button near the left margin, say).
class _RailLayout extends SingleChildLayoutDelegate {
  const _RailLayout({required this.anchor, required this.padding, required this.above});

  final Rect anchor;
  final EdgeInsets padding;
  final bool above;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest).deflate(padding);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final y = above
        ? anchor.top - _anchorGap - childSize.height
        // Clamped so a button low on the screen doesn't push the rail off
        // it — overlapping the button is still reachable, off-screen isn't.
        : math.min(anchor.bottom + _anchorGap, size.height - padding.bottom - childSize.height);
    final maxX = math.max(padding.left, size.width - padding.right - childSize.width);
    final x = (anchor.center.dx - childSize.width / 2).clamp(padding.left, maxX);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_RailLayout old) => old.anchor != anchor || old.padding != padding || old.above != above;
}

class _ReactionRail extends StatelessWidget {
  const _ReactionRail({required this.current, required this.animation, required this.above});

  final ReactionType? current;
  final Animation<double> animation;

  /// Which side of the button the rail landed on — it scales out of the edge
  /// facing the button, so it reads as coming out of what was pressed.
  final bool above;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // `drive` rather than a `CurvedAnimation`: this widget has no ticker to
    // dispose one with, and the route's animation outlives the build.
    final curved = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: curved.drive(Tween<double>(begin: 0.82, end: 1)),
        alignment: above ? Alignment.bottomCenter : Alignment.topCenter,
        child: Material(
          color: colors.surf,
          // No `AppShadows.card` here on purpose: this subtree is scaled and
          // faded on every frame of the entry animation, and a blurred
          // `BoxShadow` under that is the Impeller crash shape documented in
          // `docs/GOTCHAS.md`. The barrier scrim separates it from the page
          // instead.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            side: BorderSide(color: colors.line, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(_railPadding),
            // Six 44px tiles need 274px of rail, which fits a 320dp screen —
            // but 320dp is also what a 360dp phone becomes at Android's
            // larger Display size settings, and one more tile or a narrower
            // device would overflow the `Row`. Scaling the rail down beats
            // `RenderFlex overflowed`; see `docs/GOTCHAS.md`.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final type in ReactionType.values)
                    _ReactionOption(
                      emoji: type.emoji,
                      selected: type == current,
                      onTap: () => Navigator.of(context).pop(type),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactionOption extends StatelessWidget {
  const _ReactionOption({required this.emoji, required this.selected, required this.onTap});

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox.square(
      dimension: _tileExtent,
      child: Material(
        color: selected ? colors.yelb : Colors.transparent,
        shape: selected ? CircleBorder(side: BorderSide(color: colors.yel, width: 1.5)) : const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          // Uniform slot so all six tiles come out the same size — emoji
          // advance widths differ per glyph. See [ReactionGlyphSlot].
          child: Center(
            child: ReactionGlyphSlot(size: 26, child: Text(emoji, style: const TextStyle(fontSize: 25, height: 1))),
          ),
        ),
      ),
    );
  }
}
