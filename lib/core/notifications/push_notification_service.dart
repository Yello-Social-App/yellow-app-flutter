import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/notification/domain/entities/notification_entity.dart';
import '../../features/notification/domain/usecases/notification_usecases.dart';
import '../constants/app_constants.dart';
import '../security/secure_storage_service.dart';
import '../utils/logger.dart';

/// Channel every push is shown under on Android. `yello_default` is the id
/// `yello-notify`'s own guide names, and it must match
/// `AndroidManifest.xml`'s `default_notification_channel_id` meta-data —
/// that value is what the OS uses to draw a backgrounded/killed-app
/// notification straight from the FCM payload, without ever running Dart
/// code, so the three have to agree on the same id.
const _androidChannel = AndroidNotificationChannel(
  'yello_default',
  'Yello notifications',
  description:
      'Chat messages, reactions, friend requests, and other Yello activity.',
  importance: Importance
      .high, // required for a heads-up pop, not just a silent tray entry
);

/// Where a tapped push should take the user, worked out from its `data`
/// map in the order the notify guide fixes: a conversation first, then a
/// post (optionally at a comment), then a profile. Anything else is an
/// unknown type and is ignored — new types are added over time.
sealed class PushDestination {
  const PushDestination();

  static PushDestination? fromData(Map<String, dynamic> data) {
    String? read(String key) {
      final value = data[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    // Keyed off `type`, not off an id, so it has to be checked before the
    // id ladder below: a resolved report carries `reportId`/`status` and
    // none of the ids that ladder looks for, and its destination is a
    // screen rather than one of the things those ids name.
    if (read('type') == NotificationTypes.reportResolved) {
      return ReportsDestination(reportId: read('reportId'));
    }
    final conversationId = read('conversationId');
    if (conversationId != null) {
      return ConversationDestination(conversationId: conversationId, messageId: read('messageId'));
    }
    final postId = read('postId');
    if (postId != null) return PostDestination(postId: postId, commentId: read('commentId'));
    final actorId = read('actorId');
    if (actorId != null) return ProfileDestination(userId: actorId);
    return null;
  }
}

class ConversationDestination extends PushDestination {
  const ConversationDestination({required this.conversationId, this.messageId});
  final String conversationId;

  /// Present on chat pushes; the transcript has no scroll-to-message yet,
  /// so it is carried for when it does.
  final String? messageId;
}

class PostDestination extends PushDestination {
  const PostDestination({required this.postId, this.commentId});
  final String postId;

  /// Set on comment / reply / comment-reaction pushes. The post screen has
  /// no scroll-to-comment yet; the post itself opens.
  final String? commentId;
}

class ProfileDestination extends PushDestination {
  const ProfileDestination({required this.userId});
  final String userId;
}

/// A `REPORT_RESOLVED` push — opens Privacy & safety, whose "Your reports"
/// list re-reads `GET /v1/reports/me` for the outcome. There is no
/// per-report screen to open: the push deliberately carries nothing about
/// the post or its author, so [reportId] is only useful for highlighting a
/// row and is carried for when that lands.
class ReportsDestination extends PushDestination {
  const ReportsDestination({this.reportId});
  final String? reportId;
}

/// Wires Firebase Cloud Messaging: requests notification permission, keeps
/// the backend's device-token registration (`RegisterDeviceUseCase` —
/// `LogoutUseCase` already reads [AppConstants.secureKeyPushToken] back to
/// unregister it on sign-out) in sync with the current FCM token, shows the
/// notification manually while the app is foregrounded — FCM only auto-pops
/// a system notification when the app is backgrounded or killed — and
/// takes an alert down again when its chat message is unsent.
abstract interface class PushNotificationService {
  Future<void> init();

  /// Fires whenever a push arrives or is tapped — the shell refreshes the
  /// inbox and Signals counts on it.
  Stream<void> get updates;

  /// Fires when a push is tapped and a destination was parsed from it;
  /// read it with [takePendingDestination].
  Stream<void> get notificationTaps;

  /// The other party's user id, each time a silent `FRIENDSHIP_CHANGED`
  /// push arrives — someone unfriended the viewer, declined their request,
  /// or cancelled one they had sent.
  ///
  /// A separate stream from [updates] because nothing the shell refreshes
  /// (the inbox, the Signals count) is affected by it: the screens that
  /// *are* — the Circle tab and whichever profile is open — listen for
  /// themselves while mounted, since both own factory Cubits the shell has
  /// no handle on. Foreground only: a push that arrives while the app is
  /// backgrounded runs no Dart here, so the affected screen reloads on its
  /// own next `load()` instead.
  Stream<String> get friendshipChanges;

  /// The destination of the last tapped push, once. Null when there is
  /// none pending or the tap carried no recognised deep link.
  PushDestination? takePendingDestination();
}

class PushNotificationServiceImpl implements PushNotificationService {
  PushNotificationServiceImpl(this._registerDevice, this._secureStorage);

  final RegisterDeviceUseCase _registerDevice;
  final SecureStorageService _secureStorage;
  final _updates = StreamController<void>.broadcast();
  final _notificationTaps = StreamController<void>.broadcast();
  final _friendshipChanges = StreamController<String>.broadcast();
  PushDestination? _pendingDestination;

  /// Which message the alert shown *by this isolate* under each chat tag is
  /// for — what lets a `CHAT_MESSAGE_DELETED` push leave a newer message's
  /// alert alone. An OS-drawn alert (background push) has no entry here.
  final Map<String, String> _shownChatMessages = {};

  @override
  Stream<void> get notificationTaps => _notificationTaps.stream;

  @override
  Stream<String> get friendshipChanges => _friendshipChanges.stream;

  @override
  PushDestination? takePendingDestination() {
    final destination = _pendingDestination;
    _pendingDestination = null;
    return destination;
  }

  void _handleTap(Map<String, dynamic> data) {
    _updates.add(null);
    final destination = PushDestination.fromData(data);
    if (destination == null) return;
    _pendingDestination = destination;
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
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
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

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    _updates.add(null);
    final data = message.data;
    if (data['type'] == NotificationTypes.chatMessageDeleted) {
      await _onChatMessageDeleted(data);
      return;
    }
    if (data['type'] == NotificationTypes.friendshipChanged) {
      final userId = data['userId'];
      if (userId is String && userId.isNotEmpty) _friendshipChanges.add(userId);
      return;
    }
    final notification = message.notification;
    if (notification == null) return; // data-only payload — nothing to pop here

    // The grouping key: a newer push for the same key *replaces* the older
    // one on Android (tag) and threads under it on iOS. For a chat push it
    // is rebuilt from `data` — the same derivation the unsend handler uses
    // to find the alert again — and for everything else it is whatever tag
    // the server put on the Android block (per post, per comment, per
    // sender).
    final conversationTag = chatNotificationTag(data);
    final tag = conversationTag ?? message.notification?.android?.tag;
    if (conversationTag != null && data['messageId'] is String) {
      _shownChatMessages[conversationTag] = data['messageId'] as String;
    }

    await _local.show(
      // Stable per key so a re-show under the same tag replaces, not stacks.
      id: tag?.hashCode ?? notification.hashCode,
      title: notification.title,
      body: notification.body,
      payload: jsonEncode(data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          tag: tag,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          threadIdentifier: tag,
        ),
      ),
    );
  }

  /// A data-only push: someone unsent a chat message and the alert shown
  /// for it must come down. When this isolate showed it, the tag → message
  /// record says whether the alert on screen is for *this* message; an
  /// OS-drawn alert keeps no such record and is taken down on the
  /// conversation alone — a stale alert for an unsent message is exactly
  /// what the contract exists to prevent.
  Future<void> _onChatMessageDeleted(Map<String, dynamic> data) async {
    final tag = chatNotificationTag(data);
    final messageId = data['messageId'];
    if (tag == null || messageId is! String) return;
    final shownFor = _shownChatMessages[tag];
    if (shownFor != null && shownFor != messageId) return;
    _shownChatMessages.remove(tag);
    await cancelChatNotification(_local, tag);
  }
}

/// `chat:<conversationId>` — the tag `yello-notify` files every chat push
/// under, and the key the unsend handler cancels by. Null for anything
/// that is not a chat push.
String? chatNotificationTag(Map<String, dynamic> data) {
  final type = data['type'];
  if (type != NotificationTypes.chatMessage && type != NotificationTypes.chatMessageDeleted) return null;
  final conversationId = data['conversationId'];
  if (conversationId is! String || conversationId.isEmpty) return null;
  return 'chat:$conversationId';
}

/// Takes down whatever is showing under [tag]. On Android that is by
/// (id, tag): an OS-drawn FCM alert sits at id `0`, one shown by
/// `_onForegroundMessage` at the tag's hash — both are tried, plus anything
/// `getActiveNotifications` reports under the tag. iOS exposes no id for an
/// OS-drawn alert, so only locally shown ones can be removed there — the
/// best effort the notify guide asks for.
Future<void> cancelChatNotification(FlutterLocalNotificationsPlugin local, String tag) async {
  try {
    final active = await local.getActiveNotifications();
    for (final n in active) {
      if (n.tag == tag || n.groupKey == tag) await local.cancel(id: n.id ?? 0, tag: tag);
    }
    await local.cancel(id: 0, tag: tag);
    await local.cancel(id: tag.hashCode, tag: tag);
  } catch (e) {
    appLogger.w('cancelChatNotification($tag) failed — $e');
  }
}

/// Top-level per the plugin's requirement — it must be callable in its own
/// background isolate, so this can never be a class method. That isolate
/// starts with none of `bootstrap()`'s state, hence the fresh
/// `Firebase.initializeApp()`. The OS has already drawn any *visible* push
/// from its payload by the time this fires; the one thing that needs Dart
/// here is the silent `CHAT_MESSAGE_DELETED` push, which carries no
/// notification block and exists only so the app can take the earlier
/// alert down (Android delivers it at high priority even in the background;
/// iOS may delay or drop it).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final data = message.data;
  if (data['type'] != NotificationTypes.chatMessageDeleted) return;
  final tag = chatNotificationTag(data);
  if (tag == null) return;
  await cancelChatNotification(FlutterLocalNotificationsPlugin(), tag);
}
