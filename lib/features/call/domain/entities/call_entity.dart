import 'package:equatable/equatable.dart';

/// What the caller chose. A hint for the UI — open the camera or not — and
/// never a constraint: the callee may answer a video call with the camera off.
enum CallMedia {
  audio('audio'),
  video('video');

  const CallMedia(this.wire);
  final String wire;

  static CallMedia fromWire(Object? value) => value == 'video' ? video : audio;
}

/// A 1:1 call in a DIRECT conversation, or a call in a GROUP one.
enum CallKind {
  direct,
  group;

  static CallKind fromWire(Object? value) => value == 'GROUP' ? group : direct;
}

/// Where one member stands in a call — `participants[].state` on the wire.
enum CallParticipantState {
  /// Being rung.
  invited,

  /// In the call as far as the server knows — the caller from the start.
  /// Who is actually connected to the media comes from the LiveKit room.
  joined,

  /// Refused the ring. In a group they can still join.
  declined,

  /// Did not answer within 45 s, or was removed from the group while rung.
  missed,

  /// Was in the call and left, or was removed from the group.
  left,

  /// Was in another call when this one started, so was never rung.
  busy;

  static CallParticipantState fromWire(Object? value) => switch (value) {
    'JOINED' => joined,
    'DECLINED' => declined,
    'MISSED' => missed,
    'LEFT' => left,
    'BUSY' => busy,
    _ => invited,
  };
}

/// One entry of a call's roster.
class CallParticipant extends Equatable {
  const CallParticipant({required this.userId, required this.state, this.joinedAt});

  final String userId;
  final CallParticipantState state;

  /// The latest join; null if they never joined.
  final DateTime? joinedAt;

  @override
  List<Object?> get props => [userId, state, joinedAt];
}

/// `RINGING → ACTIVE → ENDED`, or straight from `RINGING` to `ENDED`.
/// `ENDED` is final.
enum CallStatus {
  ringing,
  active,
  ended;

  static CallStatus fromWire(Object? value) => switch (value) {
    'ACTIVE' => active,
    'ENDED' => ended,
    _ => ringing,
  };
}

/// Why a call ended — set exactly when the status is `ENDED`.
enum CallEndReason {
  /// Fewer than two were left in an answered call, or LiveKit reported the
  /// room gone.
  hangup,

  /// Everyone rung refused before anyone answered.
  declined,

  /// Nobody answered within the ring timeout (45 s).
  missed,

  /// DM: the other side was in a call. Group: nobody else was free. Nobody
  /// rang; only the caller hears about it.
  busy,

  /// The caller left while it rang.
  cancelled,

  /// The first answer came but the server could not create the media room.
  failed;

  static CallEndReason? fromWire(Object? value) => switch (value) {
    'HANGUP' => hangup,
    'DECLINED' => declined,
    'MISSED' => missed,
    'BUSY' => busy,
    'CANCELLED' => cancelled,
    'FAILED' => failed,
    _ => null,
  };
}

/// One call, as `yello-chat` records it: 1:1 in a DIRECT conversation, or a
/// group call (up to 16 people) in a GROUP one. A conversation has at most
/// one live call, and a user is in at most one live (ringing or active) call
/// at a time across every conversation and device.
///
/// **`call.end` means leave.** A call ends once fewer than two people are
/// left in it — for a DM that is either side hanging up; a group call goes
/// on while two or more remain, whoever started it.
class CallEntity extends Equatable {
  const CallEntity({
    required this.id,
    required this.conversationId,
    required this.initiatorId,
    required this.media,
    required this.status,
    required this.createdAt,
    required this.isOutgoing,
    this.kind = CallKind.direct,
    this.participants = const [],
    this.viewerState,
    this.endReason,
    this.answeredAt,
    this.endedAt,
  });

  final String id;
  final String conversationId;
  final CallKind kind;

