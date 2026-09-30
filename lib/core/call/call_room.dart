import 'dart:async';
import 'dart:io' show Platform;

import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show Helper;
import 'package:livekit_client/livekit_client.dart';

import '../utils/logger.dart';

/// Where the media side of a call stands. Separate from the call's own
/// status on `yello-chat`: a call can be `ACTIVE` there while this is still
/// [connecting], or [lost] after a network drop the server has not noticed.
enum CallRoomConnection {
  idle,
  connecting,
  connected,

  /// LiveKit is retrying on its own after a network blip.
  reconnecting,

  /// LiveKit gave up on the network. A fresh token and a rejoin may bring the
  /// call back.
  lost,

  /// The room was closed from the other end — deleted when the call ended,
  /// or this participant removed. Rejoining will not help; `yello-chat`'s
  /// `call.ended` is on its way with the reason.
  closed,

  /// The same user joined from another device, and LiveKit let that one in
  /// by putting this one out. The call carries on — just not here.
  replaced,
}

/// One person connected to the room, as a group call's tile draws them.
///
/// [identity] is the user id — the join token is issued "as you" — so the
/// call screen can look the name and avatar up in the conversation. [name]
/// is whatever LiveKit was told, a fallback only.
class CallRoomMember extends Equatable {
  const CallRoomMember({
    required this.identity,
    required this.isLocal,
    this.name = '',
    this.camera,
    this.screen,
    this.micEnabled = false,
    this.isSpeaking = false,
  });

  final String identity;
  final String name;
  final bool isLocal;

  /// Their camera while it is published, subscribed and unmuted.
  final VideoTrack? camera;

  /// Their screen share, same rule.
  final VideoTrack? screen;
  final bool micEnabled;
  final bool isSpeaking;

  @override
  List<Object?> get props => [identity, name, isLocal, camera, screen, micEnabled, isSpeaking];
}

/// Everything the call screen draws from the media side, as one value.
class CallRoomSnapshot {
  const CallRoomSnapshot({
    this.connection = CallRoomConnection.idle,
    this.peerJoined = false,
    this.localVideo,
    this.remoteVideo,
    this.members = const [],
    this.micEnabled = false,
    this.cameraEnabled = false,
    this.screenShareEnabled = false,
    this.speakerOn = false,
    this.frontCamera = true,
  });

  final CallRoomConnection connection;

  /// Someone else is in the room.
  final bool peerJoined;

  /// This device's camera, while it is publishing.
  final VideoTrack? localVideo;

  /// The first other person's picture — their screen share if they are
  /// sharing, else their camera. Null means "draw their avatar". What a 1:1
  /// call shows full screen.
  final VideoTrack? remoteVideo;

  /// This device first, then everyone else in the order they arrived.
  final List<CallRoomMember> members;

  final bool micEnabled;
  final bool cameraEnabled;

  /// This device is sharing its screen.
  final bool screenShareEnabled;
  final bool speakerOn;
  final bool frontCamera;
}

/// The one place `livekit_client` is touched, apart from the widget that
/// renders a [VideoTrack].
///
/// `yello-chat` decides who may call whom and hands out join tokens; the
/// audio and video themselves never pass through it. They go device ↔
/// LiveKit Cloud ↔ device, in a room named `call_<callId>` — two people for
/// a DM, up to 16 for a group. This class joins that room, publishes the
/// microphone, camera and screen, and reports what the room looks like as a
/// [CallRoomSnapshot] after every change — so `CallCubit` talks to a handful
/// of methods and one stream instead of to an SDK, and can be tested without
/// WebRTC.
///
/// One room at a time: [join] leaves any previous one first.
class CallRoom {
  CallRoom({Room Function()? createRoom}) : _createRoom = createRoom ?? _defaultRoom;

