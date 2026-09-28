import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/sticker_entity.dart';

/// One sticker picture, at whatever size the caller asks for.
///
/// The two backgrounds are drawn differently because the bytes are different:
/// a `REMOVED` sticker is a cut-out with alpha and its white outline already
/// in the pixels, so it is drawn straight and `contain`; a `KEPT` one is a
/// square photo flattened onto white, and the **app** supplies the rounded
/// corners and the white frame the design shows around it.
///
/// Cached by the sticker's **id**, not its URL — the link is re-signed on
/// every read, and keying the cache on it would re-download every sticker in
/// the transcript on each history poll. The widget still carries a
/// `ValueKey(url)`, because `CachedNetworkImageProvider` compares equal on
/// `cacheKey` alone: without it a picture whose link had expired would sit in
/// its error state forever, the provider never looking different enough to
/// resolve again (`docs/GOTCHAS.md`).
///
/// No shadow under the frame, unlike the design: a blurred `BoxShadow` inside
/// a widget that rebuilds on Cubit state crashed this project's renderer
/// (`docs/GOTCHAS.md`), and the transcript rebuilds on every poll. The white
/// frame alone carries the lift.
class StickerImageView extends StatelessWidget {
  const StickerImageView({
    super.key,
    required this.sticker,
    required this.size,
    this.frameWidth = 3,
    this.radius = 14,
    this.onExpired,
  });

  final StickerEntity sticker;

  /// The side of the square the sticker is drawn in. A `KEPT` sticker fills
  /// it; a cut-out is fitted inside it, so its visible ink is smaller.
  final double size;

  /// The white frame around a `KEPT` sticker. Ignored for a cut-out.
  final double frameWidth;

  /// Corner rounding for a `KEPT` sticker. Ignored for a cut-out.
  final double radius;

  /// A presigned link 403'd: ask for a fresh copy. Null where there is
  /// nothing to ask (the picker, whose lists are re-read on open).
  final ValueChanged<String>? onExpired;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final url = sticker.image.url;
    final framed = sticker.needsFrame;
    final borderRadius = BorderRadius.circular(radius);

    final placeholder = framed
        ? DecoratedBox(
            decoration: BoxDecoration(color: colors.surf2, borderRadius: borderRadius),
            child: Center(child: Icon(CupertinoIcons.smiley, size: size * 0.4, color: colors.ink3)),
          )
        : Center(child: Icon(CupertinoIcons.smiley, size: size * 0.4, color: colors.ink3));

    Widget picture = url.isEmpty
        ? placeholder
        : CachedNetworkImage(
            key: ValueKey(url),
            imageUrl: url,
            cacheKey: sticker.id,
            // A cut-out must not be cropped — the whitespace around the
            // subject is part of the picture. A kept sticker is already
            // square, so `cover` only guards against a source that is not.
            fit: framed ? BoxFit.cover : BoxFit.contain,
            // The source is always 512 × 512; decoding it at display size is
            // the difference between ~1 MB and ~60 KB per sticker in memory,
            // and a transcript can hold a lot of them.
            memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) {
              final refresh = onExpired;
              // Deferred a frame so nothing emits from inside a build. Only
              // an expired link is worth retrying; a genuinely broken picture
              // keeps its placeholder, and the cubit's own per-id guard stops
              // a retry loop either way.
              if (refresh != null && sticker.image.isUrlExpired) {
                WidgetsBinding.instance.addPostFrameCallback((_) => refresh(sticker.id));
              }
              return placeholder;
            },
          );

    if (framed) {
      picture = Container(
        // The fill and the clip shape go in `decoration`; the white frame
        // goes in `foregroundDecoration`, or an edge-to-edge child paints
        // over it and it quietly vanishes (`docs/GOTCHAS.md`).
        decoration: BoxDecoration(color: Colors.white, borderRadius: borderRadius),
        foregroundDecoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: frameWidth),
          borderRadius: borderRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: picture,
      );
    }

    return SizedBox.square(dimension: size, child: picture);
  }
}
