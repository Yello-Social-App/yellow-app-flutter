import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// App-wide light/dark toggle (the mockup's theme-toggle button, present on
/// both the Home header and the Profile screen). A single instance lives
/// for the app's lifetime, registered as a singleton so both call sites —
/// and the `MaterialApp.router` at the root — share one source of truth.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.light) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.prefsKeyThemeMode);
    if (saved == 'dark') emit(ThemeMode.dark);
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    emit(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefsKeyThemeMode, next == ThemeMode.dark ? 'dark' : 'light');
  }
}
