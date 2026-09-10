import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/config/app_config.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/security/root_jailbreak_detector.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'l10n/app_localizations.dart';
import 'shared/widgets/responsive_content.dart';

/// Root widget the app's single entrypoint (`main.dart`) hands off to once
/// DI/session bootstrap is done — see `bootstrap.dart`.
class YelloApp extends StatelessWidget {
  const YelloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ThemeCubit>.value(
      value: sl<ThemeCubit>(),
      child: Builder(
        builder: (context) {
          final themeMode = context.watch<ThemeCubit>().state;
          return MaterialApp.router(
            title: AppConfig.appDisplayName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // Applied once, here, rather than per-screen — see
            // ResponsiveContent's doc comment and _clampTextScale's.
            builder: (context, child) =>
                _clampTextScale(context, ResponsiveContent(child: child!)),
            routerConfig: sl<AppRouter>().router,
          );
        },
      ),
    );
  }
}

/// A hard stop shown instead of [YelloApp] when
/// [RootJailbreakDetector.check] reports [DeviceIntegrityReport.shouldBlockLaunch]
/// — a rooted/jailbroken OS undermines every other control in
/// `core/security/` (secure storage, cert pinning, biometrics all assume an
/// intact OS sandbox), so the app refuses to run rather than run unsafely.
class SecurityBlockedApp extends StatelessWidget {
  const SecurityBlockedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          _clampTextScale(context, ResponsiveContent(child: child!)),
      home: Builder(
        builder: (context) {
          final colors = AppColors.of(context);
          final l10n = AppLocalizations.of(context)!;
          return Scaffold(
            backgroundColor: colors.bg,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gpp_bad_outlined, size: 40, color: colors.red),
                    const SizedBox(height: 16),
                    Text(
                      l10n.securityBlockedTitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleLg.copyWith(color: colors.ink),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.securityBlockedBody,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Clamps the device's system font-scale setting to a range this app's
/// tightly pixel-authored layouts (fixed-height heroes, single-line nav
/// labels, the profile header's measured-overlap block, etc.) can actually
/// absorb, instead of applying it unclamped.
///
/// This does NOT disable text scaling — a viewer who bumped their system
/// font size still gets noticeably larger text throughout the app, just
/// bounded to 0.85x-1.3x instead of the full range some OSes allow (which
/// can exceed 2x). Below 0.85x text starts reading as illegibly small on a
/// design already using 10-11px labels; above 1.3x, single-line elements
/// that aren't wrapped in a shrink-to-fit affordance (unlike
/// `BottomNavBar`'s nav labels, which use `FittedBox` specifically so they
/// can't overflow) would start clipping/overlapping on top of every other
/// per-device-size issue this app already has to handle. A hard clamp is a
/// deliberate accessibility trade-off, not an oversight — flagged as such
/// rather than silently applied.
Widget _clampTextScale(BuildContext context, Widget child) {
  final clamped = MediaQuery.textScalerOf(
    context,
  ).clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3);
  return MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: clamped),
    child: child,
  );
}
