import 'dart:async' hide TimeoutException;

import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../chat/data/datasources/chat_remote_datasource.dart';
import '../../../chat/data/datasources/chat_socket.dart';
import '../../domain/entities/call_entity.dart';
import '../models/call_model.dart';
import 'call_frame_decoder.dart';

/// `yello-chat`'s call surface: four socket frames and three HTTP routes.
///
/// The frames are requests without a request id of their own, so each one
/// carries a `ref` the server echoes on its reply and on any `error` frame it
/// causes — which is how an error is matched to the frame that caused it.
abstract interface class CallRemoteDataSource {
  /// With [viewerId] the reply's roster is read from the viewer's side. A
  /// group's `CALL_IN_PROGRESS` is turned into joining that call instead.
  Future<CallEntity> startCall({required String conversationId, required CallMedia media, String? viewerId});
  Future<void> acceptCall(String callId, {String? viewerId});
  Future<void> declineCall(String callId);
  Future<void> endCall(String callId);
  Future<CallTokenEntity> getToken(String callId);
  Future<CallEntity?> getActiveCall({String? viewerId});
  Future<CallEntity?> getConversationCall(String conversationId, {String? viewerId});
}

/// Details the server attaches to a `CONFLICT`, by name, so the copy below
/// can switch on them — never on `message`, which is for logs.
abstract final class CallErrorReasons {
  /// `call.start` in a group that already has a live call; `details.callId`
  /// names it.
  static const String callInProgress = 'CALL_IN_PROGRESS';

  /// `call.accept` on a call already holding its maximum (16 by default).
  static const String callFull = 'CALL_FULL';

  /// `call.accept` while JOINED in another call.
  static const String alreadyInCall = 'ALREADY_IN_CALL';
}

/// `call.start` found the group's call already running. Never shown:
/// [CallRemoteDataSourceImpl.startCall] catches it and joins [callId].
class CallInProgressException extends ServerException {
  const CallInProgressException(this.callId) : super('A call is already going on here.', code: ChatErrorCodes.conflict);
  final String callId;
}

class CallRemoteDataSourceImpl implements CallRemoteDataSource {
  CallRemoteDataSourceImpl(this._apiClient, this._socket);

  final ApiClient _apiClient;
  final ChatSocket _socket;
  Dio get _dio => _apiClient.dio;

  /// How long `call.start` / `call.accept` may take to be answered.
  static const Duration _replyTimeout = Duration(seconds: 10);

  /// `call.decline` / `call.end` are answered by `call.ended` — unless the
  /// call had already ended, in which case the server answers nothing at all.
  /// Silence for this long therefore means "already over", not a failure.
  static const Duration _endTimeout = Duration(seconds: 5);

  int _sequence = 0;

  @override
  Future<CallEntity> startCall({required String conversationId, required CallMedia media, String? viewerId}) async {
    final Map<String, dynamic> reply;
    try {
      reply = await _request('call.start', {
        'conversationId': conversationId,
        'media': media.wire,
      }, isReply: (frame, ref) => frame['event'] == 'call.started' && _data(frame)['ref'] == ref);
    } on CallInProgressException catch (e) {
      // The guide's answer to CALL_IN_PROGRESS: join that call instead.
      await acceptCall(e.callId, viewerId: viewerId);
      final live = await getConversationCall(conversationId, viewerId: viewerId);
      if (live == null || live.id != e.callId) throw const ServerException('That call has already ended.');
      return live;
    }
    final call = _data(reply)['call'];
    if (call is! Map<String, dynamic>) throw const ServerException('The call service sent an unreadable reply.');
    return CallMapper.fromJson(call, viewerId: viewerId, isOutgoing: true);
  }

  @override
  Future<void> acceptCall(String callId, {String? viewerId}) => _request('call.accept', {
    'callId': callId,
  }, isReply: (frame, _) => CallFrameDecoder.settles(frame, callId, viewerId: viewerId));

  @override
  Future<void> declineCall(String callId) => _end('call.decline', callId);

  @override
  Future<void> endCall(String callId) => _end('call.end', callId);

  /// A `CONFLICT` on `call.end` means the call changed state under the frame
  /// (it was answered as it was cancelled); the guide's answer is to send it
  /// again, once.
  Future<void> _end(String event, String callId) async {
    for (var attempt = 0; ; attempt++) {
      try {
        await _request(
          event,
          {'callId': callId},
          isReply: (frame, _) => CallFrameDecoder.ends(frame, callId),
          timeout: _endTimeout,
        );
        return;
      } on TimeoutException {
        return;
      } on ServerException catch (e) {
        if (event == 'call.end' && e.code == ChatErrorCodes.conflict && attempt == 0) continue;
        rethrow;
      }
    }
  }

