import '../../domain/entities/call_entity.dart';
import '../../domain/repositories/call_repository.dart';
import '../models/call_model.dart';

/// Reads the `call.*` frames off `yello-chat`'s socket (`{event, data}`).
///
/// `call.started` is not here on purpose: it is the reply to the viewer's own
/// `call.start` and only reaches the socket that sent it, so
/// `CallRemoteDataSource.startCall` consumes it as a request's answer rather
/// than it travelling as an event. Anything that is not a call frame
/// decodes to null.
abstract final class CallFrameDecoder {
  static CallEvent? decode(Map<String, dynamic> frame, {String? viewerId}) {
    final data = frame['data'];
    if (data is! Map<String, dynamic>) return null;
    final call = data['call'];
    if (call is! Map<String, dynamic>) return null;
    return switch (frame['event']) {
      // Only ever sent to the people being rung — never the caller.
      'call.ringing' => CallRinging(CallMapper.fromJson(call, viewerId: viewerId, isOutgoing: false)),
      'call.accepted' => CallAccepted(CallMapper.fromJson(call, viewerId: viewerId)),
      'call.updated' => CallUpdated(CallMapper.fromJson(call, viewerId: viewerId)),
      'call.ended' => CallEnded(_withReason(CallMapper.fromJson(call, viewerId: viewerId), data['reason'])),
      _ => null,
    };
  }

  /// `data.reason` is documented to equal `call.endReason`; fall back to it
  /// should the nested copy ever be trimmed.
  static CallEntity _withReason(CallEntity call, Object? reason) {
    if (call.endReason != null) return call;
    final fromFrame = CallEndReason.fromWire(reason);
    if (fromFrame == null) return call;
    return call.copyWith(status: CallStatus.ended, endReason: fromFrame);
  }

  /// Whether [frame] settles a `call.accept` for [callId]: the first answer
  /// (`call.accepted`), the call having ended, or — joining a group call
  /// already under way — a `call.updated` that lists [viewerId] as JOINED.
  /// Other roster changes (someone else declining) do not count, so an
  /// error frame for the accept that arrives after one is still read. With
  /// no [viewerId] any `call.updated` counts.
  static bool settles(Map<String, dynamic> frame, String callId, {String? viewerId}) {
    final event = frame['event'];
    final call = _call(frame);
    if (call == null || call['id'] != callId) return false;
    if (event == 'call.accepted' || event == 'call.ended') return true;
    if (event != 'call.updated') return false;
    if (viewerId == null) return true;
    final participants = call['participants'];
    if (participants is! List) return false;
    return participants.any((p) => p is Map<String, dynamic> && p['userId'] == viewerId && p['state'] == 'JOINED');
  }

  /// Whether [frame] answers a `call.decline` or `call.end` for [callId]:
  /// `call.ended`, or — leaving a group call that goes on without you —
  /// `call.updated`.
  static bool ends(Map<String, dynamic> frame, String callId) {
    final event = frame['event'];
    return (event == 'call.ended' || event == 'call.updated') && _call(frame)?['id'] == callId;
  }

  static Map<String, dynamic>? _call(Map<String, dynamic> frame) {
    final data = frame['data'];
    if (data is! Map<String, dynamic>) return null;
    final call = data['call'];
    return call is Map<String, dynamic> ? call : null;
  }
}
