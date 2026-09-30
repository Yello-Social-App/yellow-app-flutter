import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/call_entity.dart';

/// Audio and video calls on `yello-chat` — 1:1 in a DM, up to 16 people in
/// a group.
///
/// The service rings, records and authorises calls; the audio and video go
/// through LiveKit (`CallRoom`), never through it. Starting, answering,
/// declining and hanging up are **socket frames** — there is no HTTP route for
/// them — while the join token and the active-call lookup are HTTP.
abstract interface class CallRepository {
  /// `call.start`. Resolves with the server's `call.started` reply: a
  /// `RINGING` call, or one already `ENDED` with [CallEndReason.busy] when
  /// nobody could be rung.
  ///
  /// A group that already has a live call answers `CALL_IN_PROGRESS`; the
  /// service's rule is to join that one instead, so this sends `call.accept`
  /// for it and resolves with the call the viewer is now JOINED in.
  Future<Either<Failure, CallEntity>> startCall({required String conversationId, required CallMedia media});

  /// `call.accept`: answers a ringing call, or joins a group call already
  /// under way (after declining, missing it, leaving, or being added to the
  /// group later). Resolves once the server has settled it — `call.accepted`,
  /// a `call.updated` listing the viewer JOINED, or `call.ended`. The outcome
  /// itself arrives on [watchCalls] like any other change.
  Future<Either<Failure, Unit>> acceptCall(String callId);

  /// `call.decline` — only while the viewer is being rung.
  Future<Either<Failure, Unit>> declineCall(String callId);

  /// `call.end` — **leave**. The call ends for everyone only once fewer than
  /// two are left in it. Leaving a call that already ended is a server-side
  /// no-op, so this does not insist on a reply.
  Future<Either<Failure, Unit>> endCall(String callId);

  /// `POST /ws/calls/{id}/token` — only for someone JOINED: the caller from
  /// the start, everyone else after `call.accept`. Asking again returns a
  /// fresh token.
  Future<Either<Failure, CallTokenEntity>> getCallToken(String callId);

  /// `GET /ws/calls/active` — the call the viewer is in, else one ringing
  /// them, else null. What a client re-reads after every (re)connect, since
  /// a frame sent while it was offline is not replayed.
  Future<Either<Failure, CallEntity?>> getActiveCall();

  /// `GET /ws/conversations/{id}/call` — the conversation's live call, or
  /// null. What a chat reads when it opens, to offer "Join call".
  Future<Either<Failure, CallEntity?>> getConversationCall(String conversationId);

  /// Every call change the server announces to the viewer, plus the socket
  /// coming up or going down.
  ///
  /// Subscribing holds `yello-chat`'s socket open — a ring can only reach a
  /// device with a live connection — and the last subscriber leaving lets it
  /// close. See [CallEvent].
  Stream<CallEvent> watchCalls();
}

/// One server → client call frame, decoded — or the transport's own news.
sealed class CallEvent {
  const CallEvent();
}

/// The socket authenticated ([isLive]) or dropped. After it comes back, the
/// client re-reads [CallRepository.getActiveCall]: whatever happened while it
/// was away was not queued for it.
class CallLinkChanged extends CallEvent {
  const CallLinkChanged(this.isLive);
  final bool isLive;
}

/// `call.ringing` — someone is calling the viewer. Sent only to the people
/// being rung (INVITED), on every device.
class CallRinging extends CallEvent {
  const CallRinging(this.call);
  final CallEntity call;
}

/// `call.accepted` — the first answer, on this device or another. Sent to
/// every member; in a group the others keep ringing while their own state is
/// still INVITED.
class CallAccepted extends CallEvent {
  const CallAccepted(this.call);
  final CallEntity call;
}

/// `call.updated` — the roster changed but the status did not: someone
/// joined, left, declined or stopped ringing. Sent to every member, and to
/// anyone just removed from the group. The viewer's own entry says what to
/// do: INVITED keeps ringing, JOINED stays, anything else closes the call UI.
class CallUpdated extends CallEvent {
  const CallUpdated(this.call);
  final CallEntity call;
}

/// `call.ended` — final. `call.endReason` says why.
class CallEnded extends CallEvent {
  const CallEnded(this.call);
  final CallEntity call;
}