  @override
  Future<CallTokenEntity> getToken(String callId) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(ChatRoutes.callToken(callId));
    return CallTokenMapper.fromJson(res.data ?? const <String, dynamic>{});
  });

  @override
  Future<CallEntity?> getActiveCall({String? viewerId}) => _readCall(ChatRoutes.activeCall, viewerId);

  @override
  Future<CallEntity?> getConversationCall(String conversationId, {String? viewerId}) =>
      _readCall(ChatRoutes.conversationCall(conversationId), viewerId);

  /// Both lookups answer `{call}` or `{call: null}`.
  Future<CallEntity?> _readCall(String path, String? viewerId) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(path);
    final call = res.data?['call'];
    return call is Map<String, dynamic> ? CallMapper.fromJson(call, viewerId: viewerId) : null;
  });

  /// Sends [event] with a fresh `ref` and waits for the first frame that
  /// [isReply] accepts, or for an `error` frame carrying that `ref`.
  Future<Map<String, dynamic>> _request(
    String event,
    Map<String, dynamic> data, {
    required bool Function(Map<String, dynamic> frame, String ref) isReply,
    Duration timeout = _replyTimeout,
  }) async {
    // `send` drops a frame silently while the socket is down; a call action
    // must not look like it went through when it did not.
    if (!_socket.isConnected) {
      throw const NetworkException('Calls need a live connection — try again in a moment.');
    }
    final ref = _nextRef(event);
    final reply = Completer<Map<String, dynamic>>();
    final sub = _socket.frames.listen((frame) {
      if (reply.isCompleted) return;
      final payload = _data(frame);
      if (frame['event'] == 'error' && _refOf(payload) == ref) {
        reply.completeError(_errorFrom(payload));
      } else if (isReply(frame, ref)) {
        reply.complete(frame);
      }
    });
    try {
      _socket.send(event, {...data, 'ref': ref});
      return await reply.future.timeout(
        timeout,
        onTimeout: () => throw const TimeoutException('The call service did not answer — try again.'),
      );
    } finally {
      await sub.cancel();
    }
  }

  /// Unique per process and short of the 64-character cap.
  String _nextRef(String event) =>
      '${event.substring(event.indexOf('.') + 1)}-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-${_sequence++}';

  static Map<String, dynamic> _data(Map<String, dynamic> frame) {
    final data = frame['data'];
    return data is Map<String, dynamic> ? data : const <String, dynamic>{};
  }

  /// The guide says an error frame "carries your ref" without placing it;
  /// read it beside `code` first and under `details` second.
  static Object? _refOf(Map<String, dynamic> error) {
    final details = error['details'];
    return error['ref'] ?? (details is Map<String, dynamic> ? details['ref'] : null);
  }

  /// An `error` frame as an [AppException], worded for the person holding
  /// the phone. The server's `message` is logged, not shown: the guide says
  /// it may change, and it is written for developers.
  static AppException _errorFrom(Map<String, dynamic> error) {
    final code = error['code'] as String?;
    final details = error['details'];
    final reason = details is Map<String, dynamic> ? details['reason'] : null;
    if (code == ChatErrorCodes.conflict && reason == CallErrorReasons.callInProgress) {
      final callId = details is Map<String, dynamic> ? details['callId'] : null;
      if (callId is String && callId.isNotEmpty) return CallInProgressException(callId);
    }
    final maxParticipants = details is Map<String, dynamic> ? details['maxParticipants'] : null;
    final message = switch (code) {
      ChatErrorCodes.validationError => 'That call could not be placed.',
      ChatErrorCodes.forbidden => 'You can’t join this call.',
      ChatErrorCodes.notFound => 'That call is no longer available.',
      ChatErrorCodes.conflict when reason == CallErrorReasons.callFull =>
        maxParticipants is int ? 'This call is full — $maxParticipants people at most.' : 'This call is full.',
      ChatErrorCodes.conflict when reason == CallErrorReasons.alreadyInCall =>
        'You’re already in another call — leave it first.',
      ChatErrorCodes.conflict when reason == CallErrorReasons.callInProgress =>
        'A call is already going on here — join it instead.',
      ChatErrorCodes.conflict => 'That call has already ended.',
      ChatErrorCodes.rateLimited => 'Too many calls at once — wait a few seconds and try again.',
      ChatErrorCodes.unavailable => 'Calls aren’t available right now.',
      ChatErrorCodes.unauthorized => 'Please sign in again.',
      _ => 'Something went wrong with the call.',
    };
    return ServerException(message, code: code);
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : ErrorHandler.fromDioException(e);
    }
  }
}
