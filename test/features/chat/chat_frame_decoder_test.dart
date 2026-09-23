import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/chat/data/datasources/chat_frame_decoder.dart';
import 'package:yello_social_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:yello_social_app/features/chat/domain/entities/group_invite_entity.dart';
import 'package:yello_social_app/features/chat/domain/repositories/chat_repository.dart';

void main() {
  group('ChatFrameDecoder', () {
    test('message.updated carries the whole message', () {
      final event = ChatFrameDecoder.decode(
        '{"event":"message.updated","data":{"message":{"id":"m1","conversationId":"c1","senderId":"u1",'
        '"clientId":"k","body":"edited","attachments":[],"reactions":[],"createdAt":"2026-09-22T10:00:00.000Z",'
        '"editedAt":"2026-09-22T10:01:00.000Z"}}}',
        viewerId: 'u1',
      );
      expect(event, isA<MessageUpdated>());
      final updated = (event! as MessageUpdated).message;
      expect(updated.body, 'edited');
      expect(updated.isEdited, isTrue);
      expect(updated.fromMe, isTrue);
    });

    test('message.deleted, message.reactions and group.invite.updated', () {
      final deleted = ChatFrameDecoder.decodeFrame({
        'event': 'message.deleted',
        'data': {'conversationId': 'c1', 'messageId': 'm1', 'deletedAt': '2026-09-22T10:05:00.000Z'},
      });
      expect(deleted, isA<MessageDeleted>());
      expect((deleted! as MessageDeleted).deletedAt, DateTime.utc(2026, 9, 22, 10, 5));

      final reactions = ChatFrameDecoder.decodeFrame({
        'event': 'message.reactions',
        'data': {
          'conversationId': 'c1',
          'messageId': 'm1',
          'reactions': [
            {
              'emoji': '😂',
              'count': 1,
              'userIds': ['u2'],
            },
          ],
        },
      }, viewerId: 'u2');
      expect(reactions, isA<MessageReactionsChanged>());
      expect((reactions! as MessageReactionsChanged).reactions.single.reactedByMe, isTrue);

      final invite = ChatFrameDecoder.decodeFrame({
        'event': 'group.invite.updated',
        'data': {'inviteId': 'i1', 'conversationId': 'g1', 'status': 'ACCEPTED'},
      });
      expect((invite! as GroupInviteUpdated).status, GroupInviteStatus.accepted);
    });

    test('conversation.updated folds participants and change in', () {
      final event = ChatFrameDecoder.decodeFrame({
        'event': 'conversation.updated',
        'data': {
          'conversation': {
            'id': 'g1',
            'type': 'GROUP',
            'title': 'Renamed',
            'createdBy': 'u1',
            'createdAt': '2026-09-22T10:00:00.000Z',
          },
          'participants': [
            {'userId': 'u1', 'role': 'OWNER', 'joinedAt': '2026-09-22T10:00:00.000Z'},
            {'userId': 'u2', 'role': 'MEMBER', 'joinedAt': '2026-09-22T10:00:00.000Z'},
          ],
          'change': {
            'kind': 'MEMBERS_ADDED',
            'actorId': 'u1',
            'userIds': ['u2'],
          },
        },
      });
      final updated = event! as ConversationUpdated;
      expect(updated.conversation.title, 'Renamed');
      expect(updated.conversation.participants, hasLength(2));
      expect(updated.change.kind, ConversationChangeKind.membersAdded);
      expect(updated.change.userIds, ['u2']);
    });

    test('typing carries the user and defaults to started', () {
      final started = ChatFrameDecoder.decodeFrame({
        'event': 'typing',
        'data': {'conversationId': 'c1', 'userId': 'u2'},
      })! as TypingChanged;
      expect(started.userId, 'u2');
      expect(started.isTyping, isTrue);

      final stopped = ChatFrameDecoder.decodeFrame({
        'event': 'typing',
        'data': {'conversationId': 'c1', 'userId': 'u2', 'isTyping': false},
      })! as TypingChanged;
      expect(stopped.isTyping, isFalse);
    });

    test('conversation.removed keeps the reason', () {
      final event = ChatFrameDecoder.decodeFrame({
        'event': 'conversation.removed',
        'data': {'conversationId': 'g1', 'reason': 'LEFT'},
      });
      expect((event! as ConversationRemoved).reason, 'LEFT');
    });

    test('unknown, malformed and non-object frames decode to null', () {
      expect(ChatFrameDecoder.decode('not json'), isNull);
      expect(ChatFrameDecoder.decode('[1,2]'), isNull);
      expect(ChatFrameDecoder.decodeFrame({'event': 'something.new', 'data': {}}), isNull);
      expect(ChatFrameDecoder.decodeFrame({'event': 'message.deleted', 'data': {}}), isNull,
          reason: 'a required field missing must not throw');
      expect(ChatFrameDecoder.decodeFrame({'event': 'message.updated', 'data': {'message': 'nope'}}), isNull);
    });
  });
}
