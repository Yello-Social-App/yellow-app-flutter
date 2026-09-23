import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/core/notifications/chat_reply_action.dart';
import 'package:yello_social_app/core/notifications/push_notification_service.dart';

void main() {
  group('PushDestination.fromData', () {
    test('a conversation wins over everything else', () {
      final d = PushDestination.fromData({
        'type': 'CHAT_MESSAGE',
        'conversationId': '7c1e',
        'messageId': '9f02',
        'actorId': 'a11c',
      });
      expect(d, isA<ConversationDestination>());
      expect((d! as ConversationDestination).messageId, '9f02');
    });

    test('a post, with or without a comment', () {
      final withComment = PushDestination.fromData({
        'type': 'POST_COMMENTED',
        'postId': 'p',
        'commentId': 'c',
        'actorId': 'a',
      });
      expect((withComment! as PostDestination).commentId, 'c');
      final plain = PushDestination.fromData({'type': 'POST_REACTED', 'postId': 'p', 'actorId': 'a'});
      expect((plain! as PostDestination).commentId, isNull);
    });

    test('a resolved report opens Privacy & safety, ahead of any id on it', () {
      final d = PushDestination.fromData({
        'type': 'REPORT_RESOLVED',
        'reportId': '5e1d',
        'status': 'ACTION_TAKEN',
      });
      expect(d, isA<ReportsDestination>());
      expect((d! as ReportsDestination).reportId, '5e1d');

      // The id ladder must not get a look in even if the payload grows one
      // of its keys later: this type's destination is a screen, not a post.
      final withPostId = PushDestination.fromData({
        'type': 'REPORT_RESOLVED',
        'reportId': '5e1d',
        'postId': 'p',
      });
      expect(withPostId, isA<ReportsDestination>());
    });

    test('a silent friendship change is not a destination', () {
      // Data-only: nothing is shown for it and nothing is tappable, so it
      // must not resolve to the profile via some other key.
      expect(PushDestination.fromData({'type': 'FRIENDSHIP_CHANGED', 'userId': 'u1'}), isNull);
    });

    test('actorId alone opens the profile; nothing recognisable is null', () {
      expect(
        PushDestination.fromData({'type': 'FRIEND_REQUEST_RECEIVED', 'actorId': 'a'}),
        isA<ProfileDestination>(),
      );
      expect(PushDestination.fromData({'type': 'SOMETHING_NEW'}), isNull);
      expect(PushDestination.fromData({'conversationId': '   '}), isNull);
    });
  });

  group('chatNotificationTag', () {
    test('is chat:<conversationId> for chat pushes only', () {
      expect(chatNotificationTag({'type': 'CHAT_MESSAGE', 'conversationId': '7c1e'}), 'chat:7c1e');
      expect(chatNotificationTag({'type': 'CHAT_MESSAGE_DELETED', 'conversationId': '7c1e'}), 'chat:7c1e');
      expect(chatNotificationTag({'type': 'CHAT_REACTION', 'conversationId': '7c1e'}), isNull);
      expect(chatNotificationTag({'type': 'POST_REACTED', 'postId': 'p'}), isNull);
    });
  });

  group('chatAlertPayload', () {
    test('carries the drawn copy alongside the push data', () {
      final payload = chatAlertPayload(
        {'type': 'CHAT_MESSAGE', 'conversationId': '7c1e'},
        title: 'Alice',
        body: 'hey',
      );
      expect(payload, {'type': 'CHAT_MESSAGE', 'conversationId': '7c1e', 'title': 'Alice', 'body': 'hey'});
    });

    test('leaves out copy it was not given, rather than writing nulls', () {
      expect(chatAlertPayload({'conversationId': '7c1e'}, body: 'You: hi'), {
        'conversationId': '7c1e',
        'body': 'You: hi',
      });
    });
  });

  group('decodeNotificationPayload', () {
    test('reads back a payload this app wrote', () {
      expect(decodeNotificationPayload('{"conversationId":"7c1e"}'), {'conversationId': '7c1e'});
    });

    test('is null for nothing, junk, or a non-object', () {
      expect(decodeNotificationPayload(null), isNull);
      expect(decodeNotificationPayload(''), isNull);
      expect(decodeNotificationPayload('not json'), isNull);
      expect(decodeNotificationPayload('[1,2]'), isNull);
    });
  });

  group('sendChatReply', () {
    // Both of these return before touching secure storage or the network,
    // which is what makes them testable without a device: a reply with
    // nowhere to go, or nothing in it, is never sent.
    test('refuses a payload that names no conversation', () async {
      expect(await sendChatReply(data: const {'type': 'CHAT_MESSAGE'}, text: 'hi'), isFalse);
      expect(await sendChatReply(data: const {'conversationId': '  '}, text: 'hi'), isFalse);
    });

    test('refuses a reply that is empty once sanitised', () async {
      expect(await sendChatReply(data: const {'conversationId': '7c1e'}, text: '   '), isFalse);
      expect(await sendChatReply(data: const {'conversationId': '7c1e'}, text: '​'), isFalse);
    });
  });
}
