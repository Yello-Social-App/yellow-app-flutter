import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Decorative header for the auth screens — stands in for the illustrated
/// artwork on the reference design (a person + phone scene), but drawn
/// entirely from shapes/icons in our own palette instead of a baked-in
/// image, so it stays correct in both light and dark theme with no extra
/// asset to ship or swap. [icon] is the glyph inside the central "device"
/// card (verification-style for login, add-person for register); [badgeA]
/// / [badgeB] are the two small floating accent bubbles.
class AuthHero extends StatelessWidget {
  const AuthHero({
    super.key,
    required this.icon,
    this.badgeA = CupertinoIcons.mail,
    this.badgeB = CupertinoIcons.sparkles,
    this.leading,
    this.filled = true,
  });

  final IconData icon;
  final IconData badgeA;
  final IconData badgeB;

  /// Optional widget pinned to the top-left (the screen's back button),
  /// floated over the illustration the way the reference floats its own
  /// chrome over the artwork.
  final Widget? leading;

  /// `true` (login/default): solid yellow disc behind [icon]. `false`
  /// (register/OTP): an outlined ring instead — same accent color, but a
  /// different-enough silhouette that Login and Register read as distinct
  /// screens at a glance even before the heading text registers.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: Container(
        height: 232,
        color: colors.yelb,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -40,
              top: -50,
              child: _Blob(
                size: 160,
                color: colors.yel.withValues(alpha: 0.35),
              ),
            ),
            Positioned(
              right: -30,
              bottom: -60,
              child: _Blob(
                size: 180,
                color: colors.ink.withValues(alpha: 0.05),
              ),
            ),
            Center(
              child: Container(
                width: 128,
                height: 168,
                decoration: BoxDecoration(
                  color: colors.surf,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: colors.line, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: filled ? colors.yel : colors.surf,
                    shape: BoxShape.circle,
                    border: filled
                        ? null
                        : Border.all(color: colors.yel, width: 2.5),
                  ),
                  child: Icon(
                    icon,
                    size: 30,
                    color: filled ? colors.onYel : colors.yel,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 44,
              top: 46,
              child: _Badge(icon: badgeA, colors: colors),
            ),
            Positioned(
              right: 40,
              bottom: 34,
              child: _Badge(icon: badgeB, colors: colors),
            ),
            if (leading != null) Positioned(top: 14, left: 14, child: leading!),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.colors});
  final IconData icon;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surf,
        shape: BoxShape.circle,
        border: Border.all(color: colors.line, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 17, color: colors.yeld),
    );
  }
}
