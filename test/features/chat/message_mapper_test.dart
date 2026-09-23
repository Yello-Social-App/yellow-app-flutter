import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/chat/data/models/conversation_model.dart';
import 'package:yello_social_app/features/chat/data/models/message_model.dart';
import 'package:yello_social_app/features/chat/domain/entities/attachment_entity.dart';
import 'package:yello_social_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:yello_social_app/features/chat/domain/entities/group_invite_entity.dart';
import 'package:yello_social_app/features/chat/domain/entities/participant_entity.dart';

/// The example message from the chat API reference, verbatim.
Map<String, dynamic> _fullMessage() => {
      'id': '9f02',
      'conversationId': '7c1e',
      'senderId': 'a11c',
      'clientId': 'c-42',
      'body': 'look at this',
      'replyTo': {'id': '8e01', 'senderId': 'b0b0', 'body': 'lunch?', 'hasAttachments': false, 'deleted': false},
      'attachments': [
        {
          'id': 'f1a2',
          'kind': 'IMAGE',
          'fileName': 'cat.jpg',
          'mimeType': 'image/jpeg',
          'sizeBytes': 48213,
          'url': 'https://r2.example/cat.jpg?X-Amz-Signature=1',
          'urlExpiresAt': '2026-09-22T11:00:00.000Z',
        },
      ],
      'reactions': [
        {
          'emoji': '❤️',
          'count': 2,
          'userIds': ['b0b0', 'c0de'],
        },
      ],
      'groupInvite': null,
      'createdAt': '2026-09-22T10:00:00.000Z',
      'editedAt': null,
      'deletedAt': null,
    };

