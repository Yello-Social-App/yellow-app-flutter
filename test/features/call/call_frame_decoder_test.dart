import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/call/data/datasources/call_frame_decoder.dart';
import 'package:yello_social_app/features/call/data/models/call_model.dart';
import 'package:yello_social_app/features/call/domain/entities/call_entity.dart';
import 'package:yello_social_app/features/call/domain/repositories/call_repository.dart';

Map<String, dynamic> _call({
  String id = 'call-1',
  String initiatorId = 'caller',
  String status = 'RINGING',
  String? endReason,
  String media = 'video',
}) => {
  'id': id,
  'conversationId': 'dm-1',
  'initiatorId': initiatorId,
  'media': media,
  'status': status,
  'endReason': endReason,
  'createdAt': '2026-09-29T10:00:00.000Z',
  'answeredAt': status == 'RINGING' ? null : '2026-09-29T10:00:06.412Z',
  'endedAt': status == 'ENDED' ? '2026-09-29T10:03:18.020Z' : null,
};

void main() {
  group('CallMapper', () {
    test('reads every field of a Call', () {
      final call = CallMapper.fromJson(
        _call(status: 'ENDED', endReason: 'HANGUP'),
        viewerId: 'caller',
      );

      expect(call.id, 'call-1');
      expect(call.conversationId, 'dm-1');
      expect(call.media, CallMedia.video);
      expect(call.status, CallStatus.ended);
      expect(call.endReason, CallEndReason.hangup);
      expect(call.isOutgoing, isTrue);
      expect(call.talkTime, const Duration(minutes: 3, seconds: 11, milliseconds: 608));
    });

    test('the viewer is the callee unless they are the initiator', () {
      expect(CallMapper.fromJson(_call(), viewerId: 'someone-else').isOutgoing, isFalse);
      // Unknown viewer: never claim the call is ours.
      expect(CallMapper.fromJson(_call()).isOutgoing, isFalse);
    });

    test('a token keeps its credential out of toString', () {
      final token = CallTokenMapper.fromJson({
        'serverUrl': 'wss://yello.livekit.cloud',
        'roomName': 'call_call-1',
        'token': 'secret.jwt.value',
        'expiresAt': '2026-09-29T10:10:06.000Z',
      });

      expect(token.serverUrl, 'wss://yello.livekit.cloud');
      expect(token.token, 'secret.jwt.value');
      expect(token.toString(), isNot(contains('secret')));
    });
  });

  group('CallFrameDecoder', () {
    test('call.ringing is always incoming, whoever the viewer is', () {
      final event = CallFrameDecoder.decode({
        'event': 'call.ringing',
        'data': {'call': _call()},
      }, viewerId: 'caller');

      expect(event, isA<CallRinging>());
      expect((event! as CallRinging).call.isOutgoing, isFalse);
    });

    test('call.accepted and call.ended are placed by the viewer id', () {
      final accepted = CallFrameDecoder.decode({
        'event': 'call.accepted',
        'data': {'call': _call(status: 'ACTIVE')},
      }, viewerId: 'caller');
      final ended =
          CallFrameDecoder.decode({
                'event': 'call.ended',
                'data': {'reason': 'MISSED', 'call': _call(status: 'ENDED', endReason: 'MISSED')},
              }, viewerId: 'callee')!
              as CallEnded;

      expect((accepted! as CallAccepted).call.isOutgoing, isTrue);
      expect(ended.call.endReason, CallEndReason.missed);
      expect(ended.call.isOutgoing, isFalse);
    });

    test('call.ended falls back to data.reason when the call omits it', () {
      final event = CallFrameDecoder.decode({
        'event': 'call.ended',
        'data': {'reason': 'BUSY', 'call': _call(status: 'ENDED')},
      });

      expect((event! as CallEnded).call.endReason, CallEndReason.busy);
    });

    test('ignores frames that are not about a call', () {
      expect(
        CallFrameDecoder.decode({
          'event': 'message.new',
          'data': {'message': {}},
        }),
        isNull,
      );
      expect(
        CallFrameDecoder.decode({
          'event': 'call.started',
          'data': {'call': _call()},
        }),
        isNull,
      );
      expect(CallFrameDecoder.decode({'event': 'call.ringing', 'data': 'nope'}), isNull);
    });

    test('settles / ends match only their own call', () {
      final accepted = {
        'event': 'call.accepted',
        'data': {'call': _call(status: 'ACTIVE')},
      };
      final ended = {
        'event': 'call.ended',
        'data': {'call': _call(status: 'ENDED', endReason: 'FAILED')},
      };

      expect(CallFrameDecoder.settles(accepted, 'call-1'), isTrue);
      expect(CallFrameDecoder.settles(ended, 'call-1'), isTrue);
      expect(CallFrameDecoder.settles(accepted, 'call-2'), isFalse);
      expect(CallFrameDecoder.ends(ended, 'call-1'), isTrue);
      expect(CallFrameDecoder.ends(accepted, 'call-1'), isFalse);
    });
  });

  group('group calls', () {
    Map<String, dynamic> group({Map<String, String> states = const {'ana': 'JOINED', 'me': 'INVITED'}}) => {
      ..._call(initiatorId: 'ana', status: 'ACTIVE'),
      'kind': 'GROUP',
      'participants': [
        for (final e in states.entries)
          {'userId': e.key, 'state': e.value, 'joinedAt': e.value == 'JOINED' ? '2026-09-30T08:00:00.000Z' : null},
      ],
    };

    test('the roster is read, and the viewer finds their own entry in it', () {
      final call = CallMapper.fromJson(group(), viewerId: 'me');

      expect(call.kind, CallKind.group);
      expect(call.participants.map((p) => p.userId), ['ana', 'me']);
      expect(call.joinedCount, 1);
      expect(call.viewerState, CallParticipantState.invited);
      expect(call.stateOf('ana'), CallParticipantState.joined);
    });

    test('a call.started reply finds the viewer as the initiator before their id is known', () {
      final call = CallMapper.fromJson(group(states: {'ana': 'JOINED'}), isOutgoing: true);
      expect(call.viewerState, CallParticipantState.joined);
    });

    test('an old DM payload without kind or roster still reads as a DM', () {
      final call = CallMapper.fromJson(_call(), viewerId: 'me');
      expect(call.kind, CallKind.direct);
      expect(call.participants, isEmpty);
      expect(call.viewerState, isNull);
    });

    test('call.updated decodes to CallUpdated', () {
      final event = CallFrameDecoder.decode({
        'event': 'call.updated',
        'data': {
          'call': group(states: {'ana': 'JOINED', 'me': 'DECLINED'}),
        },
      }, viewerId: 'me');

      expect(event, isA<CallUpdated>());
      expect((event! as CallUpdated).call.viewerState, CallParticipantState.declined);
    });

    test('a call.updated settles an accept only once it lists the viewer JOINED', () {
      Map<String, dynamic> updated(String mine) => {
        'event': 'call.updated',
        'data': {
          'call': group(states: {'ana': 'JOINED', 'me': mine}),
        },
      };

      expect(CallFrameDecoder.settles(updated('INVITED'), 'call-1', viewerId: 'me'), isFalse);
      expect(CallFrameDecoder.settles(updated('JOINED'), 'call-1', viewerId: 'me'), isTrue);
      expect(CallFrameDecoder.ends(updated('LEFT'), 'call-1'), isTrue, reason: 'leaving a call that goes on');
    });
  });
}
