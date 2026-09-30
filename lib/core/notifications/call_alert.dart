import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/chat/data/datasources/chat_remote_datasource.dart' show ChatRoutes;
import '../../features/notification/domain/entities/notification_entity.dart';
import '../config/app_config.dart';
import '../security/secure_storage_service.dart';
import '../utils/logger.dart';
import 'background_auth.dart';
import 'push_notification_service.dart' show chatAlertDetails;

/// The incoming-call ring for a phone whose app is not on screen — the three
/// call pushes of `yello-notify` (see `docs/BACKEND.md`).
///
/// On Android the pushes arrive **data-only**, so the app draws the ring
/// itself: that is the only way a backgrounded or killed app gets Accept and
/// Decline onto it (docs/GOTCHAS.md). With the app on screen nothing is
/// drawn — the chat socket's `call.ringing` already rings in the app, and the
/// push is the same call again.
///
/// On iOS the ring is an alert iOS draws from the APNs payload; tapping it
/// opens the app, whose socket recovery puts the call on screen. Its Accept /
/// Decline buttons are not wired: `flutter_local_notifications` ignores the
/// response to any alert it did not draw, and `firebase_messaging` reports a
/// button as a plain open, so a Decline there would open the app and decline
/// nothing. That needs native `AppDelegate` code — see ADR-051.

/// Accept on the ring. Brings the app forward (`showsUserInterface`), so on
/// Android it reaches `onDidReceiveNotificationResponse` in the main isolate
/// — unlike Decline, which never needs the app.
const String acceptCallActionId = 'yello.call.accept';

/// Decline on the ring. Runs in the plugin's background engine and declines
/// over HTTP, with no socket and no app on screen.
const String declineCallActionId = 'yello.call.decline';

/// The ringing channel, apart from `yello_default` so it can ring like a
/// phone call: the device's ringtone, at ringtone volume, and `max`
/// importance for the full-screen / heads-up treatment. A channel's sound
/// and importance are fixed once created, which is why this is its own id
/// rather than a setting on the existing one. Not `yello_calls`: that is
/// `CallService.kt`'s quiet ongoing-call channel, and reusing its id keeps
/// *its* low importance and no sound (docs/GOTCHAS.md).
const AndroidNotificationChannel callAlertChannel = AndroidNotificationChannel(
  'yello_incoming_calls',
  'Incoming calls',
  description: 'Rings for voice and video calls while Yello is in the background or closed.',
  importance: Importance.max,
  sound: UriAndroidNotificationSound('content://settings/system/ringtone'),
  audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
);

/// `Notification.FLAG_INSISTENT`: the sound loops until the ring is answered,
/// declined, taken down, or times out — instead of playing once.
const int _flagInsistent = 4;

/// The server stops ringing 45 s after the call starts; used only when a push
/// arrives without a readable `expiresAt`.
const Duration _defaultRing = Duration(seconds: 45);

/// One id per call, shared by the ring and the missed-call alert that
/// replaces it, and **untagged**: an action that opens the app is cancelled
/// by the plugin by id alone, so a tag would leave the ring sounding after
/// Accept.
int callAlertId(String callId) => 'call:$callId'.hashCode;

