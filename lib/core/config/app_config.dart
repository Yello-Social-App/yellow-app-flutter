import 'package:flutter/foundation.dart' show kReleaseMode;

/// App-wide config. There's a single build of this app — no dev/staging/
/// prod flavor split — so this is intentionally just one flat static
/// holder, set once by [init] (called from `bootstrap()`, before DI is
/// configured — [ApiClient] in particular reads [baseUrl] at construction
/// time) and read everywhere else through these static members.
abstract final class AppConfig {
  static const String appDisplayName = 'yello';
  static const String packageName = 'social.yello.app';

  /// The only backend that exists today — `main()` hands it to [init].
  ///
  /// It is a constant rather than only a literal in `main.dart` because the
  /// notification background isolates (the FCM handler and the direct-reply
  /// action) never run `bootstrap()`, and statics don't cross an isolate
  /// boundary: over there this is the one thing that can re-seed [baseUrl].
  /// Repoint it here if a dedicated production host is ever stood up.
  static const String defaultBaseUrl = 'https://api.yello.cachewraith.com';

  /// Where the sideload updater looks for the published build.
  ///
  /// Yello ships as an APK people install themselves, not through a store,
  /// so "is there a newer build?" is answered by a `latest.json` published
  /// as a release asset — the API still serves no version resource
  /// (`docs/BACKEND.md`). GitHub's `releases/latest/download/<name>` is a
  /// permanent redirect onto whatever the newest release attached, so this
  /// URL never has to change when a version is cut.
  ///
  /// Moving the channel off GitHub means changing this one line: nothing
  /// below it knows where the manifest came from. See ADR-029.
  static const String updateManifestUrl =
      'https://github.com/Yello-Social-App/yellow-app-flutter/releases/latest/download/latest.json';

  static String? _baseUrl;
  static bool? _enableLogging;

  static bool get isInitialized => _baseUrl != null;

  static void init({required String baseUrl, bool? enableLogging}) {
    _baseUrl = baseUrl;
    _enableLogging = enableLogging ?? !kReleaseMode;
  }

  static String get baseUrl {
    final url = _baseUrl;
    if (url == null) {
      throw StateError(
        'AppConfig.init() was never called — bootstrap() (called from '
        'main.dart) always calls it first, so reaching this means '
        'AppConfig.baseUrl was read before bootstrap() ran.',
      );
    }
    return url;
  }

  /// Whether request/response bodies should be logged — off by default in
  /// release builds since they may carry tokens or PII (see
  /// `LoggingInterceptor`).
  static bool get enableLogging => _enableLogging ?? !kReleaseMode;

  /// True in release builds (`flutter run --release` / `flutter build ...`).
  /// Used to gate verbose logging — see `core/utils/logger.dart`.
  static bool get isProd => kReleaseMode;
}
