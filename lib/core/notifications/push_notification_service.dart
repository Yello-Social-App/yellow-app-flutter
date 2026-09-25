import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/notification/domain/entities/notification_entity.dart';
import '../../features/notification/domain/usecases/notification_usecases.dart';
import '../constants/app_constants.dart';
import '../security/secure_storage_service.dart';
import '../utils/logger.dart';
import 'chat_reply_action.dart';

/// Channel every push is shown under on Android. `yello_default` is the id
/// `yello-notify`'s own guide names, and it must match
/// `AndroidManifest.xml`'s `default_notification_channel_id` meta-data —
/// that value is what the OS uses to draw a backgrounded/killed-app
/// notification straight from the FCM payload, without ever running Dart
/// code, so the three have to agree on the same id.
const _androidChannel = AndroidNotificationChannel(
  'yello_default',
  'Yello notifications',
  description: 'Chat messages, reactions, friend requests, and other Yello activity.',
  importance: Importance.high, // required for a heads-up pop, not just a silent tray entry
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
/// a system notification when the app is backgrounded or killed — takes an
/// alert down again when its chat message is unsent, and answers the Reply
/// action on a chat alert without the app coming forward (ADR-025).
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

  /// A response to an alert this isolate drew: the Reply action answers the
  /// conversation in place, anything else is an ordinary tap.
  Future<void> _handleLocalResponse(NotificationResponse response) async {
    final data = decodeNotificationPayload(response.payload);
    if (data == null) return;
    if (response.actionId != chatReplyActionId) {
      _handleTap(data);
      return;
    }
    // Reached on iOS, where the delegate answers in this isolate. On
    // Android an action tap *never* arrives here — see [_replyPortName] —
    // so the refresh is left to the port rather than done inline.
    await replyFromNotification(_local, data: data, text: response.input ?? '');
  }

  @override
  Stream<void> get updates => _updates.stream;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  static String get _platform => Platform.isIOS ? 'ios' : 'android';

  @override
  Future<void> init() async {
    // Republished on every init: a mapping can outlive the process that
    // made it, and `registerPortWithName` refuses to overwrite one.
    IsolateNameServer.removePortNameMapping(_replyPortName);
    // An open ReceivePort is held by the VM's own port map, so a local is
    // enough to keep it alive for the process.
    final replyPort = ReceivePort();
    IsolateNameServer.registerPortWithName(replyPort.sendPort, _replyPortName);
    // A reply sent from the notification bypassed ChatCubit's own send path,
    // so nothing on screen knows about it: the open transcript and the
    // inbox counts refresh off this.
    replyPort.listen((_) => _updates.add(null));

    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
    await _local.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        // The reply category has to exist before any alert names it, and
        // registering it here is also what lets an iOS-drawn push carry the
        // reply field — provided the APNs payload sets `aps.category` to
        // [chatReplyCategoryId]. See docs/BACKEND.md.
        iOS: DarwinInitializationSettings(notificationCategories: [chatReplyCategory]),
      ),
      onDidReceiveNotificationResponse: _handleLocalResponse,
      // Fires in the plugin's own engine when the reply was typed while
      // this isolate was gone — see [notificationReplyBackgroundHandler].
      onDidReceiveBackgroundNotificationResponse: notificationReplyBackgroundHandler,
    );

    FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleTap(message.data));
    // Save cold-start destinations until the authenticated shell is ready.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleTap(initialMessage.data);
    final localLaunch = await _local.getNotificationAppLaunchDetails();
    if (localLaunch?.didNotificationLaunchApp == true && localLaunch?.notificationResponse != null) {
      await _handleLocalResponse(localLaunch!.notificationResponse!);
    }

    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      appLogger.w('PushNotificationService: permission denied — push disabled for this session.');
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

    final result = await _registerDevice(RegisterDeviceParams(token: token, platform: _platform));
    result.fold(
      (failure) => appLogger.w('PushNotificationService: registerDevice failed — ${failure.message}'),
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
    // The grouping key: a newer push for the same key *replaces* the older
    // one on Android (tag) and threads under it on iOS. For a chat push it
    // is rebuilt from `data` — the same derivation the unsend handler uses
    // to find the alert again — and for everything else it is whatever tag
    // the server put on the Android block (per post, per comment, per
    // sender).
    final conversationTag = chatNotificationTag(data);
    final notification = message.notification;
    // A chat push may also arrive *data-only*, so that the app draws it
    // itself and can hang the Reply action off it (the reason the copy is
    // repeated in `data` at all — see docs/BACKEND.md). Anything else
    // data-only has nothing to pop.
    if (notification == null && conversationTag == null) return;
    final title = notification?.title ?? _copy(data, 'title');
    final body = notification?.body ?? _copy(data, 'body');
    if (title == null && body == null) return;

    final tag = conversationTag ?? notification?.android?.tag;
    if (conversationTag != null && data['messageId'] is String) {
      _shownChatMessages[conversationTag] = data['messageId'] as String;
    }

    await _local.show(
      // Stable per key so a re-show under the same tag replaces, not
      // stacks; an untagged push falls back to its own identity so two of
      // them don't collapse into one.
      id: tag?.hashCode ?? identityHashCode(notification),
      title: title,
      body: body,
      payload: jsonEncode(chatAlertPayload(data, title: title, body: body)),
      notificationDetails: chatAlertDetails(tag: tag, replyable: conversationTag != null, title: title, body: body),
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

/// Name the running app publishes a port under, so a reply sent from the
/// notification's own isolate can tell it to refresh.
///
/// That indirection is not optional: the plugin's `ActionBroadcastReceiver`
/// routes **every** action tap to the background callback dispatcher — even
/// while the app is in the foreground — and only a tap on the notification
/// *body* reaches `onDidReceiveNotificationResponse`. So on Android a reply
/// is always handled in a separate engine, where `_updates` does not exist.
/// `IsolateNameServer` is process-wide, which is what lets the two engines
/// find each other; lookup simply returns null when no app is running.
const String _replyPortName = 'yello.chat.reply';

/// One line of notification copy out of a `data` map, read defensively —
/// FCM only allows string values, but a payload is still outside data this
/// app controls, and a cast would throw rather than degrade.
String? _copy(Map<String, dynamic> data, String key) {
  final value = data[key];
  return value is String && value.isNotEmpty ? value : null;
}

/// What an alert this app drew carries in its payload: the push's own
/// `data`, plus the copy that was actually drawn. The copy is there so a
/// reply handled in a *different* isolate can rewrite the alert without
/// re-fetching anything — it only ever has the payload to work from.
Map<String, dynamic> chatAlertPayload(Map<String, dynamic> data, {String? title, String? body}) => {
  ...data,
  'title': ?title,
  'body': ?body,
};

/// How every chat/social alert this app draws is configured. [replyable]
/// adds the direct-reply affordance, which only a chat push has — nothing
/// else names a conversation to answer into.
///
/// A replyable alert is built as a **conversation**: `MessagingStyle` plus
/// `CATEGORY_MESSAGE` is what makes Android render it as a chat rather than
/// a one-line tray entry — sender across the top, the message below it, the
/// Reply field expanded rather than folded behind a chevron, and later
/// messages under the same tag threaded into one card instead of replacing
/// it. Everything else keeps the plain text form; there is no conversation
/// to style.
///
/// How much of that a given phone honours is still the phone's call — One
/// UI's *Notification pop-up style: Brief* collapses every heads-up to a
/// pill no matter what the app asks for. The style decides what the shade
/// and the expanded card look like, not whether the pop-up starts expanded.
NotificationDetails chatAlertDetails({required String? tag, required bool replyable, String? title, String? body}) =>
    NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        tag: tag,
        category: replyable ? AndroidNotificationCategory.message : null,
        styleInformation: replyable ? _chatStyle(title: title, body: body) : null,
        actions: replyable ? const [chatReplyAction] : null,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        threadIdentifier: tag,
        categoryIdentifier: replyable ? chatReplyCategoryId : null,
      ),
    );

