import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/error/exceptions.dart';
import 'package:yello_social_app/core/network/api_client.dart';
import 'package:yello_social_app/features/call/data/datasources/call_remote_datasource.dart';
import 'package:yello_social_app/features/call/domain/entities/call_entity.dart';
import 'package:yello_social_app/features/chat/data/datasources/chat_socket.dart';

class _Socket extends Mock implements ChatSocket {}

class _ApiClient extends Mock implements ApiClient {}

class _Dio extends Mock implements Dio {}

Map<String, dynamic> _call(String status, {String? endReason}) => {
  'id': 'call-1',
  'conversationId': 'dm-1',
  'initiatorId': 'me',
  'media': 'audio',
  'status': status,
  'endReason': endReason,
  'createdAt': '2026-09-29T10:00:00.000Z',
};

/// A group call already under way, with [viewerState] for `me`.
Map<String, dynamic> _groupCall({String viewerState = 'JOINED'}) => {
  'id': 'call-9',
  'conversationId': 'group-1',
  'kind': 'GROUP',
  'initiatorId': 'ana',
  'media': 'video',
  'status': 'ACTIVE',
  'endReason': null,
  'createdAt': '2026-09-30T08:00:00.000Z',
  'answeredAt': '2026-09-30T08:00:04.000Z',
  'participants': [
    {'userId': 'ana', 'state': 'JOINED', 'joinedAt': '2026-09-30T08:00:00.000Z'},
    {'userId': 'bo', 'state': 'JOINED', 'joinedAt': '2026-09-30T08:00:04.000Z'},
    {'userId': 'me', 'state': viewerState, 'joinedAt': null},
  ],
};

void main() {
  late _Socket socket;
  late StreamController<Map<String, dynamic>> frames;
  late CallRemoteDataSourceImpl remote;
  late _Dio dio;
  late List<(String, Map<String, dynamic>)> sent;

  /// What the fake server does with each frame the client sends.
  late void Function(String event, Map<String, dynamic> data) server;

  setUp(() {
    socket = _Socket();
    frames = StreamController<Map<String, dynamic>>.broadcast();
    sent = [];
    server = (_, _) {};
    when(() => socket.isConnected).thenReturn(true);
    when(() => socket.frames).thenAnswer((_) => frames.stream);
    when(() => socket.send(any(), any())).thenAnswer((invocation) {
      final event = invocation.positionalArguments[0] as String;
      final data = invocation.positionalArguments[1] as Map<String, dynamic>;
      sent.add((event, data));
      // Delivered on a later turn, the way a real socket delivers a reply.
      scheduleMicrotask(() => server(event, data));
    });
    dio = _Dio();
    final api = _ApiClient();
    when(() => api.dio).thenReturn(dio);
    remote = CallRemoteDataSourceImpl(api, socket);
  });

  tearDown(() => frames.close());

  test('call.start carries a ref and resolves on the call.started that echoes it', () async {
    server = (event, data) {
      // Someone else's reply first — a different ref must not settle ours.
      frames.add({
        'event': 'call.started',
        'data': {'ref': 'not-ours', 'call': _call('ENDED', endReason: 'BUSY')},
      });
      frames.add({
        'event': 'call.started',
        'data': {'ref': data['ref'], 'call': _call('RINGING')},
      });
    };

    final call = await remote.startCall(conversationId: 'dm-1', media: CallMedia.audio);

    expect(sent.single.$1, 'call.start');
    expect(sent.single.$2, containsPair('conversationId', 'dm-1'));
    expect(sent.single.$2, containsPair('media', 'audio'));
    expect(sent.single.$2['ref'], isA<String>());
    expect(call.status, CallStatus.ringing);
    expect(call.isOutgoing, isTrue);
  });

  test('an error frame with our ref fails the request, worded by code and reason', () async {
    server = (event, data) => frames.add({
      'event': 'error',
      'data': {
        'ref': data['ref'],
        'code': 'CONFLICT',
        'message': 'The call is full',
        'details': {'reason': 'CALL_FULL', 'maxParticipants': 16},
      },
    });

    await expectLater(
      remote.acceptCall('call-9'),
      throwsA(
        isA<ServerException>()
            .having((e) => e.code, 'code', 'CONFLICT')
            .having((e) => e.message, 'message', 'This call is full — 16 people at most.'),
      ),
    );
  });

  test('CALL_IN_PROGRESS on call.start joins the running call instead', () async {
    server = (event, data) {
      if (event == 'call.start') {
        frames.add({
          'event': 'error',
          'data': {
            'ref': data['ref'],
            'code': 'CONFLICT',
            'message': 'A call is already going on here; join it instead',
            'details': {'reason': 'CALL_IN_PROGRESS', 'callId': 'call-9'},
          },
        });
      } else if (event == 'call.accept') {
        // Someone else's roster change first: it must not settle our accept.
        frames.add({
          'event': 'call.updated',
          'data': {'call': _groupCall(viewerState: 'INVITED')},
        });
        frames.add({
          'event': 'call.updated',
          'data': {'call': _groupCall()},
        });
      }
    };
    when(() => dio.get<Map<String, dynamic>>('/ws/conversations/group-1/call')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/ws/conversations/group-1/call'),
        data: {'call': _groupCall()},
      ),
    );

    final call = await remote.startCall(conversationId: 'group-1', media: CallMedia.video, viewerId: 'me');

    expect(sent.map((f) => f.$1), ['call.start', 'call.accept']);
    expect(sent[1].$2, containsPair('callId', 'call-9'));
    expect(call.id, 'call-9');
    expect(call.isGroup, isTrue);
    expect(call.status, CallStatus.active);
    expect(call.viewerState, CallParticipantState.joined);
  });

  test('nothing is sent while the socket is down', () async {
    when(() => socket.isConnected).thenReturn(false);

    await expectLater(remote.acceptCall('call-1'), throwsA(isA<NetworkException>()));
    expect(sent, isEmpty);
  });

  test('call.accept is settled by call.ended too (the room could not be created)', () async {
    server = (event, data) => frames.add({
      'event': 'call.ended',
      'data': {'reason': 'FAILED', 'call': _call('ENDED', endReason: 'FAILED')},
    });

    await remote.acceptCall('call-1');

    expect(sent.single.$1, 'call.accept');
    expect(sent.single.$2, containsPair('callId', 'call-1'));
  });

  test('a CONFLICT on call.end is sent again, once', () async {
    var attempts = 0;
    server = (event, data) {
      attempts++;
      if (attempts == 1) {
        frames.add({
          'event': 'error',
          'data': {
            'ref': data['ref'],
            'code': 'CONFLICT',
            'details': {'status': 'ACTIVE'},
          },
        });
      } else {
        frames.add({
          'event': 'call.ended',
          'data': {'reason': 'HANGUP', 'call': _call('ENDED', endReason: 'HANGUP')},
        });
      }
    };

    await remote.endCall('call-1');

    expect(sent.map((f) => f.$1), ['call.end', 'call.end']);
    expect(sent[0].$2['ref'], isNot(sent[1].$2['ref']));
  });
}