String? _read(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// The call id a call push or a call alert's payload names.
String? callIdOf(Map<String, dynamic> data) => _read(data, 'callId');

bool isCallPush(Map<String, dynamic> data) {
  final type = data['type'];
  return type == NotificationTypes.callIncoming ||
      type == NotificationTypes.callMissed ||
      type == NotificationTypes.callRingStopped;
}

/// Acts on one of the three call pushes, in whichever isolate it arrived.
///
/// [appOnScreen] is true for a push `FirebaseMessaging.onMessage` delivered:
/// the socket is already ringing in the app, so no ring is drawn.
/// [osDrewIt] is true when the push carried its own `notification` block —
/// iOS has already shown it, and drawing again would double it.
Future<void> handleCallPush(
  FlutterLocalNotificationsPlugin local,
  Map<String, dynamic> data, {
  required bool appOnScreen,
  bool osDrewIt = false,
}) async {
  final callId = callIdOf(data);
  if (callId == null) return;
  switch (data['type']) {
    case NotificationTypes.callIncoming:
      if (appOnScreen || osDrewIt) return;
      await _showRing(local, callId, data);
    case NotificationTypes.callMissed:
      await cancelCallAlert(local, callId);
      if (osDrewIt) return;
      final body = _read(data, 'body') ?? 'Missed call';
      await local.show(
        id: callAlertId(callId),
        title: _read(data, 'title'),
        body: body,
        payload: jsonEncode(data),
        notificationDetails: chatAlertDetails(tag: null, replyable: false, title: _read(data, 'title'), body: body),
      );
    case NotificationTypes.callRingStopped:
      // Always safe to take down: when *this* device is the one that
      // answered, the call's own notification is `CallService`'s, not this.
      await cancelCallAlert(local, callId);
  }
}

Future<void> _showRing(FlutterLocalNotificationsPlugin local, String callId, Map<String, dynamic> data) async {
  final expiresAt = DateTime.tryParse(_read(data, 'expiresAt') ?? '');
  final left = expiresAt == null ? _defaultRing : expiresAt.difference(DateTime.now());
  // Never ring for a call that is already over — a push held up in transit
  // can land after its ring has ended.
  if (left <= Duration.zero) return;

  // Created on first use too: this may be the background engine, and a
  // channel has to exist before a notification can name it. A no-op when it
  // already does.
  await local
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(callAlertChannel);
  await local.show(
    id: callAlertId(callId),
    title: _read(data, 'title') ?? 'Incoming call',
    body: _read(data, 'body'),
    payload: jsonEncode(data),
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        callAlertChannel.id,
        callAlertChannel.name,
        channelDescription: callAlertChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        // Wakes a locked phone to the ring; unlocked, it shows as a heads-up
        // that stays up instead of folding into the shade.
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        // Stops by itself when the server stops ringing, whether or not the
        // CALL_MISSED push that follows makes it here.
        timeoutAfter: left.inMilliseconds,
        additionalFlags: Int32List.fromList(const [_flagInsistent]),
        actions: const [
          AndroidNotificationAction(declineCallActionId, 'Decline', showsUserInterface: false),
          AndroidNotificationAction(acceptCallActionId, 'Accept', showsUserInterface: true),
        ],
      ),
    ),
  );
}

/// Takes the ring (or the missed-call alert) for [callId] down. Only alerts
/// this app drew: iOS exposes no id for one it drew from APNs, and the
/// missed-call push replaces that one by collapse id on its own.
Future<void> cancelCallAlert(FlutterLocalNotificationsPlugin local, String callId) async {
  try {
    await local.cancel(id: callAlertId(callId));
  } catch (e) {
    appLogger.w('cancelCallAlert($callId) failed — $e');
  }
}

/// Decline pressed on the ring: `POST /ws/calls/{id}/decline`, with the app
/// closed. Every answer but a 401 means there is nothing left to do — `204`
/// declined, `409` no longer ringing (answered elsewhere, missed, ended),
/// `404` unknown, `403` the viewer placed the call — so only a 401 is retried,
/// once, after a refresh. A network failure is not retried either: the ring
/// is already gone from this phone, and the server's own timeout ends it for
/// the caller as a missed call.
Future<void> declineCallFromNotification(String callId) async {
  final storage = SecureStorageServiceImpl();
  var token = await backgroundAccessToken(storage);
  if (token == null) return;
  final dio = backgroundDio();
  try {
    try {
      await _decline(dio, callId, token);
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) return _logDeclineFailure(e);
      token = await refreshedAccessToken(storage);
      if (token == null) return;
      await _decline(dio, callId, token);
    }
  } on DioException catch (e) {
    _logDeclineFailure(e);
  } finally {
    dio.close();
  }
}

Future<void> _decline(Dio dio, String callId, String token) =>
    dio.post<void>(ChatRoutes.declineCall(callId), options: bearer(token));

void _logDeclineFailure(DioException e) {
  final status = e.response?.statusCode;
  if (status == 409 || status == 404) return; // the call had already moved on — nothing failed
  final detail = AppConfig.enableLogging ? ' — ${e.response?.data ?? e.message}' : '';
  appLogger.w('Notification decline failed: ${e.type.name}${status == null ? '' : ' HTTP $status'}$detail');
}