/// `MessagingStyle` for one chat push. [title] is the sender as
/// `yello-notify` framed it and [body] the message, which is the shape a
/// chat alert's copy arrives in; `conversationTitle` is deliberately left
/// null, because setting it makes Android treat the thread as a group and
/// prefix every line with a sender name — and the payload says nothing
/// about whether this conversation is a group.
///
/// The [Person] passed first is *the viewer* — who a message the user sends
/// is attributed to — not the sender, which is why the incoming line
/// carries its own.
MessagingStyleInformation? _chatStyle({String? title, String? body}) {
  if (body == null) return null;
  return MessagingStyleInformation(
    const Person(name: 'You', key: 'me'),
    messages: [Message(body, DateTime.now(), Person(name: title, key: title))],
  );
}

/// The `data` map an alert was drawn from, or null when the payload is
/// missing or isn't one this app wrote.
Map<String, dynamic>? decodeNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) return decoded;
  } on FormatException {
    appLogger.w('Ignoring invalid notification navigation payload.');
  }
  return null;
}

/// Sends a reply typed into the shade. Returns whether the server took it.
///
/// Answering a message ends the notification: [chatReplyAction] already took
/// the alert down when Send was tapped, so a successful reply leaves nothing
/// behind. Only a failure needs an alert, and it gets a fresh one carrying
/// the text that didn't go out — otherwise the reply would disappear with
/// the notification and the user would have no way to know, or to get the
/// words back.
///
/// Shared by both isolates: the service handles the reply while the app is
/// alive, [notificationReplyBackgroundHandler] when it isn't, so the
/// behaviour is the same either way.
Future<bool> replyFromNotification(
  FlutterLocalNotificationsPlugin local, {
  required Map<String, dynamic> data,
  required String text,
}) async {
  final reply = text.trim();
  if (reply.isEmpty) return false;

  if (await sendChatReply(data: data, text: reply)) {
    IsolateNameServer.lookupPortByName(_replyPortName)?.send(null);
    return true;
  }

  final tag = chatNotificationTag(data);
  if (tag == null) return false;
  final body = 'Not sent: "$reply" — tap to open the chat.';
  await local.show(
    // The id the original alert was drawn under, so a retry that fails
    // again replaces this instead of stacking another copy.
    id: tag.hashCode,
    title: _copy(data, 'title'),
    body: body,
    payload: jsonEncode(chatAlertPayload(data, body: body)),
    // Audible on purpose: the message did not go out, and a silent alert
    // reads as "sent" to anyone who isn't watching the shade.
    notificationDetails: chatAlertDetails(tag: tag, replyable: true, title: _copy(data, 'title'), body: body),
  );
  return false;
}

