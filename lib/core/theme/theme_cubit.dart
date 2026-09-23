import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// App-wide light/dark choice, made on the account menu's Theme screen
/// (`features/settings/presentation/pages/theme_page.dart`). A single
/// instance lives for the app's lifetime, registered as a singleton so the
/// screen and the `MaterialApp.router` at the root share one source of
/// truth.
///
/// Only light and dark are stored: `ThemeMode.system` would need a third
/// persisted value and a `AppColors` pass for a mode nothing in the app
/// currently offers.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.light) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.prefsKeyThemeMode);
    if (saved == 'dark') emit(ThemeMode.dark);
  }

  /// Emits first and persists after: the repaint should not wait on disk,
  /// and a write that fails only costs the choice its persistence, not the
  /// session.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    emit(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefsKeyThemeMode, mode == ThemeMode.dark ? 'dark' : 'light');
  }
}
