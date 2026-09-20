import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/notification/domain/usecases/notification_usecases.dart';
import '../constants/app_constants.dart';
import '../security/secure_storage_service.dart';
import '../utils/logger.dart';

/// Channel every push is shown under on Android. Must match
/// `AndroidManifest.xml`'s `default_notification_channel_id` meta-data — that
/// value is what the OS uses to draw a backgrounded/killed-app notification
/// straight from the FCM payload, without ever running Dart code, so the two
/// have to agree on the same id.
const _androidChannel = AndroidNotificationChannel(
  'yello_default_channel',
  'Yello notifications',
  description:
      'Chat messages, reactions, friend requests, and other Yello activity.',
  importance: Importance
      .high, // required for a heads-up pop, not just a silent tray entry
);

/// Wires Firebase Cloud Messaging: requests notification permission, keeps
/// the backend's device-token registration (`RegisterDeviceUseCase` —
/// `LogoutUseCase` already reads [AppConstants.secureKeyPushToken] back to
/// unregister it on sign-out) in sync with the current FCM token, and shows
/// the notification manually while the app is foregrounded — FCM only
/// auto-pops a system notification when the app is backgrounded or killed.
abstract interface class PushNotificationService {
  Future<void> init();
  Stream<void> get updates;
  Stream<void> get notificationTaps;
  String? takePendingConversationId();
}

class PushNotificationServiceImpl implements PushNotificationService {
  PushNotificationServiceImpl(this._registerDevice, this._secureStorage);

  final RegisterDeviceUseCase _registerDevice;
  final SecureStorageService _secureStorage;
  final _updates = StreamController<void>.broadcast();
  final _notificationTaps = StreamController<void>.broadcast();
  String? _pendingConversationId;

  @override
  Stream<void> get notificationTaps => _notificationTaps.stream;

  @override
  String? takePendingConversationId() {
    final id = _pendingConversationId;
    _pendingConversationId = null;
    return id;
  }

  void _handleTap(Map<String, dynamic> data) {
    _updates.add(null);
    final id = data['conversationId'];
    if (id is! String || id.trim().isEmpty) return;
    _pendingConversationId = id.trim();
    _notificationTaps.add(null);
  }

  void _handleLocalTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) _handleTap(data);
    } on FormatException {
      appLogger.w('Ignoring invalid notification navigation payload.');
    }
  }

  @override
  Stream<void> get updates => _updates.stream;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static String get _platform => Platform.isIOS ? 'ios' : 'android';

  @override
  Future<void> init() async {
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _handleLocalTap,
    );

    FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleTap(message.data));
    // Save cold-start destinations until the authenticated shell is ready.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleTap(initialMessage.data);
    final localLaunch = await _local.getNotificationAppLaunchDetails();
    if (localLaunch?.didNotificationLaunchApp == true && localLaunch?.notificationResponse != null) {
      _handleLocalTap(localLaunch!.notificationResponse!);
    }

    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      appLogger.w(
        'PushNotificationService: permission denied — push disabled for this session.',
      );
      return;
    }

    if (Platform.isIOS) {
      // Must resolve before `getToken()` on iOS, or the FCM token comes back
      // null while the native APNs registration is still in flight.
      await FirebaseMessaging.instance.getAPNSToken();
    }

    final token = await FirebaseMessaging.instance.getToken();
    // Debug-only visibility (filtered out in release by `appLogger`'s own
    // filter — see core/utils/logger.dart) — paste this into the Firebase
    // console's Cloud Messaging > "Send test message" dialog to pop a real
    // notification on this exact device without waiting on the backend.
    appLogger.i('PushNotificationService: FCM token → $token');
    if (token != null) await _syncToken(token);
    FirebaseMessaging.instance.onTokenRefresh.listen(_syncToken);

    // Background/terminated pushes are drawn by the OS straight from the FCM
    // payload's `notification` block — see `firebaseMessagingBackgroundHandler`
    // below for why nothing needs to happen here for that case.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  Future<void> _syncToken(String token) async {
    final previous = await _secureStorage.read(AppConstants.secureKeyPushToken);
    if (previous == token) {
      return; // already registered — avoid a PUT on every cold start
    }

    final result = await _registerDevice(
      RegisterDeviceParams(token: token, platform: _platform),
    );
    result.fold(
      (failure) => appLogger.w(
        'PushNotificationService: registerDevice failed — ${failure.message}',
      ),
      (_) => _secureStorage.write(AppConstants.secureKeyPushToken, token),
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    _updates.add(null);
    final notification = message.notification;
    if (notification == null) return; // data-only payload — nothing to pop here
    await _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      payload: jsonEncode(message.data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}

/// Top-level per the plugin's requirement — it must be callable in its own
/// background isolate, so this can never be a class method. That isolate
/// starts with none of `bootstrap()`'s state, hence the fresh
/// `Firebase.initializeApp()`; nothing else runs here because the OS has
/// already drawn the system notification from the payload by the time this
/// fires — this hook is for background *data* processing, not display.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
