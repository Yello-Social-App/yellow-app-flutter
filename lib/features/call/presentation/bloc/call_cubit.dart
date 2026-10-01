import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart' show VideoTrack;

import '../../../../core/call/call_keep_alive.dart';
import '../../../../core/call/call_room.dart';
import '../../../../core/call/call_tones.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../../chat/domain/entities/conversation_entity.dart';
import '../../../chat/domain/usecases/chat_usecases.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/entities/call_log_entry.dart';
import '../../domain/repositories/call_repository.dart';
import '../../domain/usecases/call_log_usecases.dart';
import '../../domain/usecases/call_usecases.dart';

/// Where the one call on this device stands, as the screen sees it.
enum CallPhase {
  idle,

  /// The viewer is calling. [CallState.call] is null until the server has
  /// answered `call.start`, then holds the ringing call.
  outgoing,

  /// Someone is calling the viewer.
  incoming,

  /// Answered or joining: fetching a join token and entering the media room.
  connecting,

  /// In the room. Whether anyone else has arrived yet is
  /// [CallState.peerJoined].
  active,

  /// A live call found on reconnect that this device is not part of — the
  /// app restarted mid-call, or the call is running on the viewer's other
  /// device. Offers Rejoin or End rather than joining on its own: a second
  /// device of the same user joining would put the first one out of the room.
  interrupted,

  /// Over — or, in a group, over *for the viewer*. [CallState.endMessage]
  /// says why, for a moment, then [idle].
  ended,
}

class CallState extends Equatable {
  const CallState({
    this.phase = CallPhase.idle,
    this.call,
    this.kind = CallKind.direct,
    this.peer = const CallPeer.unknown(),
    this.members = const {},
    this.media = CallMedia.audio,
    this.micEnabled = true,
    this.cameraEnabled = false,
    this.speakerOn = false,
    this.frontCamera = true,
    this.screenSharing = false,
    this.peerJoined = false,
    this.isReconnecting = false,
    this.localVideo,
    this.remoteVideo,
    this.roomMembers = const [],
    this.isMinimized = false,
    this.endMessage,
    this.notice,
  });

  final CallPhase phase;
  final CallEntity? call;

  /// Known before [call] is: a call placed from a group chat is a group call
  /// from the first frame of the screen.
  final CallKind kind;

  /// The other person of a DM, or the group itself.
  final CallPeer peer;

  /// A group's members by user id, for the tiles — resolved from the
  /// conversation, since neither the call nor the room carries names.
  final Map<String, CallPeer> members;
  final CallMedia media;

  /// What the viewer asked for. Applied to the room once it is joined, so a
  /// callee can answer a video call with the camera already off.
  final bool micEnabled;
  final bool cameraEnabled;
  final bool speakerOn;
  final bool frontCamera;

  /// This device is publishing its screen.
  final bool screenSharing;

  /// Someone other than the viewer is in the room.
  final bool peerJoined;

  /// LiveKit is retrying, or a fresh token is being fetched to rejoin.
  final bool isReconnecting;

  /// SDK tracks, compared by identity: only a new track is a change.
  final VideoTrack? localVideo;
  final VideoTrack? remoteVideo;

  /// Everyone connected to the media, this device first — a group call's
  /// tiles. Who the *server* counts as in the call is `call.participants`.
  final List<CallRoomMember> roomMembers;

  /// The call is shrunk to a pill over the app, so the chat (or anything
  /// else) can be used while it runs.
  final bool isMinimized;

  /// Why the call ended, shown in [CallPhase.ended].
  final String? endMessage;

  /// A passing remark while the call goes on — a refused permission.
  final String? notice;

  bool get isVideo => media == CallMedia.video;
  bool get isGroup => kind == CallKind.group;

  bool get isVisible => phase != CallPhase.idle;

  /// Anything but idle or ended: a call is ringing, connecting or running.
  bool get isLive => phase != CallPhase.idle && phase != CallPhase.ended;

  /// Someone's screen share, theirs before the viewer's own — what a group
  /// call shows large above the tiles.
  CallRoomMember? get sharing {
    CallRoomMember? own;
    for (final member in roomMembers) {
      if (member.screen == null) continue;
      if (!member.isLocal) return member;
      own = member;
    }
    return own;
  }

  static const Object _unset = Object();

