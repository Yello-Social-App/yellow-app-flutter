import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// One loop of the sheen: it crosses the screen in the first
/// [_sweepFraction] of the period, then the bones rest for the remainder so
/// the effect reads as a calm pulse rather than a conveyor belt.
const Duration _shimmerPeriod = Duration(milliseconds: 1700);
const double _sweepFraction = 0.72;

/// Half the band's width, measured along the sweep direction, in logical px.
const double _bandHalfWidth = 110;

/// How far the band leans off vertical. Every bone reads the band in screen
/// space, so the lean continues across neighbouring bones as one diagonal.
const double _bandAngle = 18 * math.pi / 180;

/// Shared by every bone so they all sit at the same point of the loop, no
/// matter when each one was built. Started lazily on first use.
final Stopwatch _shimmerClock = Stopwatch()..start();

double get _shimmerPhase =>
    (_shimmerClock.elapsedMicroseconds % _shimmerPeriod.inMicroseconds) / _shimmerPeriod.inMicroseconds;

/// A single placeholder "bone" — the one primitive every loading skeleton in
/// the app is built from.
///
/// The fill is a soft wash of `ink` at low opacity rather than a fixed
/// palette token, so it reads on every surface in all four palettes (the old
/// `surf2`→`line` gradient was invisible on white cards and ran *darker* at
/// its highlight). A lighter diagonal sheen sweeps across it on a shared
/// clock, positioned in screen space: every bone on screen is lit by the
/// same band at the same moment, so a whole skeleton shimmers as one surface
/// instead of each block flashing on its own timer.
///
/// Each bone owns a [Ticker] (so it pauses under `TickerMode`, e.g. on an
/// inactive shell branch) that only marks it for repaint — no rebuilds. With
/// "reduce motion" on, the bone is drawn flat and never ticks.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({super.key, this.width, this.height = 16, this.borderRadius = AppRadii.xs, this.corners});

  final double? width;
  final double height;
  final double borderRadius;

  /// Per-corner radii, for a bone that stands in for a non-uniform shape
  /// (a chat bubble's tail). Overrides [borderRadius] when set.
  final BorderRadius? corners;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  bool _wasSweeping = false;

  /// Repaints only while the band is moving, plus one frame after it leaves
  /// so the bone settles back to its flat fill; the resting tail is free.
  void _onTick(Duration _) {
    final sweeping = _shimmerPhase <= _sweepFraction;
    if (sweeping || _wasSweeping) _frame.value++;
    _wasSweeping = sweeping;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (animate && !_ticker.isActive) {
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: _ShimmerBone(
        repaint: _frame,
        baseColor: colors.ink.withValues(alpha: isDark ? 0.08 : 0.065),
        highlightColor: colors.ink.withValues(alpha: isDark ? 0.15 : 0.02),
        borderRadius: widget.borderRadius,
        corners: widget.corners,
        viewport: MediaQuery.sizeOf(context),
        animate: !MediaQuery.disableAnimationsOf(context),
      ),
    );
  }
}

class _ShimmerBone extends LeafRenderObjectWidget {
  const _ShimmerBone({
    required this.repaint,
    required this.baseColor,
    required this.highlightColor,
    required this.borderRadius,
    required this.corners,
    required this.viewport,
    required this.animate,
  });

  final Listenable repaint;
  final Color baseColor;
  final Color highlightColor;
  final double borderRadius;
  final BorderRadius? corners;
  final Size viewport;
  final bool animate;

  @override
  _RenderShimmerBone createRenderObject(BuildContext context) => _RenderShimmerBone(
    repaint: repaint,
    baseColor: baseColor,
    highlightColor: highlightColor,
    borderRadius: borderRadius,
    corners: corners,
    viewport: viewport,
    animate: animate,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderShimmerBone renderObject) {
    renderObject
      ..repaint = repaint
      ..baseColor = baseColor
      ..highlightColor = highlightColor
      ..borderRadius = borderRadius
      ..corners = corners
      ..viewport = viewport
      ..animate = animate;
  }
}

