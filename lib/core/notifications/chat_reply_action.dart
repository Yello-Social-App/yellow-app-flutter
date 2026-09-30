import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/chat/data/datasources/chat_remote_datasource.dart' show ChatRoutes;
import '../../features/chat/domain/usecases/chat_usecases.dart' show chatMessageMaxLength, newChatClientId;
import '../config/app_config.dart';
import '../security/input_sanitizer.dart';
import '../security/secure_storage_service.dart';
import '../utils/logger.dart';
import 'background_auth.dart';

/// Id of the Reply action — the Android `RemoteInput` one and the iOS
/// `UNTextInputNotificationAction` share it, so a response carrying this in
/// `NotificationResponse.actionId` is a reply on either platform, and
/// `NotificationResponse.input` is what the user typed.
const String chatReplyActionId = 'yello.chat.reply';

/// The iOS category the reply field hangs off. An alert **iOS itself**
/// draws from an APNs payload only grows the field when `aps.category`
/// names this value, so `yello-notify` has to set it — see
/// `docs/BACKEND.md`. Alerts this app draws set it via
/// [DarwinNotificationDetails.categoryIdentifier].
const String chatReplyCategoryId = 'yello_chat_reply';

/// The Android direct-reply action on every chat alert this app draws.
///
/// - `showsUserInterface: false` keeps the send in Dart — the point is to
///   answer without the app coming forward.
/// - `cancelNotification: true` takes the alert down the instant Send is
///   tapped: answering a message is done with it. It also means the shade
///   never sits on the system's progress spinner while the request runs —
///   that spinner only resolves when the notification changes or goes, so
///   holding the alert open until the POST returns would leave it turning.
///   A send that then fails puts a fresh alert back
///   (`replyFromNotification`), carrying the text so nothing is lost.
const AndroidNotificationAction chatReplyAction = AndroidNotificationAction(
  chatReplyActionId,
  'Reply',
  inputs: [AndroidNotificationActionInput(label: 'Reply…')],
  semanticAction: SemanticAction.reply,
  showsUserInterface: false,
);

/// Registered once in [DarwinInitializationSettings.notificationCategories]
/// so [chatReplyCategoryId] resolves to a real category on iOS. Not `const`
/// — `DarwinNotificationAction.text` is a factory.
final DarwinNotificationCategory chatReplyCategory = DarwinNotificationCategory(
  chatReplyCategoryId,
  actions: [DarwinNotificationAction.text(chatReplyActionId, 'Reply', buttonTitle: 'Send', placeholder: 'Message…')],
);

/// Sends [text] into the conversation a chat push's [data] names, and
/// reports whether the server took it.
///
/// Runs in whichever isolate the reply arrived on — see `background_auth.dart`
/// for how it reaches the API without DI. Both attempts (the second after a
/// 401 refresh) reuse one `clientId`, so a retry cannot post the reply twice.
Future<bool> sendChatReply({required Map<String, dynamic> data, required String text}) async {
  final conversationId = data['conversationId'];
  if (conversationId is! String || conversationId.trim().isEmpty) return false;

  // Same sanitising the composer's SendMessageUseCase applies — a reply
  // typed into the shade reaches the same endpoint with the same limits.
  final body = InputSanitizer.sanitizeText(text, maxLength: chatMessageMaxLength);
  if (body.isEmpty) return false;

  final storage = SecureStorageServiceImpl();
  var token = await backgroundAccessToken(storage);
  if (token == null) return false;
  final dio = backgroundDio();

  final id = conversationId.trim();
  final clientId = newChatClientId();
  try {
    try {
      await _postReply(dio, id, body, clientId, token);
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) {
        _logReplyFailure('failed', e);
        return false;
      }
      final refreshed = await refreshedAccessToken(storage);
      if (refreshed == null) return false;
      token = refreshed;
      await _postReply(dio, id, body, clientId, token);
    }
    await _markReplyRead(dio, id, data['messageId'], token);
    return true;
  } on DioException catch (e) {
    _logReplyFailure('failed after refresh', e);
    return false;
  } finally {
    dio.close();
  }
}

/// A reply that didn't go out has no UI to explain itself — the alert only
/// says "couldn't send" — so the log is the only diagnosis there is. The
/// transport reason and the status code are always recorded; the server's
/// error body only in debug, because it echoes the message that was sent
/// (the same line `LoggingInterceptor` draws).
void _logReplyFailure(String stage, DioException e) {
  final status = e.response?.statusCode;
  final detail = AppConfig.enableLogging ? ' — ${e.response?.data ?? e.message}' : '';
  appLogger.w('Notification reply $stage: ${e.type.name}${status == null ? '' : ' HTTP $status'}$detail');
}

/// Answering a message is reading it, so the conversation's unread count and
/// the inbox badge have to come down too — otherwise a reply sent from the
/// shade leaves the chat looking unread. Best effort on purpose: the reply
/// itself already landed, and there is nowhere to report this failing.
Future<void> _markReplyRead(Dio dio, String conversationId, Object? messageId, String token) async {
  if (messageId is! String || messageId.isEmpty) return;
  try {
    await dio.post<void>(ChatRoutes.read(conversationId), data: {'messageId': messageId}, options: bearer(token));
  } catch (e) {
    appLogger.w('Notification reply: marking $conversationId read failed — $e');
  }
}

Future<void> _postReply(Dio dio, String conversationId, String body, String clientId, String token) =>
    dio.post<Map<String, dynamic>>(
      ChatRoutes.messages(conversationId),
      data: {'clientId': clientId, 'body': body},
      options: bearer(token),
    );
