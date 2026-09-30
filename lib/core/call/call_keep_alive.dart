import 'dart:io';

import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Keeps a call working while nobody is looking at it, over the `yello/call`
/// channel (`MainActivity.kt`, `CallService.kt`).
///
/// Android silences an app's microphone soon after it leaves the screen —
/// the display timing out mid-call is enough — unless a *microphone*
/// foreground service is running. [hold] starts one, with the ongoing "call
/// in progress" notification the OS requires; [release] stops it. A video
/// call also keeps the screen awake, since nobody touches the phone while
/// they watch it.
///
/// Sharing the screen needs the same service to also carry the
/// `mediaProjection` type while it lasts — Android refuses to hand over a
/// screen capture otherwise. [setScreenCapture] re-promotes it either way.
///
/// Android only. iOS keeps call audio through the `audio` background mode in
/// `Info.plist` and needs nothing from here; its screen still auto-locks
/// during a video call (no counterpart is written for it yet).
class CallKeepAlive {
  CallKeepAlive({MethodChannel? channel, bool? isAndroid})
    : _channel = channel ?? const MethodChannel('yello/call'),
      _isAndroid = isAndroid ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool _isAndroid;

  bool _serviceRunning = false;
  bool _screenOn = false;
  bool _screenCapture = false;
  String _title = 'Yello call';

  /// Idempotent — call it at every step of a call that might now succeed.
  /// The service cannot start before the microphone permission is granted
  /// (a first call asks for it only once it publishes), so an early refusal
  /// is expected and the next [hold] tries again.
  Future<void> hold({required String title, required bool keepScreenOn}) async {
    if (!_isAndroid) return;
    _title = title;
    if (!_serviceRunning) {
      _serviceRunning = await _start();
    }
    if (keepScreenOn != _screenOn) {
      _screenOn = keepScreenOn;
      await _invoke<void>('setKeepScreenOn', {'on': keepScreenOn});
    }
  }

  /// Adds the `mediaProjection` type to the service, or takes it away.
  /// Turning it on must come *after* the user allowed the capture (Android
  /// 14 refuses the type before that) and before the capture starts. False
  /// when the service could not carry it — the share must not start then.
  Future<bool> setScreenCapture(bool on) async {
    if (!_isAndroid) return false;
    if (on == _screenCapture && (_serviceRunning || !on)) return true;
    _screenCapture = on;
    final started = await _start();
    _serviceRunning = started || _serviceRunning;
    if (!started && on) _screenCapture = false;
    return started;
  }

  Future<void> release() async {
    if (!_isAndroid) return;
    _screenCapture = false;
    if (_serviceRunning) {
      _serviceRunning = false;
      await _invoke<void>('stopCallService');
    }
    if (_screenOn) {
      _screenOn = false;
      await _invoke<void>('setKeepScreenOn', {'on': false});
    }
  }

  /// Starting a running service re-promotes it with the types asked for.
  Future<bool> _start() async =>
      await _invoke<bool>('startCallService', {'title': _title, 'screenCapture': _screenCapture}) ?? false;

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on Object catch (e) {
      appLogger.w('CallKeepAlive: $method failed — $e');
      return null;
    }
  }
}
