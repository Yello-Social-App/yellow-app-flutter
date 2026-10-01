import 'package:equatable/equatable.dart';

import 'call_entity.dart';

/// One finished call, as the chat thread shows it — "Voice call declined",
/// "Missed video call", "Voice call · 1:05".
///
/// `yello-chat` records every call but writes no line into the conversation:
/// a `Message` has no call field and no route lists past calls
/// (`docs/BACKEND.md`). So this is **kept on the device**, noted as each call
/// ends — the same trade-off as saved posts. It is not synced, does not
/// survive a reinstall, and a call that ended while the app had no socket
/// (missed with the app closed) leaves no line.
class CallLogEntry extends Equatable {
  const CallLogEntry({
    required this.callId,
    required this.conversationId,
    required this.media,
    required this.isGroup,
    required this.isOutgoing,
    required this.endReason,
    required this.at,
    this.talkTime,
  });

  /// [endReason] and [talkTime] override the call's own for a call this
  /// device ended itself, before the server's `call.ended` has said so.
  factory CallLogEntry.fromCall(CallEntity call, {CallEndReason? endReason, Duration? talkTime}) => CallLogEntry(
    callId: call.id,
    conversationId: call.conversationId,
    media: call.media,
    isGroup: call.isGroup,
    isOutgoing: call.isOutgoing,
    endReason: endReason ?? call.endReason ?? CallEndReason.hangup,
    at: call.createdAt,
    talkTime: talkTime ?? call.talkTime,
  );

  /// One entry per call: noting the same call again replaces the entry.
  final String callId;
  final String conversationId;
  final CallMedia media;
  final bool isGroup;

  /// Whether the viewer placed it.
  final bool isOutgoing;
  final CallEndReason endReason;

  /// When the call started — where its line sits among the messages.
  final DateTime at;

  /// How long it was answered for; null for a call that never connected.
  final Duration? talkTime;

  bool get isVideo => media == CallMedia.video;

  /// It rang and nobody talked: declined, missed, cancelled, busy or failed.
  bool get wasUnanswered => endReason != CallEndReason.hangup;

  @override
  List<Object?> get props => [callId, conversationId, media, isGroup, isOutgoing, endReason, at, talkTime];
}
