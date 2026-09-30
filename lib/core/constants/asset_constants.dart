/// Static asset paths. The design mostly ships with user-fillable
/// `<image-slot>` placeholders rather than baked-in imagery, so avatars and
/// post media are rendered with generated initials/color tiles
/// (`shared/widgets/app_avatar.dart`) until real media upload exists.
///
/// [splashLogo] is a real file (the app's brand-mark PNG) but **not used
/// directly by any code or config any more** — `SplashPage` draws the
/// "yello." wordmark in code instead (`_YelloWordmark`, see its doc
/// comment), and the native OS-level splash (`flutter_native_splash` in
/// `pubspec.yaml`) was deliberately configured to show no logo at all
/// (plain white background only, on both the pre-Android-12 and Android-12+
/// paths — see that config block's comment for why each needed a different
/// fix). It now exists purely as the **source-of-truth to regenerate
/// from**: it's what `assets/icons/appIconSquare.png` (the square,
/// non-stretched derivative `flutter_launcher_icons` actually points at, for
/// the home-screen app icon) is manually re-derived from whenever the brand
/// mark changes — see that config block's comment in `pubspec.yaml` for the
/// exact steps. `appLogo.png` itself is bundled as a Flutter asset (matches
/// `pubspec.yaml`'s `assets:` glob) but nothing in `lib/` reads it.
///
/// [circleIcon] is the Feed header's button into the **Circle** (friends)
/// branch (index 1). It left the header for a while (ADR-043) and came back
/// in Inbox's slot (ADR-044). The filename genuinely means the Circle/friends
/// feature (it was once also borrowed as the Profile tab's icon in
/// `BottomNavBar`, an unrelated button).
abstract final class AssetConstants {
  static const String iconDir = 'assets/icons/';
  static const String imageDir = 'assets/images/';
  static const String splashLogo = 'assets/icons/appLogo.png';
  static const String circleIcon = 'assets/icons/Circle.png';

  /// Transparent Signals bells: black for light themes, white for dark.
  /// Unread notifications play a gentle ring, then rest for 1.6 seconds.
  /// PNGs share the GIFs' resting geometry. Regenerate with
  /// `python tool/generate_notification_bells.py` (requires Pillow).
  static const String notificationIcon =
      'assets/icons/notification_bell_black.png';
  static const String notificationIconActive =
      'assets/icons/notification_bell_black.gif';
  static const String notificationIconDark =
      'assets/icons/notification_bell_white.png';
  static const String notificationIconActiveDark =
      'assets/icons/notification_bell_white.gif';

  /// Community thread vote arrows, as four authored PNGs rather than Material
  /// glyphs: outline for "not voted", filled for the direction the viewer
  /// chose. They ship pre-colored in the brand yellow, so they are drawn
  /// untinted — see `VoteArrowIcon`.
  ///
  /// Note the capital "A" in [voteDownArrowActive]: that is the file's real
  /// name on disk. Asset keys are case-sensitive at runtime on Android and
  /// iOS even though a Windows dev machine resolves either spelling, so a
  /// "tidied" lowercase path here would load fine locally and throw on
  /// device.
  static const String voteUpArrow = 'assets/icons/vote_up_arrow.png';
  static const String voteDownArrow = 'assets/icons/vote_down_arrow.png';
  static const String voteUpArrowActive = 'assets/icons/voted_up_arrow.png';
  static const String voteDownArrowActive = 'assets/icons/voted_down_Arrow.png';
}
