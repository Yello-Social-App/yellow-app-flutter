import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/core/notifications/call_alert.dart';
import 'package:yello_social_app/core/notifications/push_notification_service.dart';

void main() {
  test('the three call pushes are recognised, nothing else is', () {
    expect(isCallPush(const {'type': 'CALL_INCOMING'}), isTrue);
    expect(isCallPush(const {'type': 'CALL_MISSED'}), isTrue);
    expect(isCallPush(const {'type': 'CALL_RING_STOPPED'}), isTrue);
    expect(isCallPush(const {'type': 'CHAT_MESSAGE'}), isFalse);
    expect(isCallPush(const {}), isFalse);
  });

  test('the call id is read defensively', () {
    expect(callIdOf(const {'callId': ' 7d2f '}), '7d2f');
    expect(callIdOf(const {'callId': ''}), isNull);
    expect(callIdOf(const {'callId': 42}), isNull);
    expect(callIdOf(const {}), isNull);
  });

  test('the ring and the missed-call alert share one id per call', () {
    expect(callAlertId('7d2f'), callAlertId('7d2f'));
    expect(callAlertId('7d2f'), isNot(callAlertId('8e3a')));
  });

  test('a tapped call alert opens its conversation', () {
    final destination = PushDestination.fromData(const {
      'type': 'CALL_MISSED',
      'callId': '7d2f',
      'conversationId': 'c91a',
      'actorId': '2222',
    });
    expect(destination, isA<ConversationDestination>().having((d) => d.conversationId, 'conversationId', 'c91a'));
  });
}