void main() {
  group('MessageMapper', () {
    test('maps every new field of the reference message', () {
      final message = MessageMapper.fromJson(_fullMessage(), viewerId: 'b0b0');

      expect(message.fromMe, isFalse);
      expect(message.replyTo?.id, '8e01');
      expect(message.replyTo?.body, 'lunch?');
      expect(message.attachments.single.kind, AttachmentKind.image);
      expect(message.attachments.single.sizeLabel, '47 KB');
      expect(message.reactions.single.count, 2);
      expect(message.reactions.single.reactedByMe, isTrue, reason: 'b0b0 is in userIds');
      expect(message.myReaction?.emoji, '❤️');
      expect(message.isEdited, isFalse);
      expect(message.isDeleted, isFalse);
      expect(message.canEdit, isFalse, reason: 'not the sender');
    });

    test('reactedByMe is false for an unknown viewer', () {
      final message = MessageMapper.fromJson(_fullMessage());
      expect(message.reactions.single.reactedByMe, isFalse);
      expect(message.myReaction, isNull);
    });

    test('a tombstone keeps its place but nothing else', () {
      final json = _fullMessage()
        ..['body'] = ''
        ..['attachments'] = []
        ..['reactions'] = []
        ..['deletedAt'] = '2026-09-22T10:05:00.000Z';
      final message = MessageMapper.fromJson(json, viewerId: 'a11c');

      expect(message.isDeleted, isTrue);
      expect(message.canEdit, isFalse);
      expect(message.canDelete, isFalse);
      expect(message.canInteract, isFalse);
      expect(message.hasText, isFalse);
    });

    test('an invite card is forMe only for the invitee', () {
      final json = _fullMessage()
        ..['body'] = ''
        ..['attachments'] = []
        ..['groupInvite'] = {
          'id': 'i456',
          'conversationId': 'g123',
          'inviterId': 'a11c',
          'inviteeId': 'c0de',
          'status': 'PENDING',
          'title': 'Beach trip',
          'memberCount': 3,
          'photoUrl': null,
          'photoUrlExpiresAt': null,
        };

      final forInvitee = MessageMapper.fromJson(json, viewerId: 'c0de').groupInvite!;
      expect(forInvitee.canRespond, isTrue);
      expect(forInvitee.displayTitle, 'Beach trip');

      final forInviter = MessageMapper.fromJson(json, viewerId: 'a11c').groupInvite!;
      expect(forInviter.canRespond, isFalse);

      final answered = forInvitee.copyWith(status: GroupInviteStatus.accepted);
      expect(answered.canRespond, isFalse);
    });

    test('attachment identity ignores the re-signed URL', () {
      final a = AttachmentMapper.fromJson(_fullMessage()['attachments'][0] as Map<String, dynamic>);
      final b = AttachmentMapper.fromJson(
        (_fullMessage()['attachments'][0] as Map<String, dynamic>)..['url'] = 'https://r2.example/cat.jpg?X-Amz-Signature=2',
      );
      expect(a, equals(b));
    });

    test('asDeleted mirrors the server tombstone and toReplyPreview trims', () {
      final message = MessageMapper.fromJson(_fullMessage(), viewerId: 'a11c');
      final deleted = message.asDeleted(DateTime.utc(2026, 9, 22, 10, 5));
      expect(deleted.body, '');
      expect(deleted.attachments, isEmpty);
      expect(deleted.reactions, isEmpty);
      expect(deleted.isDeleted, isTrue);
      expect(deleted.toReplyPreview().deleted, isTrue);

      final long = message.copyWith(body: 'x' * 300);
      expect(long.toReplyPreview().body.length, 200);
    });
  });

  group('ConversationMapper', () {
    test('reads the group photo, ADMIN role and viewer role', () {
      final conversation = ConversationMapper.fromJson({
        'id': 'g123',
        'type': 'GROUP',
        'title': 'Beach trip',
        'createdBy': 'a11c',
        'createdAt': '2026-09-22T10:00:00.000Z',
        'lastMessageAt': null,
        'photoUrl': 'https://r2.example/photo.jpg?sig=1',
        'photoUrlExpiresAt': '2026-09-22T11:00:00.000Z',
        'participants': [
          {'userId': 'a11c', 'role': 'OWNER', 'joinedAt': '2026-09-22T10:00:00.000Z'},
          {'userId': 'b0b0', 'role': 'ADMIN', 'joinedAt': '2026-09-22T10:00:00.000Z'},
          {'userId': 'c0de', 'role': 'MEMBER', 'joinedAt': '2026-09-22T10:00:00.000Z'},
        ],
      }, viewerId: 'b0b0');

      expect(conversation.isGroup, isTrue);
      expect(conversation.hasPhoto, isTrue);
      expect(conversation.avatarUrl, startsWith('https://r2.example/photo.jpg'));
      expect(conversation.myRole, ParticipantRole.admin);
      expect(conversation.myRole.canManage, isTrue);
      expect(conversation.participants[1].role, ParticipantRole.admin);
    });

    test('an empty lastMessage body previews as an attachment', () {
      final conversation = ConversationMapper.fromJson({
        'id': '7c1e',
        'type': 'DIRECT',
        'title': null,
        'createdBy': 'a11c',
        'createdAt': '2026-09-22T10:00:00.000Z',
        'lastMessage': {'id': 'm1', 'senderId': 'a11c', 'body': '', 'createdAt': '2026-09-22T10:00:00.000Z'},
        'participants': [],
        'unreadCount': 1,
      });
      expect(conversation.lastMessage?.kind, LastMessageKind.attachment);
      expect(conversation.lastMessagePreview, 'Sent an attachment');
    });

    test('mergeDetail keeps the inbox-only fields', () {
      final row = ConversationMapper.fromJson({
        'id': 'g123',
        'type': 'GROUP',
        'title': 'Old name',
        'createdBy': 'a11c',
        'createdAt': '2026-09-22T10:00:00.000Z',
        'lastMessage': {'id': 'm1', 'senderId': 'a11c', 'body': 'hi', 'createdAt': '2026-09-22T10:00:00.000Z'},
        'participants': [],
        'unreadCount': 4,
      });
      final detail = ConversationMapper.fromJson({
        'id': 'g123',
        'type': 'GROUP',
        'title': 'New name',
        'createdBy': 'a11c',
        'createdAt': '2026-09-22T10:00:00.000Z',
        'photoUrl': null,
        'participants': [
          {'userId': 'a11c', 'role': 'OWNER', 'joinedAt': '2026-09-22T10:00:00.000Z'},
        ],
      });

      final merged = row.mergeDetail(detail);
      expect(merged.title, 'New name');
      expect(merged.participants, hasLength(1));
      expect(merged.unreadCount, 4);
      expect(merged.lastMessagePreview, 'hi');
    });

    test('a removed photo clears through copyWith', () {
      final withPhoto = ConversationEntity(
        id: 'g',
        type: ConversationType.group,
        createdBy: 'a',
        createdAt: DateTime(2026),
        photoUrl: 'https://x/y',
      );
      expect(withPhoto.copyWith(photoUrl: null).hasPhoto, isFalse);
      expect(withPhoto.copyWith().hasPhoto, isTrue);
    });
  });
}
