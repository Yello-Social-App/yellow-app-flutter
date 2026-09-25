import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/chat/data/models/message_model.dart';
import 'package:yello_social_app/features/chat/domain/entities/attachment_entity.dart';
import 'package:yello_social_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:yello_social_app/features/chat/domain/entities/message_entity.dart';

/// The voice attachment from the Voice Messages API reference, verbatim
/// (its waveform shortened there as here — a real one carries up to 64).
Map<String, dynamic> _voiceAttachment() => {
  'id': '9b1c6f0e-3a51-4c7a-9d0e-5f2b8f3c1a77',
  'kind': 'VOICE',
  'fileName': 'voice-message.m4a',
  'mimeType': 'audio/mp4',
  'sizeBytes': 30412,
  'voice': {
    'durationMs': 4870,
    'waveform': [8, 22, 61, 100, 87, 45, 30, 72, 95, 60, 18, 5],
  },
  'url': 'https://r2.example/voice.m4a?X-Amz-Signature=1',
  'urlExpiresAt': '2026-09-24T13:00:00.000Z',
};

MessageEntity _messageWith(AttachmentEntity attachment) => MessageEntity(
  id: 'm1',
  conversationId: 'c1',
  senderId: 'u1',
  clientId: 'c-1',
  body: '',
  createdAt: DateTime(2026, 9, 24),
  fromMe: true,
  attachments: [attachment],
);

void main() {
  group('AttachmentMapper — voice', () {
    test('reads the kind, the duration and the waveform', () {
      final attachment = AttachmentMapper.fromJson(_voiceAttachment());

      expect(attachment.kind, AttachmentKind.voice);
      expect(attachment.isVoice, isTrue);
      expect(attachment.isImage, isFalse);
      expect(attachment.voice!.durationMs, 4870);
      expect(attachment.voice!.waveform, hasLength(12));
      expect(attachment.voice!.durationLabel, '0:04');
    });

    test('a waveform value outside 0–100 is clamped rather than drawn off the bar', () {
      final json = _voiceAttachment()
        ..['voice'] = {
          'durationMs': 1000,
          'waveform': [-5, 50, 140],
        };

      expect(AttachmentMapper.fromJson(json).voice!.waveform, [0, 50, 100]);
    });

    test('an unmeasurable recording falls back to a file rather than a player stuck at 0:00', () {
      final json = _voiceAttachment()..['voice'] = {'durationMs': 0, 'waveform': <int>[]};
      final attachment = AttachmentMapper.fromJson(json);

      // The kind is still what the server said — it is `isVoice` that gates
      // the player, and `_MessageBubble` sends anything else to the file chip.
      expect(attachment.kind, AttachmentKind.voice);
      expect(attachment.voice, isNull);
      expect(attachment.isVoice, isFalse);
    });

    test('a kind this app has not heard of degrades to a file', () {
      final json = _voiceAttachment()..['kind'] = 'HOLOGRAM';

      expect(AttachmentMapper.fromJson(json).kind, AttachmentKind.file);
    });

    test('two reads of the same note compare equal even though the URL is re-signed', () {
      final first = AttachmentMapper.fromJson(_voiceAttachment());
      final second = AttachmentMapper.fromJson(
        _voiceAttachment()..['url'] = 'https://r2.example/voice.m4a?X-Amz-Signature=2',
      );

      // ADR-015: identity is the id. Without this the history poll would
      // restart playback every few seconds.
      expect(first, second);
    });
  });

  group('inbox preview', () {
    test('a voice note reads as a voice message, not as its filename', () {
      final last = LastMessageEntity.fromMessage(_messageWith(AttachmentMapper.fromJson(_voiceAttachment())));

      expect(last.kind, LastMessageKind.voice);
      // The same words the push notification for one uses.
      expect(last.preview, 'Sent a voice message');
    });

    test('an ordinary attachment is unaffected', () {
      final file = AttachmentMapper.fromJson(_voiceAttachment()..['kind'] = 'FILE');
      final last = LastMessageEntity.fromMessage(_messageWith(file));

      expect(last.kind, LastMessageKind.attachment);
      expect(last.preview, 'Sent an attachment');
    });
  });

  group('formatVoiceDuration', () {
    test('is m:ss, and never negative', () {
      expect(formatVoiceDuration(Duration.zero), '0:00');
      expect(formatVoiceDuration(const Duration(seconds: 7)), '0:07');
      expect(formatVoiceDuration(const Duration(seconds: 70)), '1:10');
      expect(formatVoiceDuration(const Duration(minutes: 5)), '5:00');
      // What a countdown hits when the position overshoots the duration.
      expect(formatVoiceDuration(const Duration(milliseconds: -200)), '0:00');
    });
  });
}