  /// Adaptive stream sizes the remote video to the widget drawing it;
  /// dynacast stops encoding layers nobody is subscribed to. Both are what
  /// the service's own client guide sets.
  static Room _defaultRoom() => Room(roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true));

  /// The service's screen-share recipe (`docs/BACKEND.md`), scaled for a
  /// phone: VP9 with three spatial × three temporal layers so every viewer
  /// gets the best layer their connection carries, VP8 for viewers that
  /// cannot decode VP9, and frame rate kept over resolution when bandwidth
  /// runs short. 30 fps / 3 Mbps rather than the desktop's 60 / 5 — the
  /// guide's own "slow machine" setting, which is what a phone encoding its
  /// own screen is.
  static const VideoPublishOptions _screenSharePublish = VideoPublishOptions(
    videoCodec: 'vp9',
    scalabilityMode: 'L3T3_KEY',
    backupVideoCodec: BackupVideoCodec(codec: 'vp8'),
    screenShareEncoding: VideoEncoding(maxFramerate: 30, maxBitrate: 3000000),
    degradationPreference: DegradationPreference.maintainFramerate,
  );

  static const ScreenShareCaptureOptions _screenShareCapture = ScreenShareCaptureOptions(
    params: VideoParametersPresets.screenShareH1080FPS30,
    maxFrameRate: 30,
  );

  final Room Function() _createRoom;
  final StreamController<CallRoomSnapshot> _updates = StreamController<CallRoomSnapshot>.broadcast();

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  CallRoomConnection _connection = CallRoomConnection.idle;
  bool _speakerOn = false;
  bool _frontCamera = true;

  Stream<CallRoomSnapshot> get updates => _updates.stream;

  bool get isInRoom => _room != null;

  /// Android only: capture needs a MediaProjection consent and a
  /// `mediaProjection` foreground service, both wired up here and in
  /// `CallService.kt`. iOS needs a Broadcast Upload Extension this app does
  /// not ship.
  bool get canShareScreen => Platform.isAndroid;

  CallRoomSnapshot get snapshot {
    final room = _room;
    final local = room?.localParticipant;
    final remotes = room?.remoteParticipants.values.toList() ?? const <RemoteParticipant>[];
    return CallRoomSnapshot(
      connection: _connection,
      peerJoined: remotes.isNotEmpty,
      localVideo: _track(local?.videoTrackPublications, TrackSource.camera),
      remoteVideo: _firstRemoteVideo(remotes),
      members: [
        if (local != null) _member(local, isLocal: true),
        for (final remote in remotes) _member(remote, isLocal: false),
      ],
      micEnabled: local?.isMicrophoneEnabled() ?? false,
      cameraEnabled: local?.isCameraEnabled() ?? false,
      screenShareEnabled: local?.isScreenShareEnabled() ?? false,
      speakerOn: _speakerOn,
      frontCamera: _frontCamera,
    );
  }

  /// Connects to the room the token names. Throws when LiveKit cannot be
  /// reached; publishing is left to [setMicrophoneEnabled] and
  /// [setCameraEnabled], whose failures (a refused permission) must not
  /// fail the call itself.
  Future<void> join({required String serverUrl, required String token, required bool speakerOn}) async {
    await leave();
    final room = _createRoom();
    _room = room;
    _frontCamera = true;
    _listener = room.createListener()
      ..on<RoomReconnectingEvent>((_) => _setConnection(room, CallRoomConnection.reconnecting))
      ..on<RoomReconnectedEvent>((_) => _setConnection(room, CallRoomConnection.connected))
      ..on<RoomDisconnectedEvent>((event) {
        appLogger.w('CallRoom: room disconnected — ${event.reason}');
        _setConnection(room, switch (event.reason) {
          DisconnectReason.duplicateIdentity => CallRoomConnection.replaced,
          DisconnectReason.participantRemoved || DisconnectReason.roomDeleted => CallRoomConnection.closed,
          _ => CallRoomConnection.lost,
        });
      })
      ..on<ParticipantConnectedEvent>((_) => _emit())
      ..on<ParticipantDisconnectedEvent>((_) => _emit())
      ..on<ParticipantNameUpdatedEvent>((_) => _emit())
      ..on<ActiveSpeakersChangedEvent>((_) => _emit())
      ..on<TrackSubscribedEvent>((_) => _emit())
      ..on<TrackUnsubscribedEvent>((_) => _emit())
      ..on<TrackMutedEvent>((_) => _emit())
      ..on<TrackUnmutedEvent>((_) => _emit())
      ..on<LocalTrackPublishedEvent>((_) => _emit())
      ..on<LocalTrackUnpublishedEvent>((_) => _emit());

    _setConnection(room, CallRoomConnection.connecting);
    try {
      await room.connect(serverUrl, token);
    } on Object {
      await leave();
      rethrow;
    }
    _setConnection(room, CallRoomConnection.connected);
    await setSpeakerOn(speakerOn);
  }

  /// Whether the microphone ended up in the requested state. False when
  /// enabling it failed — in practice, the permission was refused.
  Future<bool> setMicrophoneEnabled(bool enabled) =>
      _toggle('microphone', (local) => local.setMicrophoneEnabled(enabled));

  /// Same contract as [setMicrophoneEnabled], for the camera.
  Future<bool> setCameraEnabled(bool enabled) => _toggle('camera', (local) => local.setCameraEnabled(enabled));

  /// Shows Android's "start recording or casting?" consent. True when the
  /// user allowed it. Must come before the `mediaProjection` foreground
  /// service starts (Android 14 refuses it otherwise), and before every
  /// share — a consent token captures once.
  Future<bool> requestScreenCapture() async {
    if (!canShareScreen) return false;
    try {
      return await Helper.requestCapturePermission();
    } on Object catch (e) {
      appLogger.w('CallRoom: screen capture consent failed — $e');
      return false;
    }
  }

  /// Starts or stops publishing the screen. Starting needs
  /// [requestScreenCapture] granted and the foreground service promoted to
  /// `mediaProjection` first. Same contract as [setMicrophoneEnabled].
  Future<bool> setScreenShareEnabled(bool enabled) => _toggle('screen share', (local) async {
    if (!enabled) {
      await local.setScreenShareEnabled(false);
      return;
    }
    if (local.isScreenShareEnabled()) return;
    // Built and published by hand rather than through
    // `setScreenShareEnabled(true)`, which only takes the room's default
    // publish options — the camera's.
    final track = await LocalVideoTrack.createScreenShareTrack(_screenShareCapture);
    try {
      await local.publishVideoTrack(track, publishOptions: _screenSharePublish);
    } on Object {
      await track.stop();
      rethrow;
    }
  });

  Future<void> flipCamera() async {
    final track = snapshot.localVideo;
    if (track is! LocalVideoTrack) return;
    final next = _frontCamera ? CameraPosition.back : CameraPosition.front;
    try {
      await track.setCameraPosition(next);
      _frontCamera = next == CameraPosition.front;
    } on Object catch (e) {
      appLogger.w('CallRoom: camera flip failed — $e');
    }
    _emit();
  }

  /// Loudspeaker vs earpiece — a preference, so a wired or Bluetooth headset
  /// still wins. It is LiveKit's process-wide audio route rather than the
  /// room's, so it can be set before joining and survives a rejoin.
  Future<void> setSpeakerOn(bool on) async {
    _speakerOn = on;
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(on);
    } on Object catch (e) {
      appLogger.w('CallRoom: speaker switch failed — $e');
    }
    _emit();
  }

  /// Disconnects and releases the room. Safe to call at any time, including
  /// when there is no room.
  Future<void> leave() async {
    final room = _room;
    final listener = _listener;
    _room = null;
    _listener = null;
    if (room == null) return;
    // Listener first: a disconnect we asked for must not read as [lost].
    await listener?.dispose();
    try {
      await room.disconnect();
    } on Object catch (e) {
      appLogger.w('CallRoom: disconnect failed — $e');
    }
    await room.dispose();
    _connection = CallRoomConnection.idle;
    _emit();
  }

  Future<bool> _toggle(String what, Future<void> Function(LocalParticipant local) change) async {
    final local = _room?.localParticipant;
    if (local == null) return false;
    try {
      await change(local);
      return true;
    } on Object catch (e) {
      appLogger.w('CallRoom: $what toggle failed — $e');
      return false;
    } finally {
      _emit();
    }
  }

  static CallRoomMember _member(Participant participant, {required bool isLocal}) => CallRoomMember(
    identity: participant.identity,
    name: participant.name,
    isLocal: isLocal,
    camera: _track(participant.videoTrackPublications, TrackSource.camera),
    screen: _track(participant.videoTrackPublications, TrackSource.screenShareVideo),
    micEnabled: participant.isMicrophoneEnabled(),
    isSpeaking: participant.isSpeaking,
  );

  static VideoTrack? _firstRemoteVideo(List<RemoteParticipant> remotes) {
    for (final remote in remotes) {
      final video =
          _track(remote.videoTrackPublications, TrackSource.screenShareVideo) ??
          _track(remote.videoTrackPublications, TrackSource.camera);
      if (video != null) return video;
    }
    return null;
  }

  /// A [source] track that is published, subscribed (for a remote one) and
  /// not muted — anything less draws the avatar instead.
  static VideoTrack? _track(Iterable<TrackPublication>? publications, TrackSource source) {
    if (publications == null) return null;
    for (final publication in publications) {
      final track = publication.track;
      if (track is VideoTrack && publication.source == source && !publication.muted) return track;
    }
    return null;
  }

  /// Events from a room we already left are dropped: a late disconnect from
  /// the previous room must not mark the new one [lost].
  void _setConnection(Room room, CallRoomConnection connection) {
    if (!identical(room, _room)) return;
    _connection = connection;
    _emit();
  }

  void _emit() {
    if (!_updates.isClosed) _updates.add(snapshot);
  }
}
