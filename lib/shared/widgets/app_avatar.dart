import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// The six background/foreground pairs the design cycles avatars through
/// (`AV` in the `.dc.html` source's component script). Literal design
/// colors, not theme tokens — the mockup uses the same six pairs in both
/// light and dark mode.
const List<(Color bg, Color fg)> kAvatarPalette = [
  (Color(0xFF14120C), Color(0xFFF4C542)),
  (Color(0xFFF4C542), Color(0xFF14120C)),
  (Color(0xFFE4574F), Color(0xFFFFFFFF)),
  (Color(0xFF2E9E5B), Color(0xFFFFFFFF)),
  (Color(0xFF6B5200), Color(0xFFFFDF94)),
  (Color(0xFF211E16), Color(0xFFF7F5F0)),
];

(Color bg, Color fg) avatarColorsForSeed(int seed) => kAvatarPalette[seed % kAvatarPalette.length];

/// Deterministic palette index for a real backend id/username: the backend
/// has no "avatar color" concept, so real users get a stable pseudo-random
/// seed derived from their id instead of a design-authored one (used by the
/// mockup's own hardcoded demo people).
int avatarSeedForId(String id) => id.hashCode.abs() % kAvatarPalette.length;

/// Circular initials avatar matching the mockup's avatar chip: solid ink
/// border, palette fill, optional online dot, optional story ring.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.initials,
    required this.seed,
    this.size = 44,
    this.showOnlineDot = false,
    this.ringColor,
    this.borderWidth = 1.5,
    this.imageUrl,
  });

  final String initials;
  final int seed;
  final double size;
  final bool showOnlineDot;

  /// A real uploaded avatar (`AuthorSummary.avatarUrl` /
  /// `UserResponse.avatarUrl`). Null/empty falls back to the initials tile —
  /// the only kind of avatar the mockup's demo people ever have.
  final String? imageUrl;

  /// Story-ring color (e.g. `AppColors.yel` for unseen, `line` for seen).
  /// Null renders no ring at all — the plain bordered-circle style used by
  /// post authors / conversation rows.
  final Color? ringColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (bg, fg) = avatarColorsForSeed(seed);

    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    Widget circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: colors.ink, width: borderWidth),
        image: hasImage
            ? DecorationImage(
                image: ResizeImage(
                  CachedNetworkImageProvider(imageUrl!),
                  width: (size * MediaQuery.devicePixelRatioOf(context)).round(),
                ),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasImage
          ? null
          : Text(
              initials,
              style: AppTextStyles.titleSm.copyWith(color: fg, fontSize: size * 0.30),
            ),
    );

    if (ringColor != null) {
      circle = Container(
        width: size + 6,
        height: size + 6,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ringColor!, width: 2),
        ),
        child: circle,
      );
    }

    if (!showOnlineDot) return circle;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        circle,
        Positioned(
          right: ringColor != null ? 1 : -1,
          bottom: ringColor != null ? 1 : -1,
          child: Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.grn,
              border: Border.all(color: colors.surf, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
