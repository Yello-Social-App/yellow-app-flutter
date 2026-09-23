import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// A single shimmering placeholder block — for feed/list skeletons shown
/// while a Cubit is in its loading state.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppRadii.xs,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 3, 0),
              end: Alignment(0 + t * 3, 0),
              colors: [colors.surf2, colors.line, colors.surf2],
            ),
          ),
        );
      },
    );
  }
}

/// A generic list-row skeleton — an avatar, two text lines and a block —
/// inside a card with the app's standard surface/border/shadow treatment.
/// Used by the screens whose loading state is a plain list of rows (Inbox,
/// Circle, Signals). The feed's own loading state uses [ShimmerPostCard],
/// which mirrors [PostCard]'s exact geometry instead.
class ShimmerListCard extends StatelessWidget {
  const ShimmerListCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              ShimmerBox(width: 42, height: 42, borderRadius: 21),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 120, height: 12),
                    SizedBox(height: 8),
                    ShimmerBox(width: 80, height: 9),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          ShimmerBox(height: 180, borderRadius: 20),
        ],
      ),
    );
  }
}

/// The feed's loading skeleton — a structural stand-in for a real
/// [PostCard], not just "a card with some boxes in it".
///
/// Every measurement here is copied from [PostCard]'s own subtree so the
/// placeholder occupies the same space the real card will: the outer
/// `Container` (bottom margin 16, `line` border at 1.5, [AppRadii.xxl]
/// corners, the same soft drop shadow, `Clip.antiAlias`), the header's
/// `fromLTRB(14, 14, 14, 12)` padding with a 42px avatar + 11px gap and the
/// "···" button's 8px-padded 20px glyph on the right, the body's 14px text
/// inset / 12px photo inset at [AppRadii.lg], and the action row's
/// `EdgeInsets.all(12)` with 33px-tall pills (13/9 padding around a 15px
/// icon) — three grouped left, Save pushed to the trailing edge.
///
/// Because the geometry lines up, swapping real posts in doesn't visibly
/// re-flow the list; previously the skeleton was a 14px-padded box with a
/// 180px block and no action row, so every card jumped and grew the moment
/// the feed resolved.
class ShimmerPostCard extends StatelessWidget {
  const ShimmerPostCard({super.key, this.hasImage = true});

  /// Mirrors [PostCard]'s two body shapes: `true` draws a one-line caption
  /// above a photo block, `false` the three-line text-only body. The feed
  /// renders one of each while loading so the skeleton reads like a real,
  /// mixed feed rather than two identical tiles.
  final bool hasImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PostCard's _Header: name is titleMd (14/1.15 -> 16), the meta
          // line metaMono (10.5/1.3 -> 14), 4px apart.
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                ShimmerBox(width: 42, height: 42, borderRadius: 21),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 124, height: 16),
                      SizedBox(height: 4),
                      ShimmerBox(width: 92, height: 14),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: ShimmerBox(width: 20, height: 20, borderRadius: 10),
                ),
              ],
            ),
          ),
          if (hasImage) ...[
            const _ShimmerTextLines(lineWidthFactors: [0.72]),
            // _PhotoBody insets the photo by 12 (not the body text's 14) and
            // rounds it at AppRadii.lg; 280 is PostImageCarousel's own
            // placeholderHeight, i.e. what an unresolved photo occupies.
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: ShimmerBox(height: 280, borderRadius: AppRadii.lg),
            ),
          ] else
            const _ShimmerTextLines(lineWidthFactors: [1, 1, 0.56]),
          // _Actions: react / comment / repost grouped left, Save trailing.
          const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                ShimmerBox(width: 62, height: 33, borderRadius: AppRadii.pill),
                SizedBox(width: 7),
                ShimmerBox(width: 58, height: 33, borderRadius: AppRadii.pill),
                SizedBox(width: 7),
                ShimmerBox(width: 58, height: 33, borderRadius: AppRadii.pill),
                Spacer(),
                // Flexible so the trailing pill gives way on a 320dp screen,
                // where these four fixed widths total more than the row. The
                // real pills size to their (short) counts and fit; these are
                // sized for the wide case, so this one shrinks instead of
                // overflowing.
                Flexible(child: ShimmerBox(width: 82, height: 33, borderRadius: AppRadii.pill)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stand-in for a post's body copy: one 15px bar per rendered line, 7px
/// apart, so a block of N lines takes the same room as N lines of
/// `AppTextStyles.body` (15/1.5 = 22.5 each). Laid out inside _TextBody's
/// `fromLTRB(14, 0, 14, 12)` padding. Widths are fractions of the card so
/// the last (short) line scales with the screen instead of being a fixed
/// stub.
class _ShimmerTextLines extends StatelessWidget {
  const _ShimmerTextLines({required this.lineWidthFactors});

  final List<double> lineWidthFactors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lineWidthFactors.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: lineWidthFactors[i],
              child: const ShimmerBox(height: 15, borderRadius: AppRadii.sm),
            ),
          ],
        ],
      ),
    );
  }
}

/// The card chrome shared by both skeletons — identical to [PostCard]'s own
/// decoration so the placeholder doesn't "pop" flat when real posts swap in.
BoxDecoration _cardDecoration(BuildContext context) {
  final colors = AppColors.of(context);
  return BoxDecoration(
    color: colors.surf,
    borderRadius: BorderRadius.circular(AppRadii.xxl),
    border: Border.all(color: colors.line, width: 1.5),
    boxShadow: AppShadows.card(context),
  );
}
