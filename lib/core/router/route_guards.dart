import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../security/session_manager.dart';

/// Central `redirect` logic for [GoRouter]: keeps unauthenticated users out
/// of the shell and authenticated users out of the auth screens, based
/// purely on [SessionManager] — no route or page has to know about session
/// state itself.
///
/// Keyed off **paths**, not route names — `GoRouterState.name` reads back
/// `null` inside the top-level `redirect` callback on `go_router: ^17.5.0`
/// (the matched route's name isn't resolved yet at this point in the
/// pipeline, only its location), which silently broke every guard check:
/// `_publicRoutePaths.contains(null)` was always false, so
/// `/login`→`/register` got bounced straight back to `/login` on every
/// attempt. `state.matchedLocation` is populated correctly at this point,
/// so path strings are the reliable thing to compare here. These must stay
/// in sync with the paths declared in `app_router.dart`.
///
/// This guard deliberately does **not** redirect *either* an unauthenticated
/// **or** an authenticated session away from `/splash` — `SplashPage` owns
/// that hand-off itself for both outcomes (fade out, then
/// `goNamed(RouteNames.login)` or `goNamed(RouteNames.feed)`) so its
/// animation always gets to finish instead of racing this guard's redirect.
/// `/splash` staying in `_publicRoutePaths` (and out of
/// `_authenticatedBounceRoutes` below) is what holds it in place for both
/// cases. An earlier pass *did* bounce an authenticated session off
/// `/splash` straight to `/feed` instantly here — reverted on the user's
/// request: a returning logged-in user was skipping the splash animation
/// entirely (`SplashPage` barely got to render a first frame before this
/// guard redirected it away), while a fresh/unauthenticated session got the
/// full fade — an inconsistent, jarring experience. Now both sessions see
/// the same splash before landing anywhere.
class RouteGuards {
  RouteGuards(this._sessionManager);

  final SessionManager _sessionManager;

  static const _publicRoutePaths = {'/login', '/register', '/splash'};

  // Public routes an *authenticated* session gets bounced off of straight to
  // `/feed`, no redirect delay — deliberately excludes `/splash`, which
  // `SplashPage` itself always owns the hand-off for (see doc comment).
  static const _authenticatedBounceRoutes = {'/login', '/register'};

  String? redirect(BuildContext context, GoRouterState state) {
    final session = _sessionManager.currentState;
    final path = state.matchedLocation;

    if (session == SessionState.unknown) {
      // Still waiting on SessionManager.bootstrap() — hold on splash,
      // bounce anything else back to it.
      return path == '/splash' ? null : '/splash';
    }

    final isPublicRoute = _publicRoutePaths.contains(path);
    if (session == SessionState.unauthenticated && !isPublicRoute) {
      return '/login';
    }
    if (session == SessionState.authenticated &&
        _authenticatedBounceRoutes.contains(path)) {
      return '/feed';
    }
    return null;
  }
}
