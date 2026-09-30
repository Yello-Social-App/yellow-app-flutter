import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/call/call_keep_alive.dart';
import 'package:yello_social_app/core/call/call_room.dart';
import 'package:yello_social_app/core/call/call_tones.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/features/call/domain/entities/call_entity.dart';
import 'package:yello_social_app/features/call/domain/repositories/call_repository.dart';
import 'package:yello_social_app/features/call/domain/usecases/call_usecases.dart';
import 'package:yello_social_app/features/call/presentation/bloc/call_cubit.dart';
import 'package:yello_social_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:yello_social_app/features/chat/domain/usecases/chat_usecases.dart';

class _CallRepository extends Mock implements CallRepository {}

class _ChatRepository extends Mock implements ChatRepository {}

class _Room extends Mock implements CallRoom {}

class _Tones extends Mock implements CallTones {}

class _KeepAlive extends Mock implements CallKeepAlive {}

const _peer = CallPeer(name: 'Mika Tan', avatarSeed: 7);

CallEntity _call({
  String id = 'call-1',
  CallStatus status = CallStatus.ringing,
  CallEndReason? endReason,
  bool isOutgoing = true,
  CallMedia media = CallMedia.audio,
}) => CallEntity(
  id: id,
  conversationId: 'dm-1',
  initiatorId: isOutgoing ? 'me' : 'mika',
  media: media,
  status: status,
  endReason: endReason,
  createdAt: DateTime(2026, 9, 29, 10),
  answeredAt: status == CallStatus.ringing ? null : DateTime(2026, 9, 29, 10, 0, 6),
  isOutgoing: isOutgoing,
);

/// A group call in `group-1`, started by `ana`, with the viewer (`me`) at
/// [mine] in the roster.
CallEntity _group({
  CallStatus status = CallStatus.active,
  CallParticipantState mine = CallParticipantState.invited,
  CallEndReason? endReason,
  bool isOutgoing = false,
}) => CallEntity(
  id: 'call-9',
  conversationId: 'group-1',
  kind: CallKind.group,
  initiatorId: isOutgoing ? 'me' : 'ana',
  media: CallMedia.video,
  status: status,
  endReason: endReason,
  createdAt: DateTime(2026, 9, 30, 8),
  answeredAt: status == CallStatus.ringing ? null : DateTime(2026, 9, 30, 8, 0, 4),
  participants: [
    CallParticipant(userId: isOutgoing ? 'me' : 'ana', state: CallParticipantState.joined),
    CallParticipant(
      userId: 'bo',
      state: status == CallStatus.ringing ? CallParticipantState.invited : CallParticipantState.joined,
    ),
    if (!isOutgoing) CallParticipant(userId: 'me', state: mine),
  ],
  viewerState: isOutgoing ? CallParticipantState.joined : mine,
  isOutgoing: isOutgoing,
);

const _groupPeer = CallPeer(name: 'Weekend crew', avatarSeed: 3);

final _token = CallTokenEntity(
  serverUrl: 'wss://yello.livekit.cloud',
  roomName: 'call_call-1',
  token: 'jwt',
  expiresAt: DateTime(2030),
);