  CallState copyWith({
    CallPhase? phase,
    Object? call = _unset,
    CallPeer? peer,
    Map<String, CallPeer>? members,
    bool? micEnabled,
    bool? cameraEnabled,
    bool? speakerOn,
    bool? frontCamera,
    bool? screenSharing,
    bool? peerJoined,
    bool? isReconnecting,
    Object? localVideo = _unset,
    Object? remoteVideo = _unset,
    List<CallRoomMember>? roomMembers,
    bool? isMinimized,
    Object? endMessage = _unset,
    Object? notice = _unset,
  }) => CallState(
    phase: phase ?? this.phase,
    call: identical(call, _unset) ? this.call : call as CallEntity?,
    kind: kind,
    peer: peer ?? this.peer,
    members: members ?? this.members,
    media: media,
    micEnabled: micEnabled ?? this.micEnabled,
    cameraEnabled: cameraEnabled ?? this.cameraEnabled,
    speakerOn: speakerOn ?? this.speakerOn,
    frontCamera: frontCamera ?? this.frontCamera,
    screenSharing: screenSharing ?? this.screenSharing,
    peerJoined: peerJoined ?? this.peerJoined,
    isReconnecting: isReconnecting ?? this.isReconnecting,
    localVideo: identical(localVideo, _unset) ? this.localVideo : localVideo as VideoTrack?,
    remoteVideo: identical(remoteVideo, _unset) ? this.remoteVideo : remoteVideo as VideoTrack?,
    roomMembers: roomMembers ?? this.roomMembers,
    isMinimized: isMinimized ?? this.isMinimized,
    endMessage: identical(endMessage, _unset) ? this.endMessage : endMessage as String?,
    notice: identical(notice, _unset) ? this.notice : notice as String?,
  );

  @override
  List<Object?> get props => [
    phase,
    call,
    kind,
    peer,
    members,
    media,
    micEnabled,
    cameraEnabled,
    speakerOn,
    frontCamera,
    screenSharing,
    peerJoined,
    isReconnecting,
    localVideo,
    remoteVideo,
    roomMembers,
    isMinimized,
    endMessage,
    notice,
  ];
}

