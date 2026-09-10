import 'dart:async';

import '../constants/app_constants.dart';
import '../network/token_refresh_service.dart';
import 'jwt_manager.dart';
import 'secure_storage_service.dart';

/// Tracks whether the app currently holds a usable session and broadcasts
/// the moments that matter to the rest of the app: a fresh login, an
/// explicit logout, or the session dying underneath the user (refresh
/// failed in [AuthInterceptor]). `core/router/route_guards.dart` listens to
/// [sessionState] to decide whether protected routes are reachable; nothing
/// else should need to read tokens directly out of [SecureStorageService].
///
/// OWASP Mobile **M6 — Insecure Authorization**: centralizing "am I logged
/// in" here means every route guard and every "log out" affordance agree on
/// exactly one definition of a valid session (a present, non-expired access
/// token) instead of each re-deriving it.
enum SessionState { unknown, authenticated, unauthenticated }

abstract interface class SessionManager {
  Stream<SessionState> get sessionState;
  SessionState get currentState;

  Future<void> bootstrap();

  /// [rememberMe] (default `true`) controls whether a future cold start's
  /// [bootstrap] is allowed to silently resume this session at all — `false`
  /// still leaves the user logged in for the rest of *this* app run (API
  /// calls, mid-session token refresh on a 401, all unaffected), it just
  /// means the next full app launch goes straight to the login screen
  /// instead of trying to resume. See [bootstrap]'s doc for why that's a
  /// separate concern from the access token's own, much shorter, expiry.
  Future<void> startSession({
    required String accessToken,
    required String refreshToken,
    bool rememberMe = true,
  });
  Future<void> endSession();

  /// Called by [AuthInterceptor] when a 401 survives a refresh attempt —
  /// forces the app back to "logged out" even though nothing local called
  /// [endSession] directly.
  Future<void> notifySessionExpired();
}

class SessionManagerImpl implements SessionManager {
  SessionManagerImpl(this._secureStorage, this._jwtManager, this._tokenRefreshService);

  final SecureStorageService _secureStorage;
  final JwtManager _jwtManager;
  final TokenRefreshService _tokenRefreshService;

  final _controller = StreamController<SessionState>.broadcast();
  SessionState _state = SessionState.unknown;

  @override
  Stream<SessionState> get sessionState => _controller.stream;

  @override
  SessionState get currentState => _state;

  @override
  Future<void> bootstrap() async {
    // "Remember me" was declined at login — don't resume, even if the
    // tokens underneath are technically still alive. Absent (never written,
    // e.g. an install from before this flag existed, or a session started
    // by the OTP-verify flow, which has no remember-me control at all) is
    // treated as remembered, so this can't silently log anyone out who
    // never saw the toggle.
    final remembered = await _secureStorage.read(AppConstants.secureKeyRememberMe) != 'false';
    if (!remembered) {
      await _clearSession();
      return;
    }

    final token = await _secureStorage.readAccessToken();
    if (token != null && !_jwtManager.isExpired(token)) {
      _emit(SessionState.authenticated);
      return;
    }

    // The access token is short-lived by design (that's the whole reason a
    // separate, long-lived refresh token exists) — so it being expired here
    // is the *normal* case on a cold start, not a reason to log out on its
    // own. Try to silently exchange the refresh token for a new pair before
    // giving up; only a failed/absent refresh actually ends the session.
    // Skipping this step is what used to force a full re-login on basically
    // every app relaunch, "remember me" or not.
    if (await _tokenRefreshService.refresh()) {
      _emit(SessionState.authenticated);
    } else {
      await _clearSession();
    }
  }

  @override
  Future<void> startSession({
    required String accessToken,
    required String refreshToken,
    bool rememberMe = true,
  }) async {
    await _secureStorage.writeTokens(accessToken: accessToken, refreshToken: refreshToken);
    await _secureStorage.write(AppConstants.secureKeyRememberMe, rememberMe.toString());
    _emit(SessionState.authenticated);
  }

  @override
  Future<void> endSession() async {
    await _clearSession();
  }

  @override
  Future<void> notifySessionExpired() async {
    await _clearSession();
  }

  Future<void> _clearSession() async {
    await _secureStorage.clearTokens();
    await _secureStorage.delete(AppConstants.secureKeyRememberMe);
    _emit(SessionState.unauthenticated);
  }

  void _emit(SessionState next) {
    _state = next;
    _controller.add(next);
  }

  void dispose() => _controller.close();
}
