import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import 'app_colors.dart';

/// The app's active theme: a palette family crossed with a brightness.
///
/// Two axes rather than one flat list of four, because `MaterialApp` already
/// owns the brightness axis — it swaps `theme`/`darkTheme` itself — so only
/// [flavor] has to be resolved before the themes are built. The Theme screen
/// still presents the four combinations as four rows; that is a presentation
/// choice, not the shape of the state.
@immutable
class ThemeState {
  const ThemeState({this.mode = ThemeMode.light, this.flavor = AppThemeFlavor.classic});

  /// Light or dark. Never [ThemeMode.system]: a third value would need its
  /// own persisted string and its own row on the Theme screen, and nothing
  /// in the app offers "match the system" today.
  final ThemeMode mode;

  /// Which palette family the light/dark pair is drawn from.
  final AppThemeFlavor flavor;

  bool get isDark => mode == ThemeMode.dark;

  ThemeState copyWith({ThemeMode? mode, AppThemeFlavor? flavor}) =>
      ThemeState(mode: mode ?? this.mode, flavor: flavor ?? this.flavor);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ThemeState && other.mode == mode && other.flavor == flavor);

  @override
  int get hashCode => Object.hash(mode, flavor);
}

/// App-wide theme choice, made on the account menu's Theme screen
/// (`features/settings/presentation/pages/theme_page.dart`). A single
/// instance lives for the app's lifetime, registered as a singleton so the
/// screen and the `MaterialApp.router` at the root share one source of
/// truth.
class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit() : super(const ThemeState()) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    emit(
      ThemeState(
        mode: prefs.getString(AppConstants.prefsKeyThemeMode) == 'dark' ? ThemeMode.dark : ThemeMode.light,
        flavor: AppThemeFlavor.fromName(prefs.getString(AppConstants.prefsKeyThemeFlavor)),
      ),
    );
  }

  /// Emits first and persists after: the repaint should not wait on disk,
  /// and a write that fails only costs the choice its persistence, not the
  /// session.
  Future<void> setTheme({ThemeMode? mode, AppThemeFlavor? flavor}) async {
    final next = state.copyWith(mode: mode, flavor: flavor);
    if (next == state) return;
    emit(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefsKeyThemeMode, next.isDark ? 'dark' : 'light');
    await prefs.setString(AppConstants.prefsKeyThemeFlavor, next.flavor.name);
  }

  /// Convenience for the callers that only move along the brightness axis.
  Future<void> setMode(ThemeMode mode) => setTheme(mode: mode);
}
