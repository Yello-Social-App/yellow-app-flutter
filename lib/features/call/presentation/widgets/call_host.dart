import 'dart:async';

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/security/session_manager.dart';
import '../bloc/call_cubit.dart';
import 'call_screen.dart';

/// Puts the call UI above the whole app — above the router, not on a route.
///
/// A call is not a place the user navigates to: it can ring on any tab, over
/// any pushed screen, and has to survive whatever navigation happens under it
/// (a push deep link resets the stack with `goNamed`, which would tear a call
/// *route* down mid-call). So it sits beside the router's output in a
/// [Stack], full screen while it has the user's attention and a pill at the
/// top once minimized, with the app usable underneath.
///
/// Two things a route would have got for free are done here by hand:
///
/// - **Back.** A [ChildBackButtonDispatcher] with priority over the router
///   turns Back on the full-screen call into "minimize", instead of popping
///   (or leaving) the app hidden underneath.
/// - **Predictive back.** Android asks the framework up front whether it will
///   handle Back, and the router answers for its routes only — on the Feed
///   tab that answer is "no", and Back would close the app from under a
///   ringing phone. The router's [NavigationNotification]s are caught on
///   their way up and re-sent with the call's own answer folded in.
///
/// It also decides when `CallCubit` holds the socket: signed in and on
/// screen. See [CallCubit.setListening].
class CallHost extends StatefulWidget {
  const CallHost({super.key, required this.child});

  final Widget child;

  @override
  State<CallHost> createState() => _CallHostState();
}

class _CallHostState extends State<CallHost> with WidgetsBindingObserver {
  final CallCubit _cubit = sl<CallCubit>();
  late final ChildBackButtonDispatcher _back;
  StreamSubscription<SessionState>? _session;
  StreamSubscription<void>? _callAnswers;
  final PushNotificationService _push = sl<PushNotificationService>();

  /// What the router last said about Back, before the call is folded in.
  bool _routesCanPop = false;
  bool _expanded = false;

  static bool _isExpanded(CallState state) => state.isVisible && !state.isMinimized;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = sl<SessionManager>().sessionState.listen((_) => _syncListening());
    _back = sl<AppRouter>().router.backButtonDispatcher.createChildBackButtonDispatcher()..addCallback(_onBack);
    _takeBackPriority();
    _callAnswers = _push.callAnswers.listen((_) => _takeCallAnswer());
    // After the first frame, for the same reason as `MainShellPage`'s
    // presence lease: a session restore may still be settling in initState.
    // The pending answer is taken after listening starts: Accept on a ring
    // may be what launched the app, before this widget existed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncListening();
      _takeCallAnswer();
    });
  }

  void _takeCallAnswer() {
    final callId = _push.takePendingCallAnswer();
    if (callId != null) _cubit.answerFromNotification(callId);
  }

  /// `takePriority` asserts that the root dispatcher already has a callback,
  /// and the root only gets one when the `Router` builds — which is *below*
  /// this widget, so after this `initState`. Wait for a frame in which the
  /// router has registered.
  void _takeBackPriority() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_back.parent.hasCallbacks) {
        _back.takePriority();
      } else {
        _takeBackPriority();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncListening();

  /// `inactive` counts as on screen: it is also what a permission prompt or
  /// the notification shade does to the app, and dropping the socket for
  /// either would cost a reconnect for nothing.
  void _syncListening() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final onScreen =
        lifecycle == null || lifecycle == AppLifecycleState.resumed || lifecycle == AppLifecycleState.inactive;
    final signedIn = sl<SessionManager>().currentState == SessionState.authenticated;
    _cubit.setListening(onScreen && signedIn);
  }

  Future<bool> _onBack() {
    if (!_isExpanded(_cubit.state)) return SynchronousFuture(false);
    _cubit.minimize();
    return SynchronousFuture(true);
  }

  bool _onNavigation(NavigationNotification notification) {
    _routesCanPop = notification.canHandlePop;
    _reportCanPop();
    return true;
  }

  void _reportCanPop() {
    if (!mounted) return;
    NavigationNotification(canHandlePop: _routesCanPop || _expanded).dispatch(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session?.cancel();
    _callAnswers?.cancel();
    _back.removeCallback(_onBack);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CallCubit>.value(
      value: _cubit,
      child: MultiBlocListener(
        listeners: [
          BlocListener<CallCubit, CallState>(
            listenWhen: (previous, current) => _isExpanded(previous) != _isExpanded(current),
            listener: (context, state) {
              _expanded = _isExpanded(state);
              // A call taking the screen closes whatever keyboard was up under
              // it — the chat composer, most often.
              if (_expanded) FocusManager.instance.primaryFocus?.unfocus();
              _reportCanPop();
            },
          ),
          // A call the app now has on screen no longer needs the ring drawn
          // while it was away — opened from the launcher rather than the
          // notification, that ring would otherwise sound on over the app's.
          // Live phases only: a CALL_MISSED alert can land after the ended
          // screen, and must stay.
          BlocListener<CallCubit, CallState>(
            listenWhen: (previous, current) =>
                current.isLive && current.call != null && previous.call?.id != current.call?.id,
            listener: (context, state) => _push.dismissCallAlert(state.call!.id),
          ),
        ],
        child: NotificationListener<NavigationNotification>(
          onNotification: _onNavigation,
          child: Stack(
            children: [
              widget.child,
              BlocBuilder<CallCubit, CallState>(
                buildWhen: (previous, current) =>
                    previous.isVisible != current.isVisible || previous.isMinimized != current.isMinimized,
                builder: (context, state) {
                  if (!state.isVisible) return const SizedBox.shrink();
                  if (state.isMinimized) {
                    return const Positioned(top: 0, left: 0, right: 0, child: CallPill());
                  }
                  return const Positioned.fill(child: CallScreen());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
