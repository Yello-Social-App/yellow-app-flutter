import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Stand-in for the design's `<image-slot>` component. There's no media
/// pipeline yet (no upload/CDN backend), so every photo surface in the app
/// — post photos, story frames, cover images — renders this rather than a
/// broken network image. Swap for a real `Image.network` /
/// `CachedNetworkImage` once post media has somewhere to live.
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({
    super.key,
    this.caption = 'Drop an image',
    this.borderRadius = 0,
    this.dark = false,
  });

  final String caption;
  final double borderRadius;

  /// Story frames sit on a near-black background instead of the light
  /// `slot` fill — set true there.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fg = dark ? Colors.white.withValues(alpha: 0.55) : colors.ink2;
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0B0A07) : colors.slot,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, color: fg, size: 26),
          const SizedBox(height: 6),
          Text(caption, style: AppTextStyles.bodySm.copyWith(color: fg), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
