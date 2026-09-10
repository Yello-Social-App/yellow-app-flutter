import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Corner-radius tokens used throughout the design (cards, pills, tiles).
abstract final class AppRadii {
  static const double xs = 12;
  static const double sm = 16;
  static const double md = 18;
  static const double lg = 20;
  static const double xl = 22;
  static const double xxl = 24;
  static const double huge = 26;
  static const double pill = 999;
}

/// Spacing scale (matches the 4px-rounded gaps used across the mockup).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 16;
  static const double xxl = 22;
}

/// Builds the light/dark [ThemeData] for the app, wiring the [AppColors]
/// design-token extension alongside Material defaults so any un-styled
/// widget (dialogs, default `Text`, system chrome) still lands close to the
/// mockup's palette.
abstract final class AppTheme {
  static ThemeData get light => _build(AppColors.light, Brightness.light);
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final textTheme = GoogleFonts.nunitoTextTheme(
      base.textTheme,
    ).apply(bodyColor: colors.ink, displayColor: colors.ink);

    return base.copyWith(
      scaffoldBackgroundColor: colors.bg,
      canvasColor: colors.bg,
      cardColor: colors.surf,
      dividerColor: colors.line,
      splashFactory: InkRipple.splashFactory,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.yel,
        onPrimary: colors.onYel,
        secondary: colors.ink,
        onSecondary: colors.bg,
        error: colors.red,
        onError: Colors.white,
        surface: colors.surf,
        onSurface: colors.ink,
        // Material 3 defaults `surfaceTint` to `primary` (our brand yellow)
        // and alpha-blends it onto every elevated surface — Card, Dialog,
        // BottomSheet, PopupMenu — at 5-14% opacity based on elevation.
        // That's what reads as "every color looks a bit lighter than the
        // design": it's really a yellow tint overlay Flutter adds
        // automatically, not the token colors themselves changing. This
        // app's design is flat/hand-drawn (see AppColors doc comment), so
        // pin it transparent globally instead of patching each widget's
        // own `surfaceTintColor` one at a time (AppBarTheme below already
        // had to do that locally before this fix existed).
        surfaceTint: Colors.transparent,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        foregroundColor: colors.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      iconTheme: IconThemeData(color: colors.ink),
      extensions: [colors],
    );
  }
}