class _RenderShimmerBone extends RenderBox {
  _RenderShimmerBone({
    required Listenable repaint,
    required Color baseColor,
    required Color highlightColor,
    required double borderRadius,
    required BorderRadius? corners,
    required Size viewport,
    required bool animate,
  }) : _repaint = repaint,
       _baseColor = baseColor,
       _highlightColor = highlightColor,
       _borderRadius = borderRadius,
       _corners = corners,
       _viewport = viewport,
       _animate = animate;

  Listenable _repaint;
  set repaint(Listenable value) {
    if (identical(value, _repaint)) return;
    if (attached) _repaint.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint.addListener(markNeedsPaint);
  }

  Color _baseColor;
  set baseColor(Color value) {
    if (value == _baseColor) return;
    _baseColor = value;
    markNeedsPaint();
  }

  Color _highlightColor;
  set highlightColor(Color value) {
    if (value == _highlightColor) return;
    _highlightColor = value;
    markNeedsPaint();
  }

  double _borderRadius;
  set borderRadius(double value) {
    if (value == _borderRadius) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  BorderRadius? _corners;
  set corners(BorderRadius? value) {
    if (value == _corners) return;
    _corners = value;
    markNeedsPaint();
  }

  Size _viewport;
  set viewport(Size value) {
    if (value == _viewport) return;
    _viewport = value;
    markNeedsPaint();
  }

  bool _animate;
  set animate(bool value) {
    if (value == _animate) return;
    _animate = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  /// Fills a bounded axis and collapses an unbounded one, the same way the
  /// childless `Container` this replaces did.
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(
    Size(
      constraints.hasBoundedWidth ? constraints.maxWidth : 0,
      constraints.hasBoundedHeight ? constraints.maxHeight : 0,
    ),
  );

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final rect = offset & size;
    final rrect =
        _corners?.toRRect(rect) ?? RRect.fromRectAndRadius(rect, Radius.circular(math.min(_borderRadius, size.shortestSide / 2)));
    final paint = Paint()..color = _baseColor;

    final sweep = _phase();
    if (_animate && sweep != null) {
      // Where the band's centre line crosses the vertical middle of the
      // screen, in global coordinates, then mapped into this bone's space.
      final direction = Offset(math.cos(_bandAngle), math.sin(_bandAngle));
      final lean = _viewport.height / 2 * math.tan(_bandAngle);
      final travelStart = -_bandHalfWidth - lean;
      final travelEnd = _viewport.width + _bandHalfWidth + lean;
      final centreGlobal = Offset(ui.lerpDouble(travelStart, travelEnd, sweep)!, _viewport.height / 2);
      final origin = localToGlobal(Offset.zero);
      final centre = centreGlobal - origin + offset;
      paint.shader = ui.Gradient.linear(
        centre - direction * _bandHalfWidth,
        centre + direction * _bandHalfWidth,
        [_baseColor, _highlightColor, _baseColor],
        const [0, 0.5, 1],
      );
    }
    context.canvas.drawRRect(rrect, paint);
  }

  /// Eased 0→1 progress of the band across the screen, or `null` while the
  /// loop is in its resting tail.
  static double? _phase() {
    final t = _shimmerPhase;
    if (t > _sweepFraction) return null;
    return Curves.easeInOutSine.transform(t / _sweepFraction);
  }
}

/// A generic list-row skeleton — an avatar, two text lines and a block —
/// inside a card with the app's standard surface/border/shadow treatment.
/// Only [PagedListView]'s fallback when a caller passes no `skeleton:` —
/// every screen now has a skeleton shaped like its own rows (ADR-013), so
/// don't reach for this one on a new screen.
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
                  children: [ShimmerBox(width: 120, height: 12), SizedBox(height: 8), ShimmerBox(width: 80, height: 9)],
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

