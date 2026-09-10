import 'package:flutter/foundation.dart' show kReleaseMode;

/// App-wide config. There's a single build of this app — no dev/staging/
/// prod flavor split — so this is intentionally just one flat static
/// holder, set once by [init] (called from `bootstrap()`, before DI is
/// configured — [ApiClient] in particular reads [baseUrl] at construction
/// time) and read everywhere else through these static members.
abstract final class AppConfig {
  static const String appDisplayName = 'yello';
  static const String packageName = 'social.yello.app';

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
