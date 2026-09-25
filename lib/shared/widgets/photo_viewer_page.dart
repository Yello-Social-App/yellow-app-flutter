import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_icon_button.dart';

/// What [PhotoViewerPage] is pushed with, through the route's `extra`.
///
/// Photo URLs are long and plural — they cannot go in the path — so this
/// route is `extra`-only and therefore not deep-linkable. Landing on
/// `/photo` cold gets the "not available" state rather than a crash;
/// nothing links to it from outside the app.
@immutable
class PhotoViewerArgs {
  const PhotoViewerArgs({required this.imageUrls, this.initialIndex = 0, this.cacheKeys = const []});

  final List<String> imageUrls;
  final int initialIndex;

  /// One stable cache key per URL, or empty to let the image cache key on
  /// the URL itself — which is what a post's photos do, their URLs being
  /// permanent.
  ///
  /// A chat attachment's URL is presigned and re-signed on every history
  /// fetch, so the same picture arrives under a different URL every few
  /// seconds. Those pass the attachment id here — the key the transcript's
  /// own thumbnails are already stored under — so expanding one is a cache
  /// hit rather than a second download of a file that is already on disk.
  final List<String> cacheKeys;
}

/// Opens the full-screen viewer on [initialIndex] of [imageUrls].
///
/// Empty URLs are dropped first (a post can carry a blank slot, which the
/// cards draw as an `ImagePlaceholder` — there is nothing to expand), and
/// [initialIndex] is re-mapped onto what survived, so tapping the third
/// photo still opens the third *photo*, not the third slot. With nothing
/// left to show this is a no-op rather than an empty viewer.
void openPhotoViewer(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
  List<String> cacheKeys = const [],
}) {
  final kept = <String>[];
  final keptKeys = <String>[];
  var mapped = 0;
  for (var i = 0; i < imageUrls.length; i++) {
    if (imageUrls[i].isEmpty) continue;
    if (i < initialIndex) mapped++;
    kept.add(imageUrls[i]);
    if (i < cacheKeys.length) keptKeys.add(cacheKeys[i]);
  }
  if (kept.isEmpty) return;
  context.pushNamed(
    RouteNames.photoViewer,
    extra: PhotoViewerArgs(
      imageUrls: kept,
      initialIndex: mapped.clamp(0, kept.length - 1),
      // Anything short of one key per surviving photo would pair keys with
      // the wrong pictures, so a partial list is dropped entirely.
      cacheKeys: keptKeys.length == kept.length ? keptKeys : const [],
    ),
  );
}

