import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a plain `Stream` (here, `SessionManager.sessionState`) to the
/// `Listenable` go_router's `refreshListenable` wants — so a session
/// dying underneath the user (forced logout from `AuthInterceptor`, not a
/// navigation the user triggered) still re-runs `RouteGuards.redirect` and
/// bounces them to `/login` immediately, instead of only on their next tap.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
