import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/chat/data/models/conversation_model.dart';
import 'package:yello_social_app/features/chat/data/models/message_model.dart';
import 'package:yello_social_app/features/chat/data/models/sticker_model.dart';
import 'package:yello_social_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:yello_social_app/features/chat/domain/entities/message_entity.dart';
import 'package:yello_social_app/features/chat/domain/entities/sticker_entity.dart';

/// The Sticker object from the sticker API reference, verbatim.
Map<String, dynamic> _sticker() => {
  'id': '0b6c-uuid',
  'packId': null,
  'name': 'Mochi with his stick',
  'background': 'REMOVED',
  'image': {
    'url': 'https://r2.example/stk.webp?X-Amz-Signature=1',
    'width': 512,
    'height': 512,
    'urlExpiresAt': '2026-09-28T11:15:00.000Z',
  },
  'isMine': true,
  'createdAt': '2026-09-28T10:15:00.000Z',
};

void main() {
  group('StickerMapper', () {
    test('reads the reference object whole', () {
      final sticker = StickerMapper.fromJson(_sticker());
      expect(sticker.id, '0b6c-uuid');
      expect(sticker.packId, isNull);
      expect(sticker.isFromPack, isFalse);
      expect(sticker.name, 'Mochi with his stick');
      expect(sticker.background, StickerBackground.removed);
      expect(sticker.needsFrame, isFalse);
      expect(sticker.isMine, isTrue);
      expect(sticker.canManage, isTrue);
      expect(sticker.image.width, 512);
      expect(sticker.image.urlExpiresAt, DateTime.utc(2026, 9, 28, 11, 15));
    });

    test('a pack sticker is not manageable, whatever isMine says', () {
      final sticker = StickerMapper.fromJson({
        ..._sticker(),
        'packId': 'pack_yello_buddy',
        'background': 'KEPT',
        'isMine': true,
      });
      expect(sticker.isFromPack, isTrue);
      expect(sticker.needsFrame, isTrue);
      expect(sticker.canManage, isFalse);
    });

    test('an unknown background reads as KEPT, so there is always a frame to draw', () {
      expect(StickerMapper.fromJson({..._sticker(), 'background': 'BLURRED'}).background, StickerBackground.kept);
      expect(StickerMapper.fromJson({..._sticker(), 'background': null}).background, StickerBackground.kept);
    });

    test('the presigned URL is not part of identity — two reads of one sticker compare equal', () {
      final first = StickerMapper.fromJson(_sticker());
      final second = StickerMapper.fromJson({
        ..._sticker(),
        'image': {'url': 'https://r2.example/stk.webp?X-Amz-Signature=2', 'width': 512, 'height': 512},
      });
      // Which is what stops a history poll from making the whole transcript
      // look new every few seconds.
      expect(first, second);
      expect(first.image.url, isNot(second.image.url));
    });

    test('a page keeps the server order and its cursor', () {
      final page = StickerMapper.pageFromJson({
        'items': [
          _sticker(),
          {..._sticker(), 'id': 'older'},
          {'name': 'no id at all'},
        ],
        'nextCursor': 'c2',
      });
      expect(page.items.map((s) => s.id), ['0b6c-uuid', 'older']);
      expect(page.hasMore, isTrue);
      expect(StickerMapper.pageFromJson({'items': <dynamic>[]}).hasMore, isFalse);
    });
  });

  group('StickerPackMapper', () {
    test('reads packs in order and drops an emptied one', () {
      final packs = StickerPackMapper.fromJsonList([
        {
          'id': 'pack_yello_buddy',
          'name': 'Yello Buddy',
          'thumbnailUrl': 'https://r2.example/thumb.webp',
          'stickers': [_sticker()],
        },
        {'id': 'pack_withdrawn', 'name': 'Gone', 'stickers': <dynamic>[]},
      ]);
      expect(packs.length, 1);
      expect(packs.single.id, 'pack_yello_buddy');
      expect(packs.single.stickers.single.id, '0b6c-uuid');
    });
  });

  group('StickerDraftMapper', () {
    test('a draft with no subject offers no cut-out and previews the original', () {
      final draft = StickerDraftMapper.fromJson({
        'draftId': 'd1',
        'original': {'url': 'https://r2.example/orig.webp', 'width': 512, 'height': 512},
        'cutout': null,
        'cutoutStatus': 'NO_SUBJECT',
        'expiresAt': '2026-09-28T11:15:00.000Z',
      });
      expect(draft.cutoutStatus, StickerCutoutStatus.noSubject);
      expect(draft.hasCutout, isFalse);
      // Asking for REMOVED anyway falls back to the square rather than drawing
      // nothing — the creator refuses the choice, and this is the backstop.
      expect(draft.previewFor(StickerBackground.removed).url, 'https://r2.example/orig.webp');
    });

    test('READY without a cutout picture still offers nothing', () {
      final draft = StickerDraftMapper.fromJson({
        'draftId': 'd1',
        'original': {'url': 'https://r2.example/orig.webp'},
        'cutoutStatus': 'READY',
      });
      expect(draft.hasCutout, isFalse);
    });

    test('READY with a cutout is offerable and previews the cut-out', () {
      final draft = StickerDraftMapper.fromJson({
        'draftId': 'd1',
        'original': {'url': 'https://r2.example/orig.webp'},
        'cutout': {'url': 'https://r2.example/cut.webp'},
        'cutoutStatus': 'READY',
      });
      expect(draft.hasCutout, isTrue);
      expect(draft.previewFor(StickerBackground.removed).url, 'https://r2.example/cut.webp');
      expect(draft.previewFor(StickerBackground.kept).url, 'https://r2.example/orig.webp');
    });
  });

  group('a sticker on a message', () {
    MessageEntity build({Map<String, dynamic>? sticker, Map<String, dynamic>? replyTo}) => MessageMapper.fromJson({
      'id': 'm1',
      'conversationId': 'c1',
      'senderId': 'u2',
      'clientId': 'k1',
      'body': '',
      'createdAt': '2026-09-28T10:20:00.000Z',
      'sticker': sticker,
      'replyTo': replyTo,
    }, viewerId: 'u1');

    test('is mapped, and the message is not editable', () {
      final message = build(sticker: _sticker());
      expect(message.isSticker, isTrue);
      expect(message.sticker!.id, '0b6c-uuid');
      expect(message.hasText, isFalse);
      // `400 STICKER_NOT_EDITABLE` — refused before it is offered.
      expect(message.canEdit, isFalse);
      expect(message.canInteract, isTrue);
    });

    test('a tombstone drops it, along with the quote flag on replies to it', () {
      final deleted = build(sticker: _sticker()).asDeleted(DateTime.utc(2026, 9, 28, 10, 30));
      expect(deleted.sticker, isNull);
      expect(deleted.isSticker, isFalse);

      final quote = build(sticker: _sticker()).toReplyPreview();
      expect(quote.hasSticker, isTrue);
      expect(quote.copyWith(deleted: true).hasSticker, isFalse);
    });

    test('replyTo.hasSticker comes off the wire, so a quote can say "Sticker"', () {
      final message = build(
        replyTo: {'id': 'm0', 'senderId': 'u2', 'body': '', 'hasSticker': true},
      );
      expect(message.replyTo!.hasSticker, isTrue);
      expect(message.replyTo!.body, isEmpty);
    });

    test('null on a message that is not one, and on a malformed block', () {
      expect(build().sticker, isNull);
      expect(build(sticker: {'background': 'KEPT'}).sticker, isNull);
    });
  });

  group('the inbox preview', () {
    LastMessageEntity? summaryOf(Map<String, dynamic> lastMessage) =>
        ConversationMapper.fromJson({'id': 'c1', 'type': 'DIRECT', 'lastMessage': lastMessage}).lastMessage;

    test('reads hasSticker off the summary', () {
      final summary = summaryOf({'id': 'm1', 'senderId': 'u2', 'body': '', 'hasSticker': true});
      expect(summary!.kind, LastMessageKind.sticker);
      expect(summary.preview, 'Sent a sticker');
    });

    test('an empty body without the flag is still only "an attachment"', () {
      expect(summaryOf({'id': 'm1', 'senderId': 'u2', 'body': ''})!.kind, LastMessageKind.attachment);
    });

    test('a full message this client applied itself names the sticker too', () {
      final message = MessageMapper.fromJson({
        'id': 'm1',
        'conversationId': 'c1',
        'senderId': 'u1',
        'clientId': 'k1',
        'body': '',
        'createdAt': '2026-09-28T10:20:00.000Z',
        'sticker': _sticker(),
      }, viewerId: 'u1');
      final summary = LastMessageEntity.fromMessage(message);
      expect(summary.kind, LastMessageKind.sticker);
      expect(summary.preview, 'Sent a sticker');
    });
  });
}
