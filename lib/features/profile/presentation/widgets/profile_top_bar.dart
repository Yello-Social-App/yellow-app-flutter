import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_avatar.dart';
import 'profile_header.dart';

/// Whose profile the collapsed [ProfileTopBar] names.
class ProfileBarIdentity {
  const ProfileBarIdentity({required this.id, required this.displayName, required this.username, this.avatarUrl});

  final String id;
  final String displayName;
  final String username;
  final String? avatarUrl;
}

/// A profile screen's floating chrome, and the app bar it turns into — shared
/// by the Profile tab and someone else's profile, which lay their headers out
/// identically ([ProfileHeader] / [PublicProfileHeader]).
///
/// Below [collapseStart] this is transparent buttons over the cover photo.
/// Across the stretch of scroll where the header's own name is sliding up
/// behind it, a background, a hairline and an identity — avatar and name,
/// entering from the left — fade in together, so the screen keeps saying
/// whose profile this is once the header has gone. The buttons themselves
/// never move.
///
/// The collapsed state floats: a `surf` surface over the page's `bg` with a
/// soft shadow cast onto the list, the same elevation language `BottomNavBar`
/// already uses at the other end of the screen.
///
/// That shadow is painted by [_TopBarShadowPainter], **not** put in this
/// `BoxDecoration`. The decoration here changes on every scroll frame, and a
/// blurred `BoxShadow` on a per-frame decoration is the exact shape that
/// crashed this project's Impeller renderer on-device — whereas a
/// `MaskFilter.blur` inside a `CustomPainter` is the animated-blur pattern
/// `ActiveTabIndicatorPainter` has shipped safely all along
/// (`docs/GOTCHAS.md`).
class ProfileTopBar extends StatelessWidget {
  const ProfileTopBar({super.key, required this.offset, required this.actions, this.leading, this.identity});

  /// Current scroll offset, already clamped to [collapseEnd] by the page.
  final double offset;

  /// The trailing buttons, built once by the page.
  final Widget actions;

  /// A back button, on a pushed profile. The collapsed identity slides in
  /// from underneath it.
  final Widget? leading;

  /// Null while the page has no user loaded (shimmer, error) — the buttons
  /// then stand alone.
  final ProfileBarIdentity? identity;

  /// The scroll range the collapse plays over. It ends 40px before the
  /// header's own name line ([ProfileHeader.nameOffset]) would reach the top
  /// of the viewport — by then that line is behind this bar — and runs for
  /// the 72px before that, so the hand-off happens while the header's name is
  /// on its way out rather than after it has already gone.
  static const double collapseEnd = ProfileHeader.nameOffset - 40;
  static const double collapseStart = collapseEnd - 72;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final t = Curves.easeOut.transform(((offset - collapseStart) / (collapseEnd - collapseStart)).clamp(0.0, 1.0));

    Widget title = _CollapsedTitle(progress: t, identity: identity);
    // The slide-in starts 20px left of its resting place, which would draw
    // it across the back button; clipped, it emerges from the button's edge.
    if (leading != null) title = ClipRect(child: title);

    // `Clip.none` so the painter below can cast past the bar's own box —
    // the whole point of the shadow is the part that falls on the list.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Once the bar is opaque it has to swallow pointers too, or a tap
        // lands on whichever post card happens to be scrolled underneath it.
        // A `BoxDecoration` colour does not hit-test (only `ColoredBox`
        // does), so the barrier is explicit — and switched off entirely at
        // rest, leaving the transparent state as see-through to drags as it
        // was before.
        Positioned.fill(child: AbsorbPointer(absorbing: t > 0)),
        CustomPaint(
          painter: _TopBarShadowPainter(progress: t, isDark: Theme.of(context).brightness == Brightness.dark),
          // `DecoratedBox`, not `Container(color:)`: a `ColoredBox` is opaque
          // to hit-testing at every alpha including zero, which would have
          // the resting bar eating drags over the cover photo.
          child: DecoratedBox(
            decoration: BoxDecoration(color: colors.surf.withValues(alpha: t)),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Row(
                  children: [
                    if (leading != null) ...[leading!, const SizedBox(width: 10)],
                    Expanded(child: title),
                    actions,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The collapsed bar's drop shadow, painted rather than declared.
///
/// `MaskFilter.blur` on a `Paint` is the one animated-blur technique this
/// project trusts on Android — `ActiveTabIndicatorPainter` has driven one
/// from a running animation since the bottom bar shipped. A blurred
/// `BoxShadow` in a `BoxDecoration` that changes every frame is the shape
/// that crashed Impeller here, and this bar's decoration does change every
/// frame, so the shadow could not live there.
///
/// Values track `BottomNavBar`'s floating shadow (black at 0.08 light / 0.45
/// dark, 16px blur, 4px offset) so both ends of the screen lift by the same
/// amount, with `AppShadows.card`'s second contact layer added to anchor the
/// edge. Black rather than the `ink` token on purpose: `ink` is near-white in
/// dark mode and would paint a glow instead of a shadow.
class _TopBarShadowPainter extends CustomPainter {
  const _TopBarShadowPainter({required this.progress, required this.isDark});

  final double progress;
  final bool isDark;

  /// How far below the bar the shadow is allowed to reach.
  static const double _reach = 28;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    // Everything is clipped to the strip *below* the bar, so the blur's top
    // and side falloff never tints the bar itself — only the edge it casts
    // onto the list shows, at any point in the fade.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, size.height, size.width, size.height + _reach));

    void cast(double alpha, double blur, double dy) {
      canvas.drawRect(
        // Grown past the canvas on the top and sides so only the bottom
        // edge's falloff is ever in frame.
        Rect.fromLTRB(-blur, -blur, size.width + blur, size.height + dy),
        Paint()
          ..color = Colors.black.withValues(alpha: alpha * progress)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }

    cast(isDark ? 0.45 : 0.08, 16, 4);
    cast(isDark ? 0.30 : 0.05, 4, 1.5);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TopBarShadowPainter old) => old.progress != progress || old.isDark != isDark;
}

/// The app bar's identity: the avatar and the name, sliding in from the left
/// and fading up as [progress] runs 0 → 1.
///
/// `Transform.translate` is safe for that slide only because this is inert:
/// ADR-024's hit-test trap — a translated child cannot take a tap past its
/// own untransformed box — bites tappable overlaps, and this one is wrapped
/// in an `IgnorePointer` so it never takes a tap at all.
class _CollapsedTitle extends StatelessWidget {
  const _CollapsedTitle({required this.progress, required this.identity});

  final double progress;
  final ProfileBarIdentity? identity;

  static const double _avatarSize = 32;

  @override
  Widget build(BuildContext context) {
    final who = identity;
    if (progress == 0 || who == null) return const SizedBox.shrink();
    final colors = AppColors.of(context);

    return IgnorePointer(
      child: Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(-20 * (1 - progress), 0),
          child: Row(
            children: [
              AppAvatar(
                initials: Formatters.initialsFrom(who.displayName),
                seed: avatarSeedForId(who.id),
                imageUrl: who.avatarUrl,
                size: _avatarSize,
                borderWidth: 1.5,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      who.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleRow.copyWith(color: colors.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '@${who.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