/// Full-screen, pinch- and double-tap-zoomable photo viewer — what a tap on
/// any post photo opens.
///
/// Deliberately *not* a Hero transition: a repost preview and a plain card
/// for the same post can both be on screen in the feed at once, so any tag
/// derived from post id + photo index can legitimately appear twice in one
/// route, which is a hard framework crash. The route fades instead (see
/// `AppRouter`).
class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({super.key, required this.imageUrls, this.initialIndex = 0, this.cacheKeys = const []});

  final List<String> imageUrls;
  final int initialIndex;

  /// See [PhotoViewerArgs.cacheKeys]; ignored unless there is exactly one
  /// per URL.
  final List<String> cacheKeys;

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  /// Whether the *current* photo is zoomed in. It lives here rather than in
  /// the page itself because it decides whether the [PageView] may scroll.
  bool _zoomed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  void _onZoomChanged(int index, bool zoomed) {
    // A page that has just been scrolled away from resets its own zoom, and
    // reports that from inside the parent's build; ignoring anything but the
    // current page keeps that from calling setState during build.
    if (index != _index || zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Full-bleed black in both themes, so light status-bar icons are
      // always the correct pairing here.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: urls.isEmpty
            ? _UnavailableView(onClose: _close)
            : Stack(
                children: [
                  Positioned.fill(
                    child: PageView.builder(
                      controller: _controller,
                      // A zoomed-in photo owns every horizontal drag: panning
                      // around it must not page to the next photo.
                      physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                      itemCount: urls.length,
                      onPageChanged: (i) => setState(() {
                        _index = i;
                        _zoomed = false;
                      }),
                      itemBuilder: (context, i) => _ZoomablePhoto(
                        key: ValueKey('$i:${urls[i]}'),
                        imageUrl: urls[i],
                        cacheKey: widget.cacheKeys.length == urls.length ? widget.cacheKeys[i] : null,
                        isCurrent: i == _index,
                        onZoomChanged: (zoomed) => _onZoomChanged(i, zoomed),
                        onTapOutOfZoom: _close,
                      ),
                    ),
                  ),
                  Positioned(
                    top: topInset + 8,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        AppIconButton(
                          icon: const Icon(CupertinoIcons.xmark),
                          onPressed: _close,
                          backgroundColor: Colors.black.withValues(alpha: 0.45),
                          borderColor: Colors.white.withValues(alpha: 0.28),
                          iconColor: Colors.white,
                        ),
                        const Spacer(),
                        if (urls.length > 1) _CountPill(index: _index, total: urls.length),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// One page of the viewer: the photo, fit to the screen, pinch- and
/// double-tap-zoomable.
class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({
    super.key,
    required this.imageUrl,
    required this.isCurrent,
    required this.onZoomChanged,
    required this.onTapOutOfZoom,
    this.cacheKey,
  });

  final String imageUrl;

  /// See [PhotoViewerArgs.cacheKeys].
  final String? cacheKey;

  /// False for the neighbouring pages the [PageView] keeps alive — they drop
  /// any zoom, so a photo always comes back into view fit to the screen.
  final bool isCurrent;

  final ValueChanged<bool> onZoomChanged;

  /// A single tap while zoomed out — the whole-screen "I'm done" gesture.
  /// While zoomed *in*, the same tap returns the photo to fit instead.
  final VoidCallback onTapOutOfZoom;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> with SingleTickerProviderStateMixin {
  static const double _doubleTapScale = 2.5;

  /// Anything above this reads as "the user has zoomed in" — a hair over 1,
  /// so floating-point drift at fit-scale never trips it.
  static const double _zoomEpsilon = 1.01;

  final TransformationController _transform = TransformationController();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _lastDoubleTapDown;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransformChanged);
    _anim.addListener(_onAnimationTick);
  }

  @override
  void didUpdateWidget(covariant _ZoomablePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCurrent && !widget.isCurrent) _resetZoom(animated: false);
  }

  @override
  void dispose() {
    _anim.removeListener(_onAnimationTick);
    _anim.dispose();
    _transform.removeListener(_onTransformChanged);
    _transform.dispose();
    super.dispose();
  }

  void _onAnimationTick() {
    final animation = _zoomAnimation;
    if (animation != null) _transform.value = animation.value;
  }

  void _onTransformChanged() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > _zoomEpsilon;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
  }

  void _animateTo(Matrix4 target) {
    _zoomAnimation = Matrix4Tween(begin: _transform.value, end: target)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward(from: 0);
  }

  void _resetZoom({bool animated = true}) {
    if (!animated) {
      _anim.stop();
      _zoomAnimation = null;
      _transform.value = Matrix4.identity();
      return;
    }
    _animateTo(Matrix4.identity());
  }

  void _handleTap() {
    if (_zoomed) {
      _resetZoom();
      return;
    }
    widget.onTapOutOfZoom();
  }

  void _handleDoubleTap() {
    if (_zoomed) {
      _resetZoom();
      return;
    }
    final position = _lastDoubleTapDown?.localPosition;
    if (position == null) return;
    // Scale about the tapped point. The matrix is built entry by entry
    // (scale down the diagonal, translation in the last column) rather than
    // through `Matrix4.translate`, whose argument types have churned across
    // vector_math releases.
    const scale = _doubleTapScale;
    _animateTo(
      Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setEntry(2, 2, scale)
        ..setEntry(0, 3, -position.dx * (scale - 1))
        ..setEntry(1, 3, -position.dy * (scale - 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 5,
      // The gesture detector sits *inside* the viewer so a double-tap's
      // `localPosition` is already in the child's own coordinate space —
      // which is the space the transform above is written in. The viewer
      // itself never claims taps, only drags and pinches.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onDoubleTapDown: (details) => _lastDoubleTapDown = details,
        onDoubleTap: _handleDoubleTap,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            cacheKey: widget.cacheKey,
            fit: BoxFit.contain,
            // No `memCacheWidth` here, unlike the feed card: the whole point
            // of this screen is the full-resolution photo, and a
            // screen-width decode goes to mush at 5x.
            filterQuality: FilterQuality.medium,
            fadeInDuration: const Duration(milliseconds: 120),
            placeholder: (_, _) => const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
            errorWidget: (_, _, _) => const _PhotoError(),
          ),
        ),
      ),
    );
  }
}

/// "n/total" pill, the same treatment as the carousel badge on the card the
/// viewer was opened from.
class _CountPill extends StatelessWidget {
  const _CountPill({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${index + 1}/$total',
        style: AppTextStyles.metaMono.copyWith(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

/// A photo that would not load — the same shape as the cards' error state,
/// in the viewer's palette.
class _PhotoError extends StatelessWidget {
  const _PhotoError();

  @override
  Widget build(BuildContext context) {
    final fg = Colors.white.withValues(alpha: 0.55);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.exclamationmark_triangle, color: fg, size: 30),
          const SizedBox(height: 8),
          Text('That photo could not be loaded', style: AppTextStyles.bodySm.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// What a cold `/photo` (no `extra`) lands on — see [PhotoViewerArgs].
class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final fg = Colors.white.withValues(alpha: 0.55);
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.xmark_rectangle, color: fg, size: 30),
            const SizedBox(height: 8),
            Text('This photo is no longer available', style: AppTextStyles.bodySm.copyWith(color: fg)),
            const SizedBox(height: 16),
            AppIconButton(
              icon: const Icon(CupertinoIcons.xmark),
              onPressed: onClose,
              backgroundColor: Colors.black.withValues(alpha: 0.45),
              borderColor: Colors.white.withValues(alpha: 0.28),
              iconColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