  /// Who started it. In a DM the callee is the other participant.
  final String initiatorId;
  final CallMedia media;
  final CallStatus status;
  final CallEndReason? endReason;
  final DateTime createdAt;

  /// The roster, initiator first. A member added to a group after the call
  /// started is not listed until they join.
  final List<CallParticipant> participants;

  /// The signed-in user's own entry in [participants]. Not a wire field —
  /// derived like [isOutgoing]; null when the viewer is unknown or unlisted.
  final CallParticipantState? viewerState;

  /// The first answer — what the call timer counts from.
  final DateTime? answeredAt;
  final DateTime? endedAt;

  /// Whether the signed-in user placed this call. Not a wire field: the
  /// payload names the initiator, and the repository compares that with the
  /// viewer — the same way a message's `fromMe` is derived.
  final bool isOutgoing;

  bool get isLive => status != CallStatus.ended;
  bool get isVideo => media == CallMedia.video;
  bool get isGroup => kind == CallKind.group;

  /// How many the server counts as in the call — "3 in call".
  int get joinedCount => participants.where((p) => p.state == CallParticipantState.joined).length;

  CallParticipantState? stateOf(String userId) {
    for (final p in participants) {
      if (p.userId == userId) return p.state;
    }
    return null;
  }

  /// How long it was answered for, once it has ended — null for a call that
  /// never connected.
  Duration? get talkTime {
    final start = answeredAt;
    final end = endedAt;
    if (start == null || end == null || end.isBefore(start)) return null;
    return end.difference(start);
  }

  CallEntity copyWith({CallStatus? status, CallEndReason? endReason, bool? isOutgoing}) => CallEntity(
    id: id,
    conversationId: conversationId,
    kind: kind,
    participants: participants,
    viewerState: viewerState,
    initiatorId: initiatorId,
    media: media,
    status: status ?? this.status,
    endReason: endReason ?? this.endReason,
    createdAt: createdAt,
    answeredAt: answeredAt,
    endedAt: endedAt,
    isOutgoing: isOutgoing ?? this.isOutgoing,
  );

  @override
  List<Object?> get props => [
    id,
    conversationId,
    kind,
    participants,
    viewerState,
    initiatorId,
    media,
    status,
    endReason,
    createdAt,
    answeredAt,
    endedAt,
    isOutgoing,
  ];
}

/// A LiveKit join ticket for one call. [token] is a credential: it lives in
/// memory for as long as it takes to connect, and is never logged or stored.
class CallTokenEntity {
  const CallTokenEntity({
    required this.serverUrl,
    required this.roomName,
    required this.token,
    required this.expiresAt,
  });

  /// `wss://…livekit.cloud` — handed to the room's `connect` with [token].
  final String serverUrl;

  /// `call_<callId>`. Informational; the token already names the room.
  final String roomName;
  final String token;

  /// Ten minutes after issue. Needed to *connect*, not to stay connected — a
  /// rejoin after this asks for a new one.
  final DateTime expiresAt;

  @override
  String toString() => 'CallTokenEntity($roomName, expires $expiresAt, token: <redacted>)';
}

/// Who is on the other end, for the call screen — the other person of a DM,
/// or the group itself. Resolved from the conversation; the call payload
/// carries ids only. Also one member of a group call's roster.
class CallPeer extends Equatable {
  const CallPeer({required this.name, required this.avatarSeed, this.avatarUrl, this.avatarCacheKey});

  /// Before the conversation has loaded: an incoming ring names only the
  /// caller's id, and the screen must not wait on a lookup to start ringing.
  const CallPeer.unknown() : name = 'Yello user', avatarSeed = 0, avatarUrl = null, avatarCacheKey = null;

  final String name;
  final int avatarSeed;
  final String? avatarUrl;
  final String? avatarCacheKey;

  String get firstName => name.split(' ').first;

  @override
  List<Object?> get props => [name, avatarSeed, avatarUrl, avatarCacheKey];
}
