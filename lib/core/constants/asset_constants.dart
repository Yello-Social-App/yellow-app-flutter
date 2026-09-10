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
/// [circleIcon] IS actively read: `FeedPage._Header` renders it (full color,
/// not tinted — it's a two-tone ink/yellow mark already matching the brand
/// palette) as a header button next to search that opens the **Circle**
/// (friends) branch (index 1) — despite once also being reused as the
/// Profile tab's icon inside `BottomNavBar` (a different, unrelated button;
/// see that file's doc comment), this asset's filename always did genuinely
/// mean the Circle/friends feature here, which is why it landed on this
/// button for good. Circle's branch has no bottom-nav slot of its own (see
/// `BottomNavBar`'s doc comment for why), so this header button is
/// currently the app's only real nav entry point into it.
abstract final class AssetConstants {
  static const String iconDir = 'assets/icons/';
  static const String imageDir = 'assets/images/';
  static const String splashLogo = 'assets/icons/appLogo.png';
  static const String circleIcon = 'assets/icons/Circle.png';
}
