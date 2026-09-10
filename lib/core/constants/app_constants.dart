/// App-wide non-visual constants (durations, limits, storage keys shared
/// across features). Visual tokens live in `core/theme/`.
abstract final class AppConstants {
  static const int postMaxChars = 2200;
  static const int postShortLengthThreshold = 40;

  /// Most images a single post can carry — matches the backend's practical
  /// limit for the `images` multipart field (see `createPost`).
  static const int postMaxImages = 10;

  /// Longest edge (px) a picked post photo is downscaled to before upload.
  /// Untouched camera photos (3000-4000px+) times up to [postMaxImages]
  /// attachments can build a multipart body large enough to trip the
  /// backend's max-request-size and come back as 413 Payload Too Large —
  /// this keeps the body well under that regardless of source resolution.
  static const double postImageMaxDimension = 1600;

  static const Duration storySegmentDuration = Duration(milliseconds: 4200);
  static const Duration likePopDuration = Duration(milliseconds: 190);
  static const Duration typingIndicatorDelay = Duration(milliseconds: 1900);

  static const int feedPageSize = 20;
  static const int messagesPageSize = 30;

  static const String secureKeyAccessToken = 'auth.access_token';
  static const String secureKeyRefreshToken = 'auth.refresh_token';
  static const String secureKeyTokenExpiry = 'auth.token_expiry';

  /// Written by `SessionManager.startSession`, read by its `bootstrap()`.
  /// `'false'` means the next cold start must not silently resume the
  /// session; any other value (including absent) means it may.
  static const String secureKeyRememberMe = 'auth.remember_me';

  static const String prefsKeyThemeMode = 'settings.theme_mode';
  static const String prefsKeyOnboardingSeen = 'settings.onboarding_seen';
}