/// Answers a Reply action typed while this app had no running isolate of
/// its own. Top-level and `vm:entry-point` because the plugin runs it in a
/// fresh engine, which starts with none of `bootstrap()`'s state — hence
/// the plugin instance built here and the registrant call, without which
/// secure storage has no platform channel to read the token through.
@pragma('vm:entry-point')
Future<void> notificationReplyBackgroundHandler(NotificationResponse response) async {
  if (response.actionId != chatReplyActionId) return;
  DartPluginRegistrant.ensureInitialized();
  final data = decodeNotificationPayload(response.payload);
  if (data == null) return;
  await replyFromNotification(FlutterLocalNotificationsPlugin(), data: data, text: response.input ?? '');
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
/// `Firebase.initializeApp()`.
///
/// Only a **data-only** push reaches this handler: Android hands a push
/// that carries its own `notification` block straight to the system tray
/// and runs no Dart at all (see docs/GOTCHAS.md). Two kinds arrive here:
///
/// - the silent `CHAT_MESSAGE_DELETED`, which exists only so the app can
///   take the earlier alert down (iOS may delay or drop it);
/// - a data-only `CHAT_MESSAGE`, which the app has to draw itself — and
///   drawing it here is the *only* way a backgrounded chat alert can carry
///   the Reply action, since the OS-drawn one has no actions on it.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final data = message.data;
  final tag = chatNotificationTag(data);
  if (tag == null) return;
  final local = FlutterLocalNotificationsPlugin();

  if (data['type'] == NotificationTypes.chatMessageDeleted) {
    await cancelChatNotification(local, tag);
    return;
  }

  // iOS *can* run this handler for a push that also carries a notification
  // block (`content-available` alongside `alert`); drawing then would
  // double the alert.
  if (message.notification != null) return;
  final title = _copy(data, 'title');
  final body = _copy(data, 'body');
  if (title == null && body == null) return;
  DartPluginRegistrant.ensureInitialized();
  await local.show(
    id: tag.hashCode,
    title: title,
    body: body,
    payload: jsonEncode(chatAlertPayload(data, title: title, body: body)),
    notificationDetails: chatAlertDetails(tag: tag, replyable: true, title: title, body: body),
  );
}
