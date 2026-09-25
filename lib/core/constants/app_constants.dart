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

  /// A story's text — the caption on an `IMAGE` story or the whole of a
  /// `TEXT` one. The backend rejects anything longer with
  /// `400 VALIDATION_FAILED` on `text`, so the composer counts down to it.
  static const int storyMaxChars = 140;

  /// Longest edge (px) a picked story photo is downscaled to before upload.
  /// The backend re-encodes to fit 1080x1920 anyway and refuses anything
  /// over 16 megapixels outright (`400 INVALID_IMAGE`) — a 12 MP phone
  /// photo is under that, but a stitched panorama or a screenshot from a
  /// high-DPI tablet is not, and 2160 is comfortably inside every limit
  /// while still over-sampling the server's own 1080-wide target.
  static const double storyImageMaxDimension = 2160;

  /// How long a story lives. The server owns `expiresAt` (always
  /// `createdAt + 24h`); this is only for copy like "23h left".
  static const Duration storyLifetime = Duration(hours: 24);

  /// A story reply is a DM, and the chat service's own body limit applies —
  /// not [storyMaxChars], which is the story's text, not the reply's.
  static const int storyReplyMaxChars = 4000;

  static const int storyFeedPageSize = 20;
  static const int storyViewersPageSize = 20;
  static const int storyArchivePageSize = 30;
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

  /// The FCM token last successfully registered via `PUT
  /// /notifications/v1/devices` (see `NotificationRepositoryImpl`).
  /// `LogoutUseCase` reads this to call `POST /devices/unregister` before
  /// the session's own tokens are discarded, per `yello-notify`'s
  /// documented client flow — without a push SDK wired up yet, this simply
  /// stays unset and the unregister step is a no-op.
  static const String secureKeyPushToken = 'notify.push_token';

  static const String prefsKeyThemeMode = 'settings.theme_mode';

  /// Stores an `AppThemeFlavor.name`. Absent on every install that
  /// predates the second palette, which `AppThemeFlavor.fromName`
  /// resolves to `classic` — so an upgrade keeps the theme it had.
  static const String prefsKeyThemeFlavor = 'settings.theme_flavor';
  static const String prefsKeyOnboardingSeen = 'settings.onboarding_seen';
}
