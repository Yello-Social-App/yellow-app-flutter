import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/di/injection.dart';
import 'core/security/root_jailbreak_detector.dart';
import 'core/security/session_manager.dart';
import 'core/utils/logger.dart';
import 'features/chat/data/datasources/user_directory.dart';
import 'features/chat/presentation/bloc/messages_cubit.dart';
import 'features/feed/presentation/bloc/feed_cubit.dart';

/// The app's single startup sequence: set app config, wire DI, resolve the
/// initial session, run the device-integrity check, then hand off to
/// [YelloApp] (or [SecurityBlockedApp] — see its doc).
///
/// Order matters: [AppConfig.init] must run before [configureDependencies]
/// because [ApiClient] reads `AppConfig.baseUrl` at construction time
/// (`sl<ApiClient>()` is lazy, but nothing stops an early resolution).
Future<void> bootstrap({required String baseUrl}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Every screen in this app (stories, the floating bottom nav, the feed
  // app bar, the profile header's overlap layout) is hand-positioned for
  // portrait only and has never been designed or verified in landscape —
  // rotating would visibly break several of them. Locking here (before the
  // first frame) is what actually keeps the app "responsive to size of
  // device" rather than just "responsive to portrait phone widths": it
  // removes the one dimension of device variation nothing in this codebase
  // accounts for. Mirrored natively in `AndroidManifest.xml`
  // (`android:screenOrientation="portrait"`) and `ios/Runner/Info.plist`
  // (`UISupportedInterfaceOrientations`, iPhone entry only) so the lock
  // holds from the very first native frame, not just once Flutter takes
  // over.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  AppConfig.init(baseUrl: baseUrl);

  await configureDependencies();

  // Every logout path (see `AuthRepositoryImpl.logout`) ends in
  // `SessionManager.endSession()` firing this — the one point in the app
  // that reliably knows the signed-in identity is about to change. Reset
  // every long-lived, per-account singleton Cubit here rather than at each
  // logout call site, so a future new one can't forget to do it.
  sl<SessionManager>().sessionState.listen((state) {
    if (state == SessionState.unauthenticated) {
      sl<FeedCubit>().reset();
      sl<MessagesCubit>().reset();
      // Chat participant names/avatars are cached per session — dropping
      // them here stops the next account seeing the previous one's contacts.
      sl<UserDirectory>().clear();
    }
  });

  await sl<SessionManager>().bootstrap();

  final integrity = await sl<RootJailbreakDetector>().check();
  if (integrity.shouldBlockLaunch) {
    appLogger.w('Device failed integrity check — refusing to launch.');
    runApp(const SecurityBlockedApp());
    return;
  }

  runApp(const YelloApp());
}
