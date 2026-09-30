import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/yello_wordmark.dart';

/// A text + icon link pinned to the top-right corner of [AuthWaveHeader]
/// ("Sign Up" on Login, "Sign In" on Register, "Back" on the OTP step).
class AuthHeaderAction {
  const AuthHeaderAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Dark header slab for the auth screens: the "yello." wordmark top-left,
/// an [action] link top-right, a big centered [title], and a brand-yellow
/// wave that draws itself in from the left edge when the header mounts.
///
/// Sits on [AppColors.shell], the one surface that is dark in *both* themes
/// (ADR-009), so the header looks the same in light and dark mode and its
/// text uses the dark set's inks as fixed colors rather than theme lookups.
///
/// Runs edge-to-edge under the status bar: the page's `SafeArea` must pass
/// the top inset through (`top: false`), and this widget pads for it itself.
/// Its own [AnnotatedRegion] keeps the status-bar icons light while it's on
/// screen; once it scrolls away the page's region takes over.
///
/// The line is a `CustomPainter` over an extracted sub-path, not a blurred
/// or shadowed decoration — see GOTCHAS on Impeller and animated shadows.
/// Honors the platform's reduce-motion setting by drawing the full line
/// immediately.
class AuthWaveHeader extends StatefulWidget {
  const AuthWaveHeader({super.key, required this.title, this.action});

  final String title;
  final AuthHeaderAction? action;

  @override
  State<AuthWaveHeader> createState() => _AuthWaveHeaderState();
}

class _AuthWaveHeaderState extends State<AuthWaveHeader>
    with SingleTickerProviderStateMixin {
  static const _contentHeight = 260.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Started here rather than in initState — reduce-motion is read from
    // MediaQuery, which isn't available until dependencies resolve.
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final action = widget.action;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        child: ColoredBox(
          color: colors.shell,
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: SizedBox(
              height: _contentHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _WavePainter(
                          progress: _progress,
                          color: colors.yel,
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 24,
                    top: 18,
                    child: YelloWordmark(fontSize: 26, brightness: Brightness.dark),
                  ),
                  if (action != null)
                    Positioned(
                      right: 12,
                      top: 8,
                      child: _ActionLink(action: action),
                    ),
                  Align(
                    alignment: const Alignment(0, -0.18),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.displayXl.copyWith(
                          color: AppColors.dark.ink,
                          fontSize: 46,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -46 * 0.03,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionLink extends StatelessWidget {
  const _ActionLink({required this.action});

  final AuthHeaderAction action;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.dark.ink;
    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 24, color: ink),
              const SizedBox(width: 8),
              Text(
                action.label,
                style: AppTextStyles.button.copyWith(color: ink, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints the first `progress` fraction of the wave (by arc length), plus a
/// small dot riding the growing tip. Repaints straight off the animation
/// (`super(repaint:)`), so the header's widget tree never rebuilds per
/// frame.
class _WavePainter extends CustomPainter {
  _WavePainter({required this.progress, required this.color})
    : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  /// Low on the left, dipping under the title, then sweeping up and out of
  /// the right edge just below the action link — the reference's shape.
  /// Starts/ends a few px outside the box so the round caps never show at
  /// the edges.
  static Path _wave(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(-6, h * 0.64)
      ..cubicTo(w * 0.14, h * 0.98, w * 0.38, h * 1.02, w * 0.57, h * 0.82)
      ..cubicTo(w * 0.73, h * 0.64, w * 0.86, h * 0.44, w + 6, h * 0.30);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0) return;
    final metrics = _wave(size).computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final end = metric.length * t;

    canvas.drawPath(
      metric.extractPath(0, end),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Fades out over the last 15% so it doesn't linger on the right edge.
    final tipOpacity = t < 0.85 ? 1.0 : (1 - t) / 0.15;
    final tip = metric.getTangentForOffset(end);
    if (tip != null && tipOpacity > 0) {
      canvas.drawCircle(
        tip.position,
        4,
        Paint()..color = color.withValues(alpha: tipOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}
