import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/chat/domain/entities/attachment_entity.dart';
import 'package:yello_social_app/features/chat/domain/entities/message_entity.dart';
import 'package:yello_social_app/features/chat/presentation/widgets/call_message_card.dart';

MessageEntity _message(
  String body, {
  ReplyPreviewEntity? replyTo,
  List<AttachmentEntity> attachments = const [],
  DateTime? editedAt,
  DateTime? deletedAt,
}) => MessageEntity(
  id: 'm-1',
  conversationId: 'dm-1',
  senderId: 'u-2',
  clientId: 'c-1',
  body: body,
  createdAt: DateTime.utc(2026, 10, 1, 9),
  fromMe: false,
  replyTo: replyTo,
  attachments: attachments,
  editedAt: editedAt,
  deletedAt: deletedAt,
);

/// A call note reaches the thread as an ordinary text message — the wire has
/// no call field — so the card hangs on reading the words. What matters is
/// that every phrasing of a call is caught and that a sentence is not.
void main() {
  group('callMessageOf', () {
    test('reads a call that only rang', () {
      for (final (text, status) in [
        ('Cancelled voice call', 'Cancelled'),
        ('Missed voice call', 'Missed'),
        ('You declined a voice call', 'Declined'),
        ('Voice call declined', 'Declined'),
        ('Voice call · no answer', 'No answer'),
        ('Voice call · line busy', 'Line busy'),
        ('Voice call failed', 'Failed'),
      ]) {
        final call = callMessageOf(_message(text));
        expect(call, isNotNull, reason: text);
        expect(call!.connected, isFalse, reason: text);
        expect(call.status, status, reason: text);
        expect(call.title, 'Voice call', reason: text);
      }
    });

    test('reads a call that was answered', () {
      final timed = callMessageOf(_message('Video call · 1:05'))!;
      expect(timed.connected, isTrue);
      expect(timed.isVideo, isTrue);
      expect(timed.status, '1:05');
      expect(timed.title, 'Video call');

      final ended = callMessageOf(_message('Voice call ended'))!;
      expect(ended.connected, isTrue);
      expect(ended.status, 'Ended');

      final bare = callMessageOf(_message('Voice call'))!;
      expect(bare.connected, isTrue);
      expect(bare.status, isNull);
    });

    test('is not thrown by case, spacing or a group call', () {
      expect(callMessageOf(_message('  cancelled VOICE call \n'))!.status, 'Cancelled');
      expect(callMessageOf(_message('Canceled video call'))!.status, 'Cancelled');
      final group = callMessageOf(_message('Missed group video call'))!;
      expect(group.isGroup, isTrue);
      expect(group.title, 'Group video call');
    });

    test('leaves a sentence that mentions a call alone', () {
      for (final text in [
        'hello',
        'Call me',
        'I missed your voice call, sorry',
        'Cancelled voice call because of the rain',
        'voice call?',
        'Missed call',
        '',
      ]) {
        expect(callMessageOf(_message(text)), isNull, reason: text);
      }
    });

    test('only a bare text message qualifies', () {
      const text = 'Cancelled voice call';
      const quote = ReplyPreviewEntity(id: 'm-0', senderId: 'u-1', body: 'ring me');
      const file = AttachmentEntity(
        id: 'att-1',
        kind: AttachmentKind.file,
        fileName: 'notes.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 10,
      );
      final at = DateTime.utc(2026, 10, 1, 10);

      expect(callMessageOf(_message(text, replyTo: quote)), isNull);
      expect(callMessageOf(_message(text, attachments: const [file])), isNull);
      expect(callMessageOf(_message(text, editedAt: at)), isNull);
      expect(callMessageOf(_message(text, deletedAt: at)), isNull);
    });
  });

  group('CallMessageCard', () {
    Future<void> pumpCard(WidgetTester tester, String text) async {
      // What an incoming bubble is given on a 320pt phone, less the bubble's
      // own padding. Mirrors `_MessageBubble` in `chat_page.dart`.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320 * 0.78 - 36 - 24),
                child: CallMessageCard(call: callMessageOf(_message(text))!),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a call that only rang shows the hung-up phone and what became of it', (tester) async {
      await pumpCard(tester, 'Cancelled voice call');

      expect(find.text('Voice call'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.phone_down_fill), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an answered video call shows the camera and its length', (tester) async {
      await pumpCard(tester, 'Group video call · 12:40');

      expect(find.text('Group video call'), findsOneWidget);
      expect(find.text('12:40'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.video_camera_solid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
