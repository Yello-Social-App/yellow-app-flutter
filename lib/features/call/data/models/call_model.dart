import '../../domain/entities/call_entity.dart';

/// `Call` on the wire ⇄ [CallEntity]. Bare JSON, no envelope — `yello-chat`.
abstract final class CallMapper {
  /// [isOutgoing] wins when the frame itself settles which side this is: a
  /// `call.started` reply only ever reaches the caller, and `call.ringing`
  /// only the people being rung. Everywhere else the initiator is compared
  /// with [viewerId]; an unknown viewer reads as the callee.
  ///
  /// The viewer's own roster entry is looked up by [viewerId] — or, for a
  /// `call.started` reply that arrives before the id is known, by the
  /// initiator, who is the viewer by definition.
  static CallEntity fromJson(Map<String, dynamic> json, {String? viewerId, bool? isOutgoing}) {
    final initiatorId = json['initiatorId'] as String? ?? '';
    final participants = _participants(json['participants']);
    final me = viewerId ?? (isOutgoing == true ? initiatorId : null);
    return CallEntity(
      id: json['id'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      kind: CallKind.fromWire(json['kind']),
      initiatorId: initiatorId,
      media: CallMedia.fromWire(json['media']),
      status: CallStatus.fromWire(json['status']),
      endReason: CallEndReason.fromWire(json['endReason']),
      createdAt: _date(json['createdAt']) ?? DateTime.now(),
      answeredAt: _date(json['answeredAt']),
      endedAt: _date(json['endedAt']),
      participants: participants,
      viewerState: me == null ? null : _stateOf(participants, me),
      isOutgoing: isOutgoing ?? (viewerId != null && initiatorId == viewerId),
    );
  }

  static List<CallParticipant> _participants(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map<String, dynamic> && entry['userId'] is String)
          CallParticipant(
            userId: entry['userId'] as String,
            state: CallParticipantState.fromWire(entry['state']),
            joinedAt: _date(entry['joinedAt']),
          ),
    ];
  }

  static CallParticipantState? _stateOf(List<CallParticipant> participants, String userId) {
    for (final p in participants) {
      if (p.userId == userId) return p.state;
    }
    return null;
  }

  static DateTime? _date(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;
}

/// `CallToken` ⇄ [CallTokenEntity].
abstract final class CallTokenMapper {
  static CallTokenEntity fromJson(Map<String, dynamic> json) => CallTokenEntity(
    serverUrl: json['serverUrl'] as String? ?? '',
    roomName: json['roomName'] as String? ?? '',
    token: json['token'] as String? ?? '',
    // Missing means "use it now": the ten-minute window is only a bound on
    // how late a connect may happen, never a reason to delay one.
    expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ?? DateTime.now(),
  );
}
