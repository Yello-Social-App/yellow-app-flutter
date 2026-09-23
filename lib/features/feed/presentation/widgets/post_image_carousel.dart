import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/image_placeholder.dart';
import '../../../../shared/widgets/photo_viewer_page.dart';

/// Read-only, swipeable viewer for a *published* post's photos — the
/// display-side counterpart to create-post's fanned `_MediaCardStack`.
///
/// [PostEntity.imageUrls] can carry more than one photo, but the feed card
/// and post-detail page used to draw only `imageUrls.first`, silently
/// dropping the rest. This renders the whole set: a single image keeps the
/// existing width-fit, natural-height treatment (no carousel chrome needed
/// for one photo), while two or more become a horizontally swiping
/// [PageView] — cropped to a fixed aspect ratio so paging between
/// differently-shaped photos doesn't jump the card's height — with a
/// "n/total" badge and dot indicator so every photo is reachable.
///
/// Every photo here is *cropped or scaled down* to fit a card, so tapping
/// one opens [PhotoViewerPage] on that same photo: full screen, full
/// resolution, pinch/double-tap zoom, and swipeable across the rest of the
/// set. That is true wherever this widget is used (feed card, post detail,
/// repost preview) — the tap is handled here rather than passed in, so no
/// surface can accidentally ship a photo that doesn't expand.
class PostImageCarousel extends StatefulWidget {
  const PostImageCarousel({
    super.key,
    required this.imageUrls,
    this.placeholderHeight = 280,
  });

  final List<String> imageUrls;

  /// Height of the empty-state / broken-image placeholder, and of the
  /// multi-photo carousel itself. Callers pass the same figure the old
  /// single-image `errorBuilder` used, so a missing or broken photo still
  /// occupies the space it always did.
  final double placeholderHeight;

  @override
  State<PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<PostImageCarousel> {
  late final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;

    if (urls.isEmpty || urls.first.isEmpty) {
      return SizedBox(
        height: widget.placeholderHeight,
        child: const ImagePlaceholder(),
      );
    }

    if (urls.length == 1) {
      final targetWidth =
          (MediaQuery.sizeOf(context).width *
                  MediaQuery.devicePixelRatioOf(context))
              .round();
      return GestureDetector(
        onTap: () => openPhotoViewer(context, imageUrls: urls),
        child: CachedNetworkImage(
          imageUrl: urls.first,
          fit: BoxFit.fitWidth,
          width: double.infinity,
          memCacheWidth: targetWidth,
          errorWidget: (_, _, _) => SizedBox(
            height: widget.placeholderHeight,
            child: const ImagePlaceholder(),
          ),
        ),
      );
    }

    return GestureDetector(
      // Opens on whichever photo is showing, not always the first.
      onTap: () => openPhotoViewer(context, imageUrls: urls, initialIndex: _index),
      child: SizedBox(
        height: widget.placeholderHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final url = urls[i];
                final dpr = MediaQuery.devicePixelRatioOf(context);
                return url.isEmpty
                    ? const ImagePlaceholder()
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        memCacheWidth: (MediaQuery.sizeOf(context).width * dpr)
                            .round(),
                        memCacheHeight: (widget.placeholderHeight * dpr)
                            .round(),
                        errorWidget: (_, _, _) => const ImagePlaceholder(),
                      );
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              child: _CountBadge(index: _index, total: urls.length),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: _DotIndicator(index: _index, total: urls.length),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top-left "n/total" pill, matching the badge `_MediaCardStack` shows
/// while composing a post.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.index, required this.total});
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${index + 1}/$total',
        style: AppTextStyles.metaMono.copyWith(
          color: Colors.white,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Bottom-center row of dots, one per photo, the current one drawn wider —
/// the classic swipe-through-photos affordance layered over the image
/// rather than the app's ink/line palette, since it has to stay legible
/// over whatever photo is behind it.
///
/// Legibility over a light photo comes from the flat dark pill behind the
/// row, **not** from a blurred `BoxShadow` on each dot: the dots are
/// `AnimatedContainer`s whose decoration changes every frame of the width
/// animation, which is exactly the shape that crashed this app's renderer
/// (`docs/GOTCHAS.md`). The pill is a plain, unblurred fill and is safe.
class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.index, required this.total});
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < total; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: i == index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: i == index ? 0.95 : 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