/// `1:05`, `12:40`, `1:02:09`.
String formatCallDuration(Duration duration) {
  final d = duration.isNegative ? Duration.zero : duration;
  final minutes = d.inMinutes.remainder(60).toString().padLeft(d.inHours > 0 ? 2 : 1, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$minutes:$seconds' : '$minutes:$seconds';
}

/// The one call this device can be in, from the first ring to the last word.
///
/// A **singleton**, deliberately: a user is in at most one call at a time
/// across every device (the server's rule), the call outlives whichever
/// screen started it, and the call UI that reads this sits above the router
/// rather than on any route (`CallHost`). Staleness is not a risk the way it
/// is for a list cubit — every change is pushed over the socket, and a
/// (re)connect re-reads the server's `GET /ws/calls/active` ([_recover]).
///
/// Who holds the socket: [setListening], driven by `CallHost` — while the app
/// is foregrounded and signed in, and for as long as a call is live whatever
/// the lifecycle says. Only a device with a live connection rings *here*;
/// one off screen is rung by a push (`core/notifications/call_alert.dart`),
/// and Accept on that comes back in through [answerFromNotification].
///
/// **DM and group calls share one flow**, and part ways where the server's
/// rules do: in a group `call.end` means *leave* (the call goes on while two
/// remain), `call.accepted` goes to every member, and the viewer's own
/// roster entry — not which frame arrived — says whether to keep ringing,
/// stay, or close ([_onRoster]).
///
/// The media — LiveKit — is [CallRoom]'s business; this cubit decides *when*
/// to join, leave or rejoin, and folds the room's snapshots into [CallState].
class CallCubit extends Cubit<CallState> {
  CallCubit({
    required StartCallUseCase startCall,
    required AcceptCallUseCase acceptCall,
    required DeclineCallUseCase declineCall,
    required EndCallUseCase endCall,
    required GetCallTokenUseCase getCallToken,
    required GetActiveCallUseCase getActiveCall,
    required GetConversationUseCase getConversation,
    required RecordCallUseCase recordCall,
    required ClearCallLogUseCase clearCallLog,
    required CallRepository repository,
    required CallRoom room,
    required CallTones tones,
    required CallKeepAlive keepAlive,
    this.endedHold = const Duration(milliseconds: 1800),
    this.retryDelay = const Duration(seconds: 1),
  }) : _startCall = startCall,
       _acceptCall = acceptCall,
       _declineCall = declineCall,
       _endCall = endCall,
       _getCallToken = getCallToken,
       _getActiveCall = getActiveCall,
       _getConversation = getConversation,
       _recordCall = recordCall,
       _clearCallLog = clearCallLog,
       _repository = repository,
       _room = room,
       _tones = tones,
       _keepAlive = keepAlive,
       super(const CallState()) {
    _roomSub = _room.updates.listen(_onRoom);
  }

  final StartCallUseCase _startCall;
  final AcceptCallUseCase _acceptCall;
  final DeclineCallUseCase _declineCall;
  final EndCallUseCase _endCall;
  final GetCallTokenUseCase _getCallToken;
  final GetActiveCallUseCase _getActiveCall;
  final GetConversationUseCase _getConversation;

  /// The chat thread's call lines. The server writes none (`docs/BACKEND.md`),
  /// so each call is noted on the device as it ends — see [_log].
  final RecordCallUseCase _recordCall;
  final ClearCallLogUseCase _clearCallLog;

  /// For [CallRepository.watchCalls] alone — a stream has no single result
  /// for a `UseCase` to carry. Same exception `ChatCubit` makes for
  /// `watchEvents`.
  final CallRepository _repository;
  final CallRoom _room;
  final CallTones _tones;

  /// The Android foreground service that keeps the microphone alive off
  /// screen (and carries a screen share), and the keep-screen-on flag for
  /// video. Held from the moment a call is placed or answered — both happen
  /// with the app on screen, which is the only time Android lets the service
  /// start.
  final CallKeepAlive _keepAlive;

  /// How long the ended screen stays up before the call UI goes away.
  final Duration endedHold;

  /// Pause before another go at joining the room.
  final Duration retryDelay;

  static const Duration _noticeFor = Duration(seconds: 4);

  /// How long a closed room waits for `call.ended` to say why before the
  /// screen closes on its own.
  static const Duration _closedGrace = Duration(seconds: 3);

  StreamSubscription<CallEvent>? _sub;
  late final StreamSubscription<CallRoomSnapshot> _roomSub;
  Timer? _endedTimer;
  Timer? _noticeTimer;
  Timer? _closedTimer;

  bool _wantsListening = false;

  /// The socket is up, as the last [CallLinkChanged] said. `call.accept` is a
  /// socket frame, so an answer from the notification waits for this.
  bool _linkLive = false;

  /// Accept was pressed on the incoming-call notification for this call, and
  /// the call is not on screen yet — it is answered the moment the socket's
  /// recovery (or its `call.ringing`) puts it there. See
  /// [answerFromNotification].
  String? _answerOnRing;
  bool _recovering = false;
  bool _joining = false;
  bool _rejoining = false;
  int _rejoins = 0;

  /// This device is the one that belongs in the media room: it placed the
  /// call, answered it, joined it, or chose Rejoin. `call.accepted` reaches
  /// every device of every member, and only this one may act on it by
  /// joining — LiveKit admits one participant per user, so a second device
  /// joining would put the first one out of its own call.
  bool _joinsHere = false;

  /// Bumped whenever a call starts or finishes. Every await re-checks it, so
  /// an answer that lands after the user moved on (a token for a call they
  /// already hung up) is dropped instead of reviving the old call.
  int _session = 0;

  /// In-flight guards for the controls — the `FeedCubit._pendingReactions`
  /// shape. A double tap on mute must not send two opposite toggles.
  final Set<String> _pendingControls = {};

  /// Whether this platform can publish its screen at all (Android only).
  bool get canShareScreen => _room.canShareScreen;

  // ---------------------------------------------------------------------------
  // Listening
  // ---------------------------------------------------------------------------

  /// Hold the socket for calls, or let it go. Letting go is deferred while a
  /// call is live: a backgrounded or locked phone mid-call still has to hear
  /// `call.ended`.
  void setListening(bool wanted) {
    _wantsListening = wanted;
    if (wanted) {
      _sub ??= _repository.watchCalls().listen(_onEvent);
    } else if (!state.isLive) {
      _stopListening();
    }
  }

  void _stopListening() {
    unawaited(_sub?.cancel());
    _sub = null;
    _linkLive = false;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Rings everyone else in the conversation — the other person of a DM, or
  /// every free member of a group. With a call already live this just brings
  /// its screen back — one call at a time. In a group whose call is already
  /// running, the server's answer is to join that one, and this does.
  Future<void> startCall({
    required String conversationId,
    required CallMedia media,
    required CallPeer peer,
    bool isGroup = false,
  }) async {
    if (state.isLive) {
      expand();
      return;
    }
    final session = _nextSession();
    _joinsHere = true;
    emit(
      CallState(
        phase: CallPhase.outgoing,
        kind: isGroup ? CallKind.group : CallKind.direct,
        peer: peer,
        media: media,
        cameraEnabled: media == CallMedia.video,
        speakerOn: media == CallMedia.video,
      ),
    );
    unawaited(_tones.ringback());
    unawaited(_holdOffScreen());
    if (isGroup) unawaited(_resolvePeer(conversationId, session));

    final result = await _startCall(StartCallParams(conversationId: conversationId, media: media));
    if (isClosed || session != _session) {
      // Hung up before the server answered: the call it made must not be
      // left ringing on the other side.
      result.fold((_) {}, (call) {
        if (call.isLive) unawaited(_endCall(call.id));
      });
      return;
    }
    result.fold((failure) => _finish(message: failure.message), (call) {
      // BUSY comes back already ended: nothing rang anywhere.
      if (!call.isLive) {
        _log(call);
        return _finish(call: call, message: _endCopy(call));
      }
      if (call.status == CallStatus.active) {
        // The group's call was already running and we joined it instead.
        unawaited(_tones.stop());
        emit(state.copyWith(phase: CallPhase.connecting, call: call));
        unawaited(_join());
        return;
      }
      emit(state.copyWith(call: call));
    });
  }

  /// Joins a group call already under way — the chat's "Join call" bar.
  /// Works after declining, missing it, leaving, or being added to the group
  /// later; the media join starts once the server lists the viewer JOINED.
  Future<void> joinCall({required CallEntity call, required CallPeer peer}) async {
    if (state.isLive) {
      expand();
      return;
    }
    final session = _nextSession();
    _joinsHere = true;
    emit(
      CallState(
        phase: CallPhase.connecting,
        call: call,
        kind: call.kind,
        peer: peer,
        media: call.media,
        cameraEnabled: call.isVideo,
        speakerOn: call.isVideo,
      ),
    );
    unawaited(_holdOffScreen());
    unawaited(_resolvePeer(call.conversationId, session));
    final result = await _acceptCall(call.id);
    if (isClosed || session != _session) return;
    result.fold((failure) => _finish(call: call, message: failure.message), (_) {});
  }

  Future<void> accept() async {
    final call = state.call;
    if (state.phase != CallPhase.incoming || call == null) return;
    final session = _session;
    _joinsHere = true;
    unawaited(_tones.stop());
    emit(state.copyWith(phase: CallPhase.connecting));
    unawaited(_holdOffScreen());
    // The join itself starts on `call.accepted` (or, joining a group call
    // someone else answered first, `call.updated`), which the server sends
    // to this socket too — see [_onAccepted] and [_onRoster]. This only has
    // to surface a refusal.
    final result = await _acceptCall(call.id);
    if (isClosed || session != _session) return;
    result.fold((failure) => _finish(call: call, message: failure.message), (_) {});
  }

  /// Accept pressed on the incoming-call notification. That press usually
  /// *started* the app, so the call is not on screen yet and the socket may
  /// not be up: remember it, and answer once recovery shows the call ringing
  /// here ([_answerIfAsked]). A call that is over by then closes on "Call
  /// ended" instead ([_reconcile]).
  void answerFromNotification(String callId) {
    if (state.isLive) {
      if (state.phase == CallPhase.incoming && state.call?.id == callId) unawaited(accept());
      return;
    }
    _answerOnRing = callId;
    // Link already up (the app was only backgrounded): recovery will not
    // come on its own, so ask now. Otherwise the link coming up asks.
    if (_linkLive) unawaited(_recover());
  }

  /// Answers [call] if Accept was pressed on its notification.
  void _answerIfAsked(CallEntity call) {
    if (_answerOnRing != call.id) return;
    _answerOnRing = null;
    unawaited(accept());
  }

  Future<void> decline() async {
    final call = state.call;
    if (state.phase != CallPhase.incoming || call == null) return;
    _nextSession();
    unawaited(_tones.stop());
    unawaited(_keepAlive.release());
    // Closes at once: the one who declined does not need to be told.
    emit(const CallState());
    // A DM ends on this decline; a group call rings on for the others, and
    // its own `call.ended` says how it went.
    if (!call.isGroup) _log(call, endReason: CallEndReason.declined);
    if (!_wantsListening) _stopListening();
    // Nothing to do if this fails — every refusal means there is no longer a
    // ringing call to decline.
    unawaited(_declineCall(call.id));
  }

  /// Cancel while it rings, or hang up once answered — in a group, leave.
  Future<void> hangUp() async {
    final call = state.call;
    switch (state.phase) {
      case CallPhase.idle || CallPhase.ended:
        return;
      case CallPhase.incoming:
        return decline();
      case CallPhase.outgoing:
        _finish(call: call, message: 'Cancelled');
        if (call != null) _log(call, endReason: CallEndReason.cancelled);
      case CallPhase.connecting || CallPhase.active || CallPhase.interrupted:
        _finish(call: call, message: _hangUpCopy(call));
        // Leaving a group call does not end it.
        if (call != null && !call.isGroup) _log(call, endReason: CallEndReason.hangup);
    }
    if (call != null) unawaited(_endCall(call.id));
  }

  /// Enter a call found running on reconnect ([CallPhase.interrupted]).
  Future<void> rejoin() async {
    if (state.phase != CallPhase.interrupted || state.call == null) return;
    _joinsHere = true;
    emit(state.copyWith(phase: CallPhase.connecting));
    unawaited(_holdOffScreen());
    await _join();
  }

  Future<void> toggleMicrophone() => _control('mic', () async {
    final next = !state.micEnabled;
    emit(state.copyWith(micEnabled: next));
    if (!_room.isInRoom) return;
    final ok = await _room.setMicrophoneEnabled(next);
    if (!ok && next) {
      emit(state.copyWith(micEnabled: false));
      _notify('Microphone blocked — allow it in Settings to be heard.');
    }
  });

  Future<void> toggleCamera() => _control('camera', () async {
    final next = !state.cameraEnabled;
    emit(state.copyWith(cameraEnabled: next));
    if (!_room.isInRoom) return;
    final ok = await _room.setCameraEnabled(next);
    if (!ok && next) {
      emit(state.copyWith(cameraEnabled: false));
      _notify('Camera blocked — allow it in Settings to be seen.');
    }
  });

  Future<void> flipCamera() => _control('flip', () async {
    if (!state.cameraEnabled || !_room.isInRoom) return;
    await _room.flipCamera();
  });

  Future<void> toggleSpeaker() => _control('speaker', () async {
    final next = !state.speakerOn;
    emit(state.copyWith(speakerOn: next));
    await _room.setSpeakerOn(next);
  });

  /// Share this phone's screen with the call, or stop. Android asks the user
  /// first every time; the foreground service then has to carry the
  /// `mediaProjection` type before the capture may start.
  Future<void> toggleScreenShare() => _control('screen', () async {
    if (state.phase != CallPhase.active || !_room.isInRoom || !canShareScreen) return;
    final session = _session;
    if (state.screenSharing) {
      emit(state.copyWith(screenSharing: false));
      await _room.setScreenShareEnabled(false);
      await _keepAlive.setScreenCapture(false);
      return;
    }
    if (!await _room.requestScreenCapture()) return;
    if (isClosed || session != _session) return;
    if (!await _keepAlive.setScreenCapture(true)) {
      _notify('Screen sharing couldn’t start — try again.');
      return;
    }
    if (isClosed || session != _session) return;
    if (!await _room.setScreenShareEnabled(true)) {
      await _keepAlive.setScreenCapture(false);
      _notify('Screen sharing couldn’t start — try again.');
      return;
    }
    if (isClosed || session != _session) return;
    emit(state.copyWith(screenSharing: true));
  });

  void minimize() {
    if (state.isVisible && !state.isMinimized) emit(state.copyWith(isMinimized: true));
  }

  void expand() {
    if (state.isMinimized) emit(state.copyWith(isMinimized: false));
  }

  /// Sign-out. Leaves a live call on the way out rather than leaving the
  /// others talking to a room nobody is in.
  Future<void> reset() async {
    final call = state.call;
    if (call != null && state.isLive) unawaited(_endCall(call.id));
    _nextSession();
    _answerOnRing = null;
    _wantsListening = false;
    _stopListening();
    // The call lines are the signed-out account's; the next one starts clean.
    unawaited(_clearCallLog(const NoParams()));
    await _tones.stop();
    await _room.leave();
    await _keepAlive.release();
    if (!isClosed) emit(const CallState());
  }

  // ---------------------------------------------------------------------------
  // Server events
  // ---------------------------------------------------------------------------

  void _onEvent(CallEvent event) {
    if (isClosed) return;
    switch (event) {
      case CallLinkChanged(:final isLive):
        _linkLive = isLive;
        if (isLive) unawaited(_recover());
      case CallRinging(:final call):
        _onRinging(call);
      case CallAccepted(:final call):
        _onAccepted(call);
      case CallUpdated(:final call):
        _onUpdated(call);
      case CallEnded(:final call):
        _logEnded(call);
        _onEnded(call);
    }
  }

  void _onRinging(CallEntity call) {
    // One call at a time — the server never rings anyone already in one, so
    // a second ring here is the same call again.
    if (state.isLive) return;
    final session = _nextSession();
    _joinsHere = false;
    emit(
      CallState(
        phase: CallPhase.incoming,
        call: call,
        kind: call.kind,
        media: call.media,
        cameraEnabled: call.isVideo,
        speakerOn: call.isVideo,
      ),
    );
    unawaited(_tones.ring());
    unawaited(_resolvePeer(call.conversationId, session));
    _answerIfAsked(call);
  }

  /// The frame's copy of [id]'s call, or null when it is about another call
  /// (or none is live here). Keeps which side this device is on.
  CallEntity? _current(CallEntity incoming) {
    final current = state.call;
    if (current == null || current.id != incoming.id || !state.isLive) return null;
    return incoming.copyWith(isOutgoing: current.isOutgoing);
  }

  void _onAccepted(CallEntity accepted) {
    final call = _current(accepted);
    if (call == null) return;
    if (call.isGroup) return _onRoster(call);
    final current = state.call!;
    // Each branch acts once: a repeated frame (or the recovery lookup finding
    // the same answer) must not start a second join.
    if (current.isOutgoing) {
      if (state.phase != CallPhase.outgoing) return;
      unawaited(_tones.stop());
      if (!_joinsHere) {
        // Placed from another of the viewer's devices (found on reconnect):
        // that device joins; this one offers to take the call over.
        emit(state.copyWith(phase: CallPhase.interrupted, call: call));
        return;
      }
      emit(state.copyWith(phase: CallPhase.connecting, call: call));
      unawaited(_join());
    } else if (_joinsHere) {
      if (state.phase != CallPhase.connecting || _room.isInRoom) return;
      emit(state.copyWith(call: call));
      unawaited(_join());
    } else if (state.phase == CallPhase.incoming) {
      // Another of the viewer's devices picked it up.
      _finish(call: call, message: 'Answered on another device');
    }
  }

  void _onUpdated(CallEntity updated) {
    final call = _current(updated);
    if (call == null) return;
    if (call.isGroup) return _onRoster(call);
    emit(state.copyWith(call: call));
  }

  /// A group call's `call.accepted` or `call.updated`. The status says
  /// whether it has been answered; the viewer's own roster entry says what
  /// this device does about it.
  void _onRoster(CallEntity call) {
    final mine = call.viewerState;
    switch (state.phase) {
      case CallPhase.outgoing:
        // The caller is JOINED from the start; the first answer is the cue
        // to enter the room.
        if (call.status == CallStatus.active) {
          unawaited(_tones.stop());
          if (!_joinsHere) {
            emit(state.copyWith(phase: CallPhase.interrupted, call: call));
            return;
          }
          emit(state.copyWith(phase: CallPhase.connecting, call: call));
          unawaited(_join());
        } else {
          emit(state.copyWith(call: call));
        }
      case CallPhase.incoming:
        switch (mine) {
          case CallParticipantState.invited || null:
            // Someone else answered; this phone keeps ringing.
            emit(state.copyWith(call: call));
          case CallParticipantState.joined:
            _finish(call: call, message: 'Answered on another device');
          case CallParticipantState.missed:
            _finish(call: call, message: 'Missed call');
          case CallParticipantState.declined || CallParticipantState.left || CallParticipantState.busy:
            _finish(call: call, message: 'Call ended');
        }
      case CallPhase.connecting:
        emit(state.copyWith(call: call));
        if (_joinsHere && mine == CallParticipantState.joined && !_room.isInRoom) unawaited(_join());
      case CallPhase.active || CallPhase.interrupted:
        if (mine != null && mine != CallParticipantState.joined) {
          // Left on another device, or removed from the group.
          _finish(call: call, message: 'You’re no longer in this call');
        } else {
          emit(state.copyWith(call: call));
        }
      case CallPhase.idle || CallPhase.ended:
        break;
    }
  }

  void _onEnded(CallEntity ended) {
    final call = _current(ended);
    if (call == null) return;
    _finish(call: call, message: _endCopy(call));
  }

  /// After every socket (re)connect: whatever changed while it was down was
  /// not queued for this client, so ask the server what is live now.
  Future<void> _recover() async {
    if (_recovering) return;
    _recovering = true;
    final session = _session;
    try {
      final result = await _getActiveCall(const NoParams());
      // A frame that landed meanwhile is fresher than this answer.
      if (isClosed || session != _session) return;
      result.fold((failure) => appLogger.w('CallCubit: active-call lookup failed — ${failure.message}'), _reconcile);
    } finally {
      _recovering = false;
    }
  }

  void _reconcile(CallEntity? active) {
    final current = state.call;
    // `call.start` is in flight; its own reply is the authority.
    if (state.phase == CallPhase.outgoing && current == null) return;

    if (active == null) {
      // The call ended (or the viewer left it) while the socket was down,
      // and its frame went nowhere.
      if (state.isLive && current != null) {
        _finish(call: current, message: 'Call ended');
      } else if (_answerOnRing != null) {
        // Accept on the notification, for a call that was over before the
        // app got here — say so rather than open on nothing.
        _answerOnRing = null;
        _finish(message: 'Call ended');
      }
      return;
    }
    // Accept was pressed for a different call than the one live now.
    if (_answerOnRing != active.id) _answerOnRing = null;
    if (current != null && current.id == active.id && state.isLive) {
      // Answered while this caller was offline.
      if (active.status == CallStatus.active && state.phase == CallPhase.outgoing) {
        _onAccepted(active);
      } else if (active.isGroup) {
        _onRoster(active.copyWith(isOutgoing: current.isOutgoing));
      }
      return;
    }

    // A live call this device is not showing.
    unawaited(_tones.stop());
    unawaited(_room.leave());
    final session = _nextSession();
    _joinsHere = false;
    final CallPhase phase;
    if (active.isGroup && active.viewerState == CallParticipantState.invited) {
      // A group call can be running while the viewer is still being rung.
      phase = CallPhase.incoming;
    } else if (active.status == CallStatus.active) {
      phase = CallPhase.interrupted;
    } else {
      phase = active.isOutgoing ? CallPhase.outgoing : CallPhase.incoming;
    }
    emit(
      CallState(
        phase: phase,
        call: active,
        kind: active.kind,
        media: active.media,
        cameraEnabled: active.isVideo,
        speakerOn: active.isVideo,
      ),
    );
    if (phase == CallPhase.incoming) unawaited(_tones.ring());
    if (phase == CallPhase.outgoing) unawaited(_tones.ringback());
    unawaited(_resolvePeer(active.conversationId, session));
    if (phase == CallPhase.incoming) _answerIfAsked(active);
  }

  // ---------------------------------------------------------------------------
  // Media
  // ---------------------------------------------------------------------------

  /// Fetch a token and enter the room — twice at most, then give up and
  /// leave the call rather than keep the others talking to silence.
  Future<void> _join() async {
    final call = state.call;
    if (call == null || _joining) return;
    _joining = true;
    final session = _session;
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(retryDelay);
          if (isClosed || session != _session) return;
        }
        final token = await _getCallToken(call.id);
        if (isClosed || session != _session) return;
        final joined = await token.fold(
          (failure) async {
            appLogger.w('CallCubit: no join token — ${failure.message}');
            return false;
          },
          (ticket) async {
            try {
              await _room.join(serverUrl: ticket.serverUrl, token: ticket.token, speakerOn: state.speakerOn);
              return true;
            } on Object catch (e) {
              appLogger.w('CallCubit: could not enter the room — $e');
              return false;
            }
          },
        );
        if (isClosed || session != _session) {
          unawaited(_room.leave());
          return;
        }
        if (joined) {
          _rejoins = 0;
          await _publish(session);
          return;
        }
      }
      _finish(call: call, message: 'Call failed — try again');
      unawaited(_endCall(call.id));
    } finally {
      _joining = false;
    }
  }

  /// Microphone and camera go on after the room is joined, and each one's
  /// failure — a refused permission — costs that one device, not the call.
  Future<void> _publish(int session) async {
    emit(state.copyWith(phase: CallPhase.active, isReconnecting: false));
    if (state.micEnabled && !await _room.setMicrophoneEnabled(true)) {
      if (isClosed || session != _session) return;
      emit(state.copyWith(micEnabled: false));
      _notify('Microphone blocked — allow it in Settings to be heard.');
    }
    if (isClosed || session != _session) return;
    if (state.cameraEnabled && !await _room.setCameraEnabled(true)) {
      if (isClosed || session != _session) return;
      emit(state.copyWith(cameraEnabled: false));
      _notify('Camera blocked — allow it in Settings to be seen.');
    }
    if (isClosed || session != _session) return;
    // Again now that the microphone permission has certainly been asked: on
    // a first call this is when the service can start at all.
    await _holdOffScreen();
  }

  void _onRoom(CallRoomSnapshot room) {
    if (isClosed || (state.phase != CallPhase.active && state.phase != CallPhase.connecting)) return;
    switch (room.connection) {
      case CallRoomConnection.lost:
        unawaited(_rejoin());
        return;
      case CallRoomConnection.closed:
        // The room was deleted or this device removed from it (a member
        // taken out of the group): `call.ended` or `call.updated` is on its
        // way with the reason. Close on our own only if it never comes.
        _closedTimer ??= Timer(_closedGrace, () {
          _closedTimer = null;
          if (state.isLive) _finish(call: state.call, message: 'Call ended');
        });
        return;
      case CallRoomConnection.replaced:
        // Not an end: the call goes on, on the viewer's other device.
        _finish(call: state.call, message: 'Call moved to another device');
        return;
      case CallRoomConnection.idle ||
          CallRoomConnection.connecting ||
          CallRoomConnection.connected ||
          CallRoomConnection.reconnecting:
        break;
    }
    emit(
      state.copyWith(
        peerJoined: room.peerJoined,
        localVideo: room.localVideo,
        remoteVideo: room.remoteVideo,
        roomMembers: room.members,
        screenSharing: room.screenShareEnabled,
        frontCamera: room.frontCamera,
        isReconnecting: room.connection == CallRoomConnection.reconnecting,
      ),
    );
  }

  /// LiveKit gave up on the network. The call may still be live on the
  /// server — try again with a fresh token, a bounded number of times.
  Future<void> _rejoin() async {
    final call = state.call;
    // One attempt at a time: a lost room can report itself more than once.
    if (call == null || _joining || _rejoining) return;
    if (_rejoins >= 2) {
      _finish(call: call, message: 'Call dropped');
      unawaited(_endCall(call.id));
      return;
    }
    _rejoins++;
    _rejoining = true;
    emit(
      state.copyWith(
        isReconnecting: true,
        peerJoined: false,
        remoteVideo: null,
        localVideo: null,
        roomMembers: const [],
        screenSharing: false,
      ),
    );
    // A share does not survive the room it was published in.
    unawaited(_keepAlive.setScreenCapture(false));
    final session = _session;
    try {
      await Future<void>.delayed(retryDelay);
      if (isClosed || session != _session) return;
      await _join();
    } finally {
      _rejoining = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Starts a new call session: cancels whatever the last one had scheduled.
  int _nextSession() {
    _endedTimer?.cancel();
    _endedTimer = null;
    _closedTimer?.cancel();
    _closedTimer = null;
    _rejoins = 0;
    _joining = false;
    return ++_session;
  }

  /// Everything a call does on its way out, whoever ended it.
  void _finish({CallEntity? call, required String message}) {
    _nextSession();
    _joinsHere = false;
    unawaited(_tones.stop());
    unawaited(_room.leave());
    unawaited(_keepAlive.release());
    emit(
      state.copyWith(
        phase: CallPhase.ended,
        call: call ?? state.call,
        endMessage: message,
        peerJoined: false,
        isReconnecting: false,
        localVideo: null,
        remoteVideo: null,
        roomMembers: const [],
        screenSharing: false,
        notice: null,
      ),
    );
    _endedTimer = Timer(endedHold, () {
      _endedTimer = null;
      if (isClosed || state.phase != CallPhase.ended) return;
      emit(const CallState());
      if (!_wantsListening) _stopListening();
    });
  }

  /// Every `call.ended` this device hears, whether or not the call is on
  /// screen: the callee who declined has already closed theirs, and a group
  /// call ends long after a member left it.
  void _logEnded(CallEntity ended) {
    final known = state.call?.id == ended.id ? state.call : null;
    // The copy on screen knows which side this device is on — and the
    // conversation, should the frame abbreviate the call.
    final call = ended.conversationId.isEmpty && known != null ? known : ended.copyWith(isOutgoing: known?.isOutgoing);
    _log(call, endReason: ended.endReason);
  }

  /// Notes a finished call for its conversation's thread (`CallLogCubit`
  /// draws it). [endReason] is this device's own account of a call it ended
  /// itself; the server's `call.ended` replaces the note when it arrives.
  /// Not awaited and never surfaced: a note that could not be saved costs a
  /// line in the thread, nothing more.
  void _log(CallEntity call, {CallEndReason? endReason}) {
    if (call.id.isEmpty || call.conversationId.isEmpty) return;
    final answeredAt = call.answeredAt;
    final talkTime = call.talkTime ?? (answeredAt == null ? null : DateTime.now().difference(answeredAt));
    unawaited(_recordCall(CallLogEntry.fromCall(call, endReason: endReason, talkTime: talkTime)));
  }

  /// Names the other side — the DM's other person, or the group — and, for
  /// a group, everyone in it, for the tiles.
  Future<void> _resolvePeer(String conversationId, int session) async {
    final result = await _getConversation(conversationId);
    if (isClosed || session != _session) return;
    result.fold(
      (_) {},
      (conversation) => emit(
        state.copyWith(
          peer: CallPeer(
            name: conversation.name,
            avatarSeed: conversation.avatarSeed,
            avatarUrl: conversation.avatarUrl,
            avatarCacheKey: conversation.avatarCacheKey,
          ),
          members: conversation.isGroup ? _membersOf(conversation) : null,
        ),
      ),
    );
  }

  /// Seeded by user id the way [ConversationEntity.avatarSeed] is, so a
  /// member without a photo looks the same here as in their DM.
  static Map<String, CallPeer> _membersOf(ConversationEntity conversation) => {
    for (final p in conversation.participants)
      p.userId: CallPeer(name: p.displayName, avatarSeed: p.userId.hashCode.abs(), avatarUrl: p.avatarUrl),
  };

  /// The screen stays awake only for video, where someone is watching it.
  Future<void> _holdOffScreen() => _keepAlive.hold(title: 'Call with ${state.peer.name}', keepScreenOn: state.isVideo);

  Future<void> _control(String key, Future<void> Function() body) async {
    if (!state.isLive || !_pendingControls.add(key)) return;
    try {
      await body();
    } finally {
      _pendingControls.remove(key);
    }
  }

  void _notify(String message) {
    _noticeTimer?.cancel();
    emit(state.copyWith(notice: message));
    _noticeTimer = Timer(_noticeFor, () {
      _noticeTimer = null;
      if (!isClosed && state.notice == message) emit(state.copyWith(notice: null));
    });
  }

  /// The guide's copy, from where the viewer stands.
  String _endCopy(CallEntity call) => switch (call.endReason) {
    CallEndReason.hangup || null => _withTalkTime('Call ended', call),
    CallEndReason.declined when call.isGroup => call.isOutgoing ? 'Nobody picked up' : 'Call declined',
    CallEndReason.declined => call.isOutgoing ? 'Declined' : 'Call declined',
    CallEndReason.cancelled => call.isOutgoing ? 'Cancelled' : 'Missed call',
    CallEndReason.missed => call.isOutgoing ? 'No answer' : 'Missed call',
    CallEndReason.busy when call.isGroup => 'Everyone is on another call',
    CallEndReason.busy => '${state.peer.firstName} is on another call',
    CallEndReason.failed => 'Call failed — try again',
  };

  /// The viewer's own hang-up. Leaving a group call ends it only for them,
  /// so it says "left".
  String _hangUpCopy(CallEntity? call) => _withTalkTime(state.isGroup ? 'You left' : 'Call ended', call);

  String _withTalkTime(String lead, CallEntity? call) {
    final answeredAt = call?.answeredAt;
    if (answeredAt == null) return lead;
    final talkTime = call?.talkTime ?? DateTime.now().difference(answeredAt);
    return '$lead · ${formatCallDuration(talkTime)}';
  }

  @override
  Future<void> close() async {
    _endedTimer?.cancel();
    _noticeTimer?.cancel();
    _closedTimer?.cancel();
    await _sub?.cancel();
    await _roomSub.cancel();
    await _tones.stop();
    await _room.leave();
    await _keepAlive.release();
    return super.close();
  }
}