  /// Mirrors [PostCard]'s two body shapes: `true` draws the full-bleed photo
  /// block (header and caption sit on the photo), `false` the header and
  /// three-line text-only body. The feed
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
          // PostCard's _PhotoBody: the photo runs edge to edge across the
          // card's top, header and caption laid over it, so the skeleton is
          // one full-bleed block. 320 sits inside the photo's 240..(1.25 ×
          // width) height bounds for a typical phone photo.
          if (hasImage)
            const ShimmerBox(height: 320, borderRadius: 0)
          else
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
                  Padding(padding: EdgeInsets.all(8), child: ShimmerBox(width: 20, height: 20, borderRadius: 10)),
                ],
              ),
            ),
          if (!hasImage) const ShimmerTextLines(lineWidthFactors: [1, 1, 0.56]),
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

/// Stand-in for a block of body copy: one bar per rendered line.
///
/// The defaults match a post's body — 15px bars 7px apart, so N lines take
/// the room of N lines of `AppTextStyles.body` (15/1.5 = 22.5 each), inside
/// _TextBody's `fromLTRB(14, 0, 14, 12)` padding. For smaller copy pass the
/// style's font size as [lineHeight] and (line height − font size) as
/// [gap]. Widths are fractions of the available width so the last (short)
/// line scales with the screen instead of being a fixed stub.
class ShimmerTextLines extends StatelessWidget {
  const ShimmerTextLines({
    super.key,
    required this.lineWidthFactors,
    this.lineHeight = 15,
    this.gap = 7,
    this.padding = const EdgeInsets.fromLTRB(14, 0, 14, 12),
  });

  final List<double> lineWidthFactors;
  final double lineHeight;
  final double gap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lineWidthFactors.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: lineWidthFactors[i],
              child: ShimmerBox(height: lineHeight, borderRadius: AppRadii.pill),
            ),
          ],
        ],
      ),
    );
  }
}

/// A person/row skeleton: a round avatar, a title bar and an optional
/// subtitle bar, with an optional trailing bone — the shape shared by the
/// inbox, Circle, reactor, viewer and member lists.
///
/// Every row type is laid out differently, so this takes its geometry from
/// the call site rather than guessing: pass the real row's padding, avatar
/// size, avatar→text gap, and each text line's rendered height. The bars sit
/// in an `Expanded` column, so their fixed widths clamp on a narrow phone
/// instead of overflowing; [trailing] is laid out at its own size.
class ShimmerListTile extends StatelessWidget {
  const ShimmerListTile({
    super.key,
    this.padding = EdgeInsets.zero,
    this.leading,
    this.leadingGap = 14,
    this.avatarSize = 40,
    this.gap = 12,
    this.titleWidth = 132,
    this.titleHeight = 14,
    this.subtitleWidth,
    this.subtitleHeight = 11,
    this.lineGap = 7,
    this.trailing,
    this.trailingGap = 10,
  });

  final EdgeInsetsGeometry padding;

  /// Anything drawn before the avatar (a pick row's checkbox).
  final Widget? leading;
  final double leadingGap;
  final double avatarSize;
  final double gap;
  final double titleWidth;
  final double titleHeight;

  /// `null` draws a single-line row.
  final double? subtitleWidth;
  final double subtitleHeight;
  final double lineGap;
  final Widget? trailing;
  final double trailingGap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, SizedBox(width: leadingGap)],
          ShimmerBox(width: avatarSize, height: avatarSize, borderRadius: avatarSize / 2),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: titleWidth, height: titleHeight, borderRadius: AppRadii.pill),
                if (subtitleWidth != null) ...[
                  SizedBox(height: lineGap),
                  ShimmerBox(width: subtitleWidth, height: subtitleHeight, borderRadius: AppRadii.pill),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[SizedBox(width: trailingGap), trailing!],
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