void main() {
  late _CallRepository calls;
  late _ChatRepository chat;
  late _Room room;
  late _Tones tones;
  late _KeepAlive keepAlive;
  late StreamController<CallEvent> events;
  late StreamController<CallRoomSnapshot> roomUpdates;
  late CallCubit cubit;

  setUpAll(() {
    registerFallbackValue(CallMedia.audio);
  });

  CallCubit build({Duration endedHold = const Duration(minutes: 1)}) => CallCubit(
    startCall: StartCallUseCase(calls),
    acceptCall: AcceptCallUseCase(calls),
    declineCall: DeclineCallUseCase(calls),
    endCall: EndCallUseCase(calls),
    getCallToken: GetCallTokenUseCase(calls),
    getActiveCall: GetActiveCallUseCase(calls),
    getConversation: GetConversationUseCase(chat),
    repository: calls,
    room: room,
    tones: tones,
    keepAlive: keepAlive,
    endedHold: endedHold,
    retryDelay: Duration.zero,
  );

  /// Lets every pending microtask and zero-length timer run.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    calls = _CallRepository();
    chat = _ChatRepository();
    room = _Room();
    tones = _Tones();
    keepAlive = _KeepAlive();
    events = StreamController<CallEvent>.broadcast();
    roomUpdates = StreamController<CallRoomSnapshot>.broadcast();

    when(() => calls.watchCalls()).thenAnswer((_) => events.stream);
    when(() => calls.getActiveCall()).thenAnswer((_) async => const Right(null));
    when(() => calls.acceptCall(any())).thenAnswer((_) async => const Right(unit));
    when(() => calls.declineCall(any())).thenAnswer((_) async => const Right(unit));
    when(() => calls.endCall(any())).thenAnswer((_) async => const Right(unit));
    when(() => calls.getCallToken(any())).thenAnswer((_) async => Right(_token));
    when(() => chat.getConversation(any())).thenAnswer((_) async => const Left(ServerFailure()));

    when(() => room.updates).thenAnswer((_) => roomUpdates.stream);
    when(() => room.isInRoom).thenReturn(false);
    when(
      () => room.join(
        serverUrl: any(named: 'serverUrl'),
        token: any(named: 'token'),
        speakerOn: any(named: 'speakerOn'),
      ),
    ).thenAnswer((_) async {});
    when(() => room.setMicrophoneEnabled(any())).thenAnswer((_) async => true);
    when(() => room.setCameraEnabled(any())).thenAnswer((_) async => true);
    when(() => room.setSpeakerOn(any())).thenAnswer((_) async {});
    when(() => room.leave()).thenAnswer((_) async {});

    when(() => tones.ring()).thenAnswer((_) async {});
    when(() => tones.ringback()).thenAnswer((_) async {});
    when(() => tones.stop()).thenAnswer((_) async {});
    when(
      () => keepAlive.hold(
        title: any(named: 'title'),
        keepScreenOn: any(named: 'keepScreenOn'),
      ),
    ).thenAnswer((_) async {});
    when(() => keepAlive.release()).thenAnswer((_) async {});
    when(() => keepAlive.setScreenCapture(any())).thenAnswer((_) async => true);
    when(() => room.canShareScreen).thenReturn(true);
    when(() => room.requestScreenCapture()).thenAnswer((_) async => true);
    when(() => room.setScreenShareEnabled(any())).thenAnswer((_) async => true);

    cubit = build()..setListening(true);
  });

  tearDown(() async {
    await cubit.close();
    await events.close();
    await roomUpdates.close();
  });

  group('placing a call', () {
    test('rings, then joins the room once the callee answers', () async {
      when(
        () => calls.startCall(
          conversationId: any(named: 'conversationId'),
          media: any(named: 'media'),
        ),
      ).thenAnswer((_) async => Right(_call()));

      final starting = cubit.startCall(conversationId: 'dm-1', media: CallMedia.audio, peer: _peer);
      expect(cubit.state.phase, CallPhase.outgoing);
      expect(cubit.state.call, isNull, reason: 'CALLING… until the server answers');
      await starting;
      expect(cubit.state.call?.status, CallStatus.ringing);
      verify(() => tones.ringback()).called(1);

      events.add(CallAccepted(_call(status: CallStatus.active, isOutgoing: false)));
      await settle();

      expect(cubit.state.phase, CallPhase.active);
      expect(cubit.state.call?.isOutgoing, isTrue, reason: 'the frame is placed by our own call, not re-derived');
      verify(() => room.join(serverUrl: 'wss://yello.livekit.cloud', token: 'jwt', speakerOn: false)).called(1);
      verify(() => room.setMicrophoneEnabled(true)).called(1);
      verifyNever(() => room.setCameraEnabled(any()));

      roomUpdates.add(const CallRoomSnapshot(connection: CallRoomConnection.connected, peerJoined: true));
      await settle();
      expect(cubit.state.peerJoined, isTrue);
    });

    test('BUSY comes back already ended and names the other person', () async {
      when(
        () => calls.startCall(
          conversationId: any(named: 'conversationId'),
          media: any(named: 'media'),
        ),
      ).thenAnswer((_) async => Right(_call(status: CallStatus.ended, endReason: CallEndReason.busy)));

      await cubit.startCall(conversationId: 'dm-1', media: CallMedia.video, peer: _peer);

      expect(cubit.state.phase, CallPhase.ended);
      expect(cubit.state.endMessage, 'Mika is on another call');
      verifyNever(() => calls.endCall(any()));
    });

    test('a refused start shows the reason and ends', () async {
      when(
        () => calls.startCall(
          conversationId: any(named: 'conversationId'),
          media: any(named: 'media'),
        ),
      ).thenAnswer((_) async => const Left(ValidationFailure('Calls are only for one-to-one chats.')));

      await cubit.startCall(conversationId: 'group-1', media: CallMedia.audio, peer: _peer);

      expect(cubit.state.phase, CallPhase.ended);
      expect(cubit.state.endMessage, 'Calls are only for one-to-one chats.');
    });

    test('hanging up before the server answers still cancels the call it made', () async {
      final reply = Completer<Either<Failure, CallEntity>>();
      when(
        () => calls.startCall(
          conversationId: any(named: 'conversationId'),
          media: any(named: 'media'),
        ),
      ).thenAnswer((_) => reply.future);

      final starting = cubit.startCall(conversationId: 'dm-1', media: CallMedia.audio, peer: _peer);
      await cubit.hangUp();
      expect(cubit.state.phase, CallPhase.ended);
      expect(cubit.state.endMessage, 'Cancelled');

      reply.complete(Right(_call()));
      await starting;
      verify(() => calls.endCall('call-1')).called(1);
      expect(cubit.state.phase, CallPhase.ended, reason: 'the late reply must not revive the call');
    });

    test('no answer reads as "No answer" to the caller', () async {
      when(
        () => calls.startCall(
          conversationId: any(named: 'conversationId'),
          media: any(named: 'media'),
        ),
      ).thenAnswer((_) async => Right(_call()));
      await cubit.startCall(conversationId: 'dm-1', media: CallMedia.audio, peer: _peer);

      events.add(CallEnded(_call(status: CallStatus.ended, endReason: CallEndReason.missed, isOutgoing: false)));
      await settle();

      expect(cubit.state.endMessage, 'No answer');
      verify(() => tones.stop()).called(greaterThanOrEqualTo(1));
    });
  });

  group('taking a call', () {
    test('rings, and answering joins on call.accepted', () async {
      events.add(CallRinging(_call(isOutgoing: false, media: CallMedia.video)));
      await settle();
      expect(cubit.state.phase, CallPhase.incoming);
      expect(cubit.state.cameraEnabled, isTrue);
      verify(() => tones.ring()).called(1);

      await cubit.accept();
      expect(cubit.state.phase, CallPhase.connecting);
      verify(() => calls.acceptCall('call-1')).called(1);
      verifyNever(
        () => room.join(
          serverUrl: any(named: 'serverUrl'),
          token: any(named: 'token'),
          speakerOn: any(named: 'speakerOn'),
        ),
      );

      events.add(CallAccepted(_call(status: CallStatus.active, isOutgoing: false, media: CallMedia.video)));
      await settle();
      expect(cubit.state.phase, CallPhase.active);
      verify(() => room.setCameraEnabled(true)).called(1);
    });

    test('declining closes at once and tells the server', () async {
      events.add(CallRinging(_call(isOutgoing: false)));
      await settle();

      await cubit.decline();

      expect(cubit.state.phase, CallPhase.idle);
      verify(() => calls.declineCall('call-1')).called(1);
    });

    test('answered on another device stops the ring here', () async {
      events.add(CallRinging(_call(isOutgoing: false)));
      await settle();

      events.add(CallAccepted(_call(status: CallStatus.active, isOutgoing: false)));
      await settle();

      expect(cubit.state.phase, CallPhase.ended);
      expect(cubit.state.endMessage, 'Answered on another device');
      verifyNever(
        () => room.join(
          serverUrl: any(named: 'serverUrl'),
          token: any(named: 'token'),
          speakerOn: any(named: 'speakerOn'),
        ),
      );
    });

    test('a caller giving up reads as a missed call', () async {
      events.add(CallRinging(_call(isOutgoing: false)));
      await settle();

      events.add(CallEnded(_call(status: CallStatus.ended, endReason: CallEndReason.cancelled, isOutgoing: false)));
      await settle();

      expect(cubit.state.endMessage, 'Missed call');
    });
  });

  group('in a call', () {
    Future<void> answerAndJoin() async {
      events.add(CallRinging(_call(isOutgoing: false)));
      await settle();
      await cubit.accept();
      events.add(CallAccepted(_call(status: CallStatus.active, isOutgoing: false)));
      await settle();
      when(() => room.isInRoom).thenReturn(true);
    }

    test('a refused microphone keeps the call and says why', () async {
      when(() => room.setMicrophoneEnabled(any())).thenAnswer((_) async => false);

      await answerAndJoin();

      expect(cubit.state.phase, CallPhase.active);
      expect(cubit.state.micEnabled, isFalse);
      expect(cubit.state.notice, contains('Microphone blocked'));
    });

    test('mute goes to the room, and a double tap sends one toggle', () async {
      await answerAndJoin();
      clearInteractions(room);

      final first = cubit.toggleMicrophone();
      final second = cubit.toggleMicrophone();
      await Future.wait([first, second]);

      expect(cubit.state.micEnabled, isFalse);
      verify(() => room.setMicrophoneEnabled(false)).called(1);
    });

    test('no token twice over ends the call for both sides', () async {
      when(() => calls.getCallToken(any())).thenAnswer((_) async => const Left(NetworkFailure()));

      await answerAndJoin();
      await settle();

      expect(cubit.state.phase, CallPhase.ended);
      expect(cubit.state.endMessage, 'Call failed — try again');
      verify(() => calls.endCall('call-1')).called(1);
    });

    test('hanging up leaves the room and ends the call', () async {
      await answerAndJoin();

      await cubit.hangUp();

      expect(cubit.state.phase, CallPhase.ended);
      expect(cubit.state.endMessage, startsWith('Call ended'));
      verify(() => calls.endCall('call-1')).called(1);
      verify(() => room.leave()).called(greaterThanOrEqualTo(1));
      verify(() => keepAlive.release()).called(greaterThanOrEqualTo(1));
    });
  });

  group('recovery after a reconnect', () {
    test('a call that ended while offline closes the screen', () async {
      events.add(CallRinging(_call(isOutgoing: false)));
      await settle();

      events.add(const CallLinkChanged(true));
      await settle();

      expect(cubit.state.phase, CallPhase.ended);
    });

    test('a call ringing for us that this device missed starts ringing', () async {
      when(() => calls.getActiveCall()).thenAnswer((_) async => Right(_call(isOutgoing: false)));

      events.add(const CallLinkChanged(true));
      await settle();

      expect(cubit.state.phase, CallPhase.incoming);
      verify(() => tones.ring()).called(1);
    });

    test('our own call placed from another device is never joined from this one', () async {
      when(() => calls.getActiveCall()).thenAnswer((_) async => Right(_call()));

      events.add(const CallLinkChanged(true));
      await settle();
      expect(cubit.state.phase, CallPhase.outgoing);

      events.add(CallAccepted(_call(status: CallStatus.active)));
      await settle();

      expect(cubit.state.phase, CallPhase.interrupted);
      verifyNever(() => calls.getCallToken(any()));
    });

    test('an active call this device is not in is offered, not joined', () async {
      when(() => calls.getActiveCall()).thenAnswer((_) async => Right(_call(status: CallStatus.active)));

      events.add(const CallLinkChanged(true));
      await settle();

      expect(cubit.state.phase, CallPhase.interrupted);
      verifyNever(() => calls.getCallToken(any()));

      await cubit.rejoin();
      expect(cubit.state.phase, CallPhase.active);
      verify(() => calls.getCallToken('call-1')).called(1);
    });
  });

  group('Accept on the incoming-call notification', () {
    test('waits for the socket, then answers the call recovery finds ringing', () async {
      when(() => calls.getActiveCall()).thenAnswer((_) async => Right(_call(isOutgoing: false)));

      cubit.answerFromNotification('call-1');
      await settle();
      // `call.accept` is a socket frame: nothing is sent before the link.
      verifyNever(() => calls.getActiveCall());
      verifyNever(() => calls.acceptCall(any()));

      events.add(const CallLinkChanged(true));
      await settle();

      expect(cubit.state.phase, CallPhase.connecting);
      verify(() => calls.acceptCall('call-1')).called(1);
    });

    test('with the link already up, looks the call up at once', () async {
      events.add(const CallLinkChanged(true));
      await settle();
      when(() => calls.getActiveCall()).thenAnswer((_) async => Right(_call(isOutgoing: false)));

      cubit.answerFromNotification('call-1');
      await settle();

      verify(() => calls.acceptCall('call-1')).called(1);
    });

    test('answers the ring already on screen', () async {
      events.add(CallRinging(_call(isOutgoing: false)));
      await settle();

      cubit.answerFromNotification('call-1');
      await settle();

      expect(cubit.state.phase, CallPhase.connecting);
      verify(() => calls.acceptCall('call-1')).called(1);
    });

    test('a call over by the time the app is up says so', () async {
      cubit.answerFromNotification('call-1');
      events.add(const CallLinkChanged(true));
      await settle();

      expect(cubit.state.phase, CallPhase.ended);
      expect(cubit.state.endMessage, 'Call ended');
      verifyNever(() => calls.acceptCall(any()));
    });

    test('never answers a different call that happens to ring', () async {
      when(() => calls.getActiveCall()).thenAnswer((_) async => Right(_call(id: 'call-2', isOutgoing: false)));

      cubit.answerFromNotification('call-1');
      events.add(const CallLinkChanged(true));
      await settle();

      expect(cubit.state.phase, CallPhase.incoming);
      verifyNever(() => calls.acceptCall(any()));
    });
  });

  group('group calls', () {
    test('someone else answering keeps this phone ringing', () async {
      events.add(CallRinging(_group(status: CallStatus.ringing)));
      await settle();
      expect(cubit.state.phase, CallPhase.incoming);
      expect(cubit.state.isGroup, isTrue);

      events.add(CallAccepted(_group()));
      await settle();

      expect(cubit.state.phase, CallPhase.incoming);
      verifyNever(() => tones.stop());
    });

    test('answering after someone else did joins on the call.updated that lists us JOINED', () async {
      events.add(CallRinging(_group(status: CallStatus.ringing)));
      await settle();
      events.add(CallAccepted(_group()));
      await settle();

      await cubit.accept();
      expect(cubit.state.phase, CallPhase.connecting);

      events.add(CallUpdated(_group(mine: CallParticipantState.joined)));
      await settle();

      expect(cubit.state.phase, CallPhase.active);
      verify(() => calls.getCallToken('call-9')).called(1);
    });

    test('answering on another device, or missing it, stops the ring', () async {
      events.add(CallRinging(_group(status: CallStatus.ringing)));
      await settle();
      events.add(CallUpdated(_group(mine: CallParticipantState.missed)));
      await settle();

      expect(cubit.state.phase, CallPhase.ended);
      expect(cubit.state.endMessage, 'Missed call');
    });

    test('the caller joins the room on the first answer', () async {
      when(
        () => calls.startCall(
          conversationId: any(named: 'conversationId'),
          media: any(named: 'media'),
        ),
      ).thenAnswer((_) async => Right(_group(status: CallStatus.ringing, isOutgoing: true)));

      await cubit.startCall(conversationId: 'group-1', media: CallMedia.video, peer: _groupPeer, isGroup: true);
      expect(cubit.state.phase, CallPhase.outgoing);

      events.add(CallAccepted(_group(isOutgoing: true)));
      await settle();

      expect(cubit.state.phase, CallPhase.active);
      expect(cubit.state.call?.isOutgoing, isTrue);
    });

    test('starting a call where one is running joins that one', () async {
      when(
        () => calls.startCall(
          conversationId: any(named: 'conversationId'),
          media: any(named: 'media'),
        ),
      ).thenAnswer((_) async => Right(_group(mine: CallParticipantState.joined)));

      await cubit.startCall(conversationId: 'group-1', media: CallMedia.video, peer: _groupPeer, isGroup: true);
      await settle();

      expect(cubit.state.phase, CallPhase.active);
      verify(() => calls.getCallToken('call-9')).called(1);
    });

    test('Join call accepts, then enters the room once the server lists us', () async {
      await cubit.joinCall(
        call: _group(mine: CallParticipantState.declined),
        peer: _groupPeer,
      );
      verify(() => calls.acceptCall('call-9')).called(1);
      expect(cubit.state.phase, CallPhase.connecting);

      events.add(CallUpdated(_group(mine: CallParticipantState.joined)));
      await settle();

      expect(cubit.state.phase, CallPhase.active);
    });

    test('a full call says so and closes', () async {
      when(() => calls.acceptCall(any())).thenAnswer((_) async => const Left(ServerFailure('This call is full.')));

      await cubit.joinCall(
        call: _group(mine: CallParticipantState.left),
        peer: _groupPeer,
      );

      expect(cubit.state.phase, CallPhase.ended);
      expect(cubit.state.endMessage, 'This call is full.');
    });

    Future<void> inGroupCall() async {
      await cubit.joinCall(
        call: _group(mine: CallParticipantState.left),
        peer: _groupPeer,
      );
      events.add(CallUpdated(_group(mine: CallParticipantState.joined)));
      await settle();
      when(() => room.isInRoom).thenReturn(true);
    }

    test('hanging up leaves — the call goes on for the others', () async {
      await inGroupCall();

      await cubit.hangUp();

      expect(cubit.state.endMessage, startsWith('You left'));
      verify(() => calls.endCall('call-9')).called(1);
    });

    test('a roster that no longer lists us JOINED closes the call here', () async {
      await inGroupCall();

      events.add(CallUpdated(_group(mine: CallParticipantState.left)));
      await settle();

      expect(cubit.state.phase, CallPhase.ended);
      expect(cubit.state.endMessage, 'You’re no longer in this call');
      verifyNever(() => calls.endCall(any()));
    });

    test('others leaving just updates the roster', () async {
      await inGroupCall();

      events.add(CallUpdated(_group(mine: CallParticipantState.joined)));
      await settle();

      expect(cubit.state.phase, CallPhase.active);
    });

    test('a group ringing us found on reconnect rings, even though it is already ACTIVE', () async {
      when(() => calls.getActiveCall()).thenAnswer((_) async => Right(_group()));

      events.add(const CallLinkChanged(true));
      await settle();

      expect(cubit.state.phase, CallPhase.incoming);
    });

    test('sharing the screen asks, promotes the service, then publishes', () async {
      await inGroupCall();

      await cubit.toggleScreenShare();

      verifyInOrder([
        () => room.requestScreenCapture(),
        () => keepAlive.setScreenCapture(true),
        () => room.setScreenShareEnabled(true),
      ]);
      expect(cubit.state.screenSharing, isTrue);

      await cubit.toggleScreenShare();
      verify(() => room.setScreenShareEnabled(false)).called(1);
      verify(() => keepAlive.setScreenCapture(false)).called(1);
      expect(cubit.state.screenSharing, isFalse);
    });

    test('a refused capture consent changes nothing', () async {
      when(() => room.requestScreenCapture()).thenAnswer((_) async => false);
      await inGroupCall();

      await cubit.toggleScreenShare();

      verifyNever(() => keepAlive.setScreenCapture(true));
      verifyNever(() => room.setScreenShareEnabled(true));
      expect(cubit.state.screenSharing, isFalse);
    });
  });

  test('the ended screen gives way to idle, and the socket is let go if nobody wants it', () async {
    await cubit.close();
    cubit = build(endedHold: Duration.zero)..setListening(true);
    await settle();
    events.add(CallRinging(_call(isOutgoing: false)));
    await settle();

    cubit.setListening(false);
    expect(events.hasListener, isTrue, reason: 'a live call keeps the socket');

    events.add(CallEnded(_call(status: CallStatus.ended, endReason: CallEndReason.missed, isOutgoing: false)));
    await settle();
    await settle();

    expect(cubit.state.phase, CallPhase.idle);
    expect(events.hasListener, isFalse);
  });
}
