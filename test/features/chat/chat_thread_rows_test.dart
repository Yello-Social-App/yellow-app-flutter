import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/call/domain/entities/call_entity.dart';
import 'package:yello_social_app/features/call/domain/entities/call_log_entry.dart';
import 'package:yello_social_app/features/chat/domain/entities/message_entity.dart';
import 'package:yello_social_app/features/chat/presentation/pages/chat_page.dart';

DateTime _at(int minute) => DateTime.utc(2026, 10, 1, 9, minute);

MessageEntity _message(String id, int minute) => MessageEntity(
  id: id,
  conversationId: 'dm-1',
  senderId: 'mika',
  clientId: id,
  body: id,
  createdAt: _at(minute),
  fromMe: false,
);

CallLogEntry _call(String id, int minute) => CallLogEntry(
  callId: id,
  conversationId: 'dm-1',
  media: CallMedia.audio,
  isGroup: false,
  isOutgoing: true,
  endReason: CallEndReason.declined,
  at: _at(minute),
);

/// Message ids and call ids, in the order the thread draws them.
List<String> _ids(List<Object> rows) => [
  for (final row in rows)
    switch (row) {
      MessageEntity(:final id) => id,
      CallLogEntry(:final callId) => callId,
      _ => '?',
    },
];

void main() {
  test('a call sits among the messages by the time it rang', () {
    final rows = chatThreadRows(
      [_message('m1', 1), _message('m2', 5)],
      [_call('c1', 3), _call('c2', 9)],
      hasOlder: false,
    );

    expect(_ids(rows), ['m1', 'c1', 'm2', 'c2']);
  });

  test('a conversation with calls and no messages still has rows', () {
    expect(_ids(chatThreadRows(const [], [_call('c1', 3)], hasOlder: false)), ['c1']);
  });

  test('a call from before the loaded page waits for that page', () {
    final messages = [_message('m1', 5), _message('m2', 8)];
    final calls = [_call('old', 1), _call('c1', 6)];

    expect(_ids(chatThreadRows(messages, calls, hasOlder: true)), ['m1', 'c1', 'm2']);
    expect(_ids(chatThreadRows(messages, calls, hasOlder: false)), ['old', 'm1', 'c1', 'm2']);
  });

  test('no calls leaves the messages as they are', () {
    final messages = [_message('m1', 1)];
    expect(chatThreadRows(messages, const [], hasOlder: true), same(messages));
  });
}
