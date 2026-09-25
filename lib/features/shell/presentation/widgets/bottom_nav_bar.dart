import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../features/chat/presentation/bloc/messages_cubit.dart';
import '../../../../features/feed/presentation/bloc/feed_cubit.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';

/// The bottom nav: Feed, Explore, a raised "+" create button, Inbox, then
/// Profile — five equal-width slots, with a short yellow accent line sitting
/// on the bar's top edge above whichever tab is selected, topped with a
/// small arrowhead that pops down toward that tab's icon (restyled to our
/// own item set, unread-dot wiring and ink/yellow/red color theme).
///
/// Laid out as a flat, full-width bar flush with the screen edges — no side
/// margins, no rounded corners, no drop shadow — matching the plain strip
/// look of e.g. Facebook's bottom nav, rather than the floating rounded pill
/// this used to be. Colors come from the [AppColors] theme extension rather
/// than hard-coded constants, so the bar follows the app's light/dark toggle
/// instead of staying white-on-ink in dark mode: the background is `surf`,
/// the top hairline `line2`, inactive icons/labels + the Profile avatar's
/// dim ring `ink3`, the unread dot `red` ringed in `surf`, and the active
/// tint + accent-line indicator `yel`.
///
/// Circle (branch index 1, the friends screen) is intentionally not shown
/// here — its route/branch still exists in the router for later use, it's
/// just not reachable from this bar right now. **Don't confuse that with the
/// Profile tab below** — it has nothing to do with the Circle/friends branch
/// despite the icon-naming history (see `AssetConstants.circleIcon`'s doc
/// comment for that trail).
///
/// **The Profile tab shows the signed-in user's real avatar**, not a fixed
/// glyph or brand mark — it reads `FeedCubit.state.me` (the same long-lived
/// singleton the Feed header/composer already use for this, see
/// `FeedState.me`'s doc comment) via a `BlocBuilder`, rendering `AppAvatar`
/// with a circular border that glows yellow while this tab is active and
/// sits dim otherwise, matching the other tabs' icon-turns-yellow treatment.
///
/// **Slot 2 is Explore, branch 5.** Signals used to sit there; it traded
/// places with the feed app bar's Explore button, so Signals is now reached
/// from that app bar (`goBranch(3)`). Explore is a real tab like the others:
/// its branch holds both Communities (the landing screen) and Showcase, and
/// the title menu on those screens (`ExploreTitleMenu`) swaps between them
/// inside the branch, so the slot stays lit for either. It went through two
/// earlier shapes — a two-row sheet, then a bare push of Communities over
/// the shell — both of which left the bar behind or the slot never active.
/// The Signals unread dot no longer lives in this bar either; the app bar's
/// own Signals button carries it.
///
/// `currentIndex` is a router *branch* index (Feed 0, Inbox 2, Profile 4,
/// Explore 5 — Circle's branch 1 and Signals' branch 3 have no slot here),
/// which doesn't match this bar's left-to-right slot order, so
/// [_slotForBranch] maps branch -> visual slot so the indicator lands under
/// the right tab.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onCreate,
  });

  final int currentIndex;
  final void Function(int branchIndex) onTabSelected;
  final VoidCallback onCreate;

  /// The brand yellow and the cream glyph sitting on it are deliberately
  /// theme-independent — the raised "+" button is a brand mark and reads the
  /// same on either background. Every other color in this bar now comes from
  /// [AppColors] so the bar follows the light/dark token set.
  static const _yel = Color(0xFFF4C542);
  static const _onYelGlyph = Color(0xFFEDE9DF);

  static const _barHeight = 62.0;
  static const _slotCount = 5;
  // Visual left-to-right order is Feed, Explore, Create, Inbox, Profile.
  // Create (slot 2) is a button, not a branch, so nothing maps onto it.
  static const _slotForBranch = {0: 0, 5: 1, 2: 3, 4: 4};

  @override
  Widget build(BuildContext context) {
    final selectedSlot = _slotForBranch[currentIndex] ?? 0;
    // Absorbed as extra ink-colored height below the icon row (rather than
    // as outer margin, like the old floating pill used) so the bar's flat
    // background still runs edge-to-edge down to the physical bottom of the
    // screen on a gesture-nav device (Android's gesture pill, iOS's home
    // indicator), matching a normal full-bleed nav bar instead of leaving a
    // gap of page background showing underneath it.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surf,
        // A neutral hairline rather than the old yellow tint — the same
        // divider token the app's surfaces already use elsewhere, since a
        // pale yellow line barely shows up against either background.
        border: Border(top: BorderSide(color: c.line2)),
        // Floats the bar above the page content now that the page
        // background is flat and near-tonal with the bar (see
        // `AppColors.light.bg` / `AppColors.dark.bg`) — a
        // negative `dy` casts the shadow upward, onto the content behind the
        // bar, matching a normal bottom-nav elevation cue. This is a plain
        // `DecoratedBox` built once per `BottomNavBar` rebuild — not an
        // `AnimatedContainer` and not rebuilt per animation frame (the
        // `TweenAnimationBuilder`/`CustomPainter` driving the tab indicator
        // live inside this decoration's `child`, not on it) — so it doesn't
        // hit the Impeller/Android blurred-`BoxShadow`-in-`AnimatedContainer`
        // crash this app hit elsewhere (see `_ProfileAvatarIcon`'s doc
        // comment). Still unverified on-device since there's no emulator in
        // this sandbox.
        boxShadow: [
          BoxShadow(
            // Always a black scrim, never the ink token — `ink` is near-white
            // in dark mode, which would turn this into a glow.
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        height: _barHeight + bottomInset,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotWidth = constraints.maxWidth / _slotCount;
            final selectedCenter = slotWidth * (selectedSlot + 0.5);

            return TweenAnimationBuilder<double>(
              tween: Tween<double>(end: selectedCenter),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, animatedCenter, _) => Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: _barHeight,
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ActiveTabIndicatorPainter(
                          selectedCenter: animatedCenter,
                          slotWidth: slotWidth,
                          barHeight: _barHeight,
                          color: c.yel,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: _barHeight,
                    child: Row(
                      children: [
                        SizedBox(
                          width: slotWidth,
                          child: _NavItem(
                            icon: CupertinoIcons.square_grid_2x2,
                            label: 'Feed',
                            active: currentIndex == 0,
                            onTap: () => onTabSelected(0),
                          ),
                        ),
                        SizedBox(
                          width: slotWidth,
                          child: _NavItem(
                            icon: CupertinoIcons.squares_below_rectangle,
                            label: 'Explore',
                            active: currentIndex == 5,
                            onTap: () => onTabSelected(5),
                          ),
                        ),
                        SizedBox(
                          width: slotWidth,
                          child: Center(
                            child: Semantics(
                              label: 'Create post',
                              button: true,
                              child: Material(
                                color: _yel,
                                shape: const CircleBorder(
                                  side: BorderSide(
                                    color: Color.fromARGB(157, 155, 152, 146),
                                    width: 1.8,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: onCreate,
                                  customBorder: const CircleBorder(),
                                  child: const SizedBox(
                                    width: 45,
                                    height: 45,
                                    child: Icon(
                                      CupertinoIcons.add,
                                      color: _onYelGlyph,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: slotWidth,
                          child: BlocBuilder<MessagesCubit, MessagesState>(
                            bloc: sl<MessagesCubit>(),
                            builder: (context, state) => _NavItem(
                              icon: CupertinoIcons.bubble_left,
                              label: 'Inbox',
                              active: currentIndex == 2,
                              dot: state.unreadTotal > 0,
                              onTap: () => onTabSelected(2),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: slotWidth,
                          child: BlocBuilder<FeedCubit, FeedState>(
                            bloc: sl<FeedCubit>(),
                            builder: (context, state) {
                              final me = state.me;
                              return _NavItem(
                                iconWidget: _ProfileAvatarIcon(
                                  active: currentIndex == 4,
                                  imageUrl: me?.avatarUrl,
                                  initials: me == null
                                      ? ''
                                      : (me.fullName ?? me.username).initials,
                                  seed: me == null ? 0 : avatarSeedForId(me.id),
                                ),
                                label: 'Profile',
                                active: currentIndex == 4,
                                onTap: () => onTabSelected(4),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.active,
    required this.onTap,
    this.dot = false,
  }) : assert(
         icon != null || iconWidget != null,
         'Provide either icon or iconWidget',
       );

  /// A Material glyph — mutually exclusive with [iconWidget]; tinted to [fg]
  /// like every other tab.
  final IconData? icon;

  /// A fully custom icon (e.g. [_ProfileAvatarIcon]) shown instead of a
  /// tinted glyph — used when a tab needs something [icon] can't express,
  /// like a real photo avatar. Owns its own active-state styling.
  final Widget? iconWidget;

  final String label;
  final bool active;
  final bool dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The tertiary-ink token: dark-on-light in light mode, light-on-dark in
    // dark mode, so inactive tabs stay legible either way.
    final c = AppColors.of(context);
    final fg = active ? c.yel : c.ink3;

    return Semantics(
      selected: active,
      label: label,
      value: dot ? 'Unread notifications' : null,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: Padding(
          padding: const EdgeInsets.only(top: 9, bottom: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSlide(
                offset: active ? const Offset(0, -0.12) : Offset.zero,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                child: AnimatedScale(
                  scale: active ? 1.14 : 1,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      iconWidget ?? Icon(icon, size: 18, color: fg),
                      if (dot)
                        Positioned(
                          top: -3,
                          right: -6,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.red,
                              // Matches the bar's own background so the dot
                              // still reads as cut into it rather than
                              // pasted on top.
                              border: Border.all(color: c.surf, width: 1),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Wrapped in a FittedBox (rather than just relying on the
              // Column's incoming width) so a tight tab slice on small
              // screens shrinks the label to fit instead of wrapping it onto
              // a 2nd line — labels like "Signals"/"Profile" must always
              // render on one line.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  softWrap: false,
                  maxLines: 1,
                  style: AppTextStyles.navLabel.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Profile tab's icon: the signed-in user's real avatar (photo or
/// initials tile, via [AppAvatar]) inside a circular border that glows
/// yellow while [active] — the same "shine" the tab bar's other icons get
/// from turning yellow, translated to a photo that can't be tinted the way
/// an [Icon] is.
///
/// **Deliberately no `boxShadow`/blur here** (an earlier version glowed via
/// a blurred `BoxShadow` on this ring) — on-device this crashed the app: a
/// signal-3 thread dump + tombstone right after switching into this tab,
/// the signature of a native/GPU-level fault rather than a Dart exception.
/// This project's Flutter (3.41.8) defaults to the Impeller renderer on
/// Android, which has known instability rendering blurred shadows inside a
/// frequently-rebuilt `AnimatedContainer` on some GPU drivers. The border's
/// own color flip (dim -> saturated yellow) is what actually carries
/// "shine" now, matching every other tab in this bar — none of which use a
/// blur either. Don't reintroduce a `BoxShadow` blur on this widget without
/// verifying on the exact device that crashed.
class _ProfileAvatarIcon extends StatelessWidget {
  const _ProfileAvatarIcon({
    required this.active,
    required this.initials,
    required this.seed,
    this.imageUrl,
  });

  final bool active;
  final String initials;
  final int seed;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Same theme-driven tint as _NavItem's inactive icons above.
        border: Border.all(color: active ? c.yel : c.ink3, width: 1.6),
      ),
      child: AppAvatar(
        initials: initials,
        seed: seed,
        imageUrl: imageUrl,
        size: 18,
        borderWidth: 1,
      ),
    );
  }
}

/// Paints the active-tab indicator: a short accent line sitting on the
/// bar's top edge above the selected slot, topped with a small arrowhead
/// that pops down from the line toward that tab's icon.
class _ActiveTabIndicatorPainter extends CustomPainter {
  const _ActiveTabIndicatorPainter({
    required this.selectedCenter,
    required this.slotWidth,
    required this.barHeight,
    required this.color,
  });

  final double selectedCenter;
  final double slotWidth;
  final double barHeight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const outerInset = 2.0;
    // `size.height` is normally just `barHeight` (the CustomPaint is sized
    // to exactly the icon row's Positioned box, not the bar's full height
    // with its safe-area filler below) — `barTop` stays here so this still
    // centers correctly if that ever changes.
    final barTop = (size.height - barHeight) / 2;
    final topY = barTop + outerInset;

    final lineHalfWidth = slotWidth * .2;
    final lineStart = Offset(selectedCenter - lineHalfWidth, topY);
    final lineEnd = Offset(selectedCenter + lineHalfWidth, topY);

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

    // Small arrowhead sitting on the line, tip pointing down toward the icon
    // — base overlaps the line slightly so it reads as popping down out of
    // it.
    const arrowHalfWidth = 5.0;
    const arrowHeight = 6.0;
    final arrowBaseY = topY + 1;
    final arrowTipY = arrowBaseY + arrowHeight;
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
  bool shouldRepaint(covariant _ActiveTabIndicatorPainter oldDelegate) {
    return oldDelegate.selectedCenter != selectedCenter ||
        oldDelegate.slotWidth != slotWidth ||
        oldDelegate.barHeight != barHeight ||
        oldDelegate.color != color;
  }
}
