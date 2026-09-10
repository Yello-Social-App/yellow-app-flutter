import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../features/chat/presentation/bloc/messages_cubit.dart';
import '../../../../features/feed/presentation/bloc/feed_cubit.dart';
import '../../../../features/notification/presentation/bloc/notifications_cubit.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';

/// The bottom nav: Feed, Signals, a raised "+" create button, Inbox, then
/// Profile — five equal-width slots, with a short yellow accent line sitting
/// on the pill's bottom edge under whichever tab is selected, topped with a
/// small arrowhead that pops up toward that tab's icon (restyled to our own
/// item set, unread-dot wiring and ink/yellow/red color theme; an earlier
/// version had this accent border curl up and arc over the top of the pill
/// instead — replaced since it read as too heavy over the nav bar).
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
/// `currentIndex` is a router *branch* index (Feed 0, Inbox 2, Signals 3,
/// Profile 4 — Circle's branch 1 is skipped), which doesn't match this bar's
/// left-to-right slot order, so [_slotForBranch] maps branch -> visual slot
/// so the indicator lands under the right tab.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key, required this.currentIndex, required this.onTabSelected, required this.onCreate});

  final int currentIndex;
  final void Function(int branchIndex) onTabSelected;
  final VoidCallback onCreate;

  static const _yel = Color(0xFFF4C542);
  static const _ink = Color(0xFF14120C);
  static const _red = Color(0xFFE4574F);

  static const _barHeight = 58.0;
  static const _slotCount = 5;
  // Visual left-to-right order is Feed, Signals, Create, Inbox, Profile.
  static const _slotForBranch = {0: 0, 3: 1, 2: 3, 4: 4};

  @override
  Widget build(BuildContext context) {
    final selectedSlot = _slotForBranch[currentIndex] ?? 0;
    // The pill's own 20px margin from the physical bottom edge was tuned
    // against a 3-button-nav device, where the system reports zero bottom
    // inset. On a gesture-nav device (most modern phones) that inset is
    // nonzero (Android's gesture pill, iOS's home indicator) — added on top
    // of the 20 rather than replacing it, so the pill still clears the
    // gesture area instead of sitting under/behind it, while staying
    // pixel-identical to before on any device that reports zero inset.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 20 + bottomInset),
      child: SizedBox(
        // +14 gives the pill a 7px margin top and bottom within this box, so
        // its shadow has room to render without being clipped.
        height: _barHeight + 14,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotWidth = constraints.maxWidth / _slotCount;
            final selectedCenter = slotWidth * (selectedSlot + 0.5);

            return TweenAnimationBuilder<double>(
              tween: Tween<double>(end: selectedCenter),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, animatedCenter, _) => Stack(
                // Left off `Clip.none` (the Stack default is `Clip.hardEdge`)
                // so the pill's shadow and the indicator's glow can bleed
                // past this Stack's own bounds instead of being cropped.
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    top: 7,
                    bottom: 7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _ink,
                        borderRadius: BorderRadius.circular(_barHeight / 2),
                        border: Border.all(color: _yel.withValues(alpha: 0.45), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 32,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ActiveTabIndicatorPainter(
                          selectedCenter: animatedCenter,
                          slotWidth: slotWidth,
                          barHeight: _barHeight,
                          color: _yel,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    top: 7,
                    bottom: 7,
                    child: Row(
                      children: [
                        SizedBox(
                          width: slotWidth,
                          child: _NavItem(
                            icon: Icons.grid_view_rounded,
                            label: 'Feed',
                            active: currentIndex == 0,
                            onTap: () => onTabSelected(0),
                          ),
                        ),
                        SizedBox(
                          width: slotWidth,
                          child: BlocBuilder<NotificationsCubit, NotificationsState>(
                            bloc: sl<NotificationsCubit>(),
                            builder: (context, state) => _NavItem(
                              icon: Icons.favorite_border,
                              label: 'Signals',
                              active: currentIndex == 3,
                              dot: state.unreadCount > 0,
                              onTap: () => onTabSelected(3),
                            ),
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
                                shape: const CircleBorder(side: BorderSide(color: _ink, width: 1.8)),
                                child: InkWell(
                                  onTap: onCreate,
                                  customBorder: const CircleBorder(),
                                  child: const SizedBox(
                                    width: 42,
                                    height: 42,
                                    child: Icon(Icons.add, color: _ink, size: 22),
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
                              icon: Icons.chat_bubble_outline,
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
                                  initials: me == null ? '' : (me.fullName ?? me.username).initials,
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
  }) : assert(icon != null || iconWidget != null, 'Provide either icon or iconWidget');

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
    final fg = active ? BottomNavBar._yel : Colors.white.withValues(alpha: 0.66);

    return Semantics(
      selected: active,
      label: label,
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
                              color: BottomNavBar._red,
                              border: Border.all(color: const Color(0xFF100E09), width: 1),
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
                child: Text(label, softWrap: false, maxLines: 1, style: AppTextStyles.navLabel.copyWith(color: fg)),
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
  const _ProfileAvatarIcon({required this.active, required this.initials, required this.seed, this.imageUrl});

  final bool active;
  final String initials;
  final int seed;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: active ? BottomNavBar._yel : Colors.white.withValues(alpha: 0.35), width: 1.6),
      ),
      child: AppAvatar(initials: initials, seed: seed, imageUrl: imageUrl, size: 18, borderWidth: 1),
    );
  }
}

/// Paints the active-tab indicator: a short accent line sitting on the
/// pill's bottom edge under the selected slot, topped with a small
/// arrowhead that pops up from the line toward that tab's icon.
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
    final barTop = (size.height - barHeight) / 2;
    // Same bottom-edge coordinate the dim full-border underneath sits on,
    // so this accent line reads as a highlighted segment of it.
    final bottomY = barTop + barHeight - outerInset;

    final lineHalfWidth = slotWidth * .2;
    final lineStart = Offset(selectedCenter - lineHalfWidth, bottomY);
    final lineEnd = Offset(selectedCenter + lineHalfWidth, bottomY);

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

    // Small arrowhead sitting on the line, tip pointing up toward the icon
    // — base overlaps the line slightly so it reads as popping up out of it.
    const arrowHalfWidth = 5.0;
    const arrowHeight = 6.0;
    final arrowBaseY = bottomY - 1;
    final arrowTipY = arrowBaseY - arrowHeight;
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
