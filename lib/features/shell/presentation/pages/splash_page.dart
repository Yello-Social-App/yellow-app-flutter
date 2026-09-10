import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../shared/widgets/yello_wordmark.dart';
import '../../../feed/presentation/bloc/feed_cubit.dart';

/// A plain white splash: just the "yello." wordmark ([YelloWordmark],
/// code-drawn, not a raster image) centered on the screen, gently breathing
/// (fading out and back in) while it waits, then fading fully out and
/// handing off — to Login for a fresh/unauthenticated session, or Feed for
/// one `SessionManager` already resolved as authenticated (`bootstrap()` is
/// kicked off in `main.dart`).
///
/// History: was `Image.asset(AssetConstants.splashLogo)` through several
/// passes (see `asset_constants.dart`'s doc comment — that PNG is still
/// used elsewhere, just not here anymore); briefly a plain `Text` wordmark
/// (reverted — user wanted the real logo look back); then the *current*
/// raster `appLogo.png` was itself a from-scratch Canvas recreation of a
/// clipped source file. This pass replaces the raster entirely with
/// [YelloWordmark], redrawn from a Claude Design reference ("Yello
/// Logo.dc.html", shared as a screenshot — the live project couldn't be
/// pulled via `DesignSync` in this session, no `/design-login` auth here)
/// specifically because a *raster* logo will always show some
/// upscale/downscale softness depending on device pixel ratio, however
/// good the source file is — vector-drawn text has no such ceiling. Later
/// pulled out to `shared/widgets/yello_wordmark.dart` so `FeedPage`'s
/// header could reuse the same mark in place of its old "Today." title —
/// see that widget's doc comment for the drawing details.
///
/// For the authenticated path, this also prefetches Feed itself: `load()`
/// is called on the same long-lived `FeedCubit` singleton `FeedPage` later
/// reuses (see that class's `BlocProvider.value`), and the breathing logo
/// is held until that finishes (loaded *or* errored — `load()`/`refresh()`
/// complete either way, never throw) alongside the usual minimum hold.
/// `FeedPage`'s own `..load()` call then just no-ops (already `loaded`),
/// so Feed appears with content already in hand instead of flashing its
/// shimmer skeleton right after this fades out. Unauthenticated sessions
/// skip this — there's no Feed to prefetch on the way to Login.
///
/// This page owns that hand-off itself rather than leaving it purely to
/// `RouteGuards` (see that class's doc comment) so the exit fade always
/// gets to finish before navigating, instead of racing a router-triggered
/// redirect the instant the session resolves.
///
/// The bordered-card look the user first saw around the logo turned out to
/// be Android 12+'s own system splash screen (drawn from the *launcher*
/// icon, before the Flutter engine's first frame — a different layer
/// entirely from this widget) — fixed via `flutter_native_splash`
/// (`pubspec.yaml`'s `flutter_native_splash:` config), not anything here.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  // Minimum time the logo spends breathing before it's allowed to exit, so
  // a near-instant session resolution (token already cached on disk)
  // doesn't skip straight past the splash without the motion ever reading.
  static const _minHold = Duration(milliseconds: 1400);

  // Doubles as both animations: while waiting, it ping-pongs between the
  // two bounds (the "breathing" fade in/out); on exit, `animateTo(0)` glides
  // from whatever the breathing value happened to be down to fully
  // transparent, so there's no jump between the two phases.
  late final AnimationController _opacityController = AnimationController(
    vsync: this,
    lowerBound: 0.45,
    upperBound: 1,
    value: 1,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _runSequence();
  }

  Future<void> _runSequence() async {
    final sessionManager = sl<SessionManager>();
    final sessionFuture = sessionManager.currentState == SessionState.unknown
        ? sessionManager.sessionState.firstWhere(
            (s) => s != SessionState.unknown,
          )
        : Future.value(sessionManager.currentState);

    // Starts alongside `sessionFuture` above, not after it, so a slow
    // session check doesn't add to this floor — same as before.
    final minHoldFuture = Future<void>.delayed(_minHold);
    final session = await sessionFuture;
    if (!mounted) return;

    // Authenticated: also hold the breathing logo through Feed's own
    // initial fetch (see class doc comment) so there's content ready the
    // instant this fades out.
    final waits = <Future<void>>[minHoldFuture];
    if (session == SessionState.authenticated) {
      waits.add(sl<FeedCubit>().load());
    }
    await Future.wait(waits);
    if (!mounted) return;

    _opacityController.stop();
    await _opacityController.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeIn,
    );
    if (!mounted) return;

    context.goNamed(
      session == SessionState.authenticated
          ? RouteNames.feed
          : RouteNames.login,
    );
  }

  @override
  void dispose() {
    _opacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Deliberately hardcoded white — this screen ignores the app's
      // light/dark theme by design.
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _opacityController,
          child: const YelloWordmark(),
        ),
      ),
    );
  }
}
