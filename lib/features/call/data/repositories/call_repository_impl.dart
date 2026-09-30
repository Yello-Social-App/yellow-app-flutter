import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../chat/data/datasources/chat_socket.dart';
import '../../../profile/domain/usecases/profile_usecases.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/repositories/call_repository.dart';
import '../datasources/call_frame_decoder.dart';
import '../datasources/call_remote_datasource.dart';

/// Calls over `yello-chat`: the same socket the chat screens use, and the
/// same `ApiClient` for the two HTTP routes.
///
/// Owns one thing the service does not hand over: **which side the viewer is
/// on**. A call names its initiator and a roster of user ids, never "you",
/// so the viewer's id is read from `GET /v1/users/me` — per subscription and
/// per lookup rather than memoised across them, since a memoised id would
/// outlive a sign-out. Within one [watchCalls] subscription the id it
/// resolved is reused by [startCall] and [acceptCall], so answering a ring
/// costs no extra round trip.
class CallRepositoryImpl implements CallRepository {
  CallRepositoryImpl(this._remote, this._socket, this._getMe, this._networkInfo);

  final CallRemoteDataSource _remote;
  final ChatSocket _socket;
  final GetMeUseCase _getMe;
  final NetworkInfo _networkInfo;

  /// The id [watchCalls] resolved for its subscription; null outside one.
  String? _watchingAs;

  Future<String?> _viewerId() async => (await _getMe(const NoParams())).fold((_) => null, (me) => me.id);

  Future<String?> _currentViewerId() async => _watchingAs ?? await _viewerId();

  Future<Either<Failure, T>> _run<T>(Future<T> Function() body) async {
    if (!await _networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await body());
    } on AppException catch (e) {
      return Left(ErrorHandler.toFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CallEntity>> startCall({required String conversationId, required CallMedia media}) =>
      _run(() async {
        final viewerId = await _currentViewerId();
        return _remote.startCall(conversationId: conversationId, media: media, viewerId: viewerId);
      });

  @override
  Future<Either<Failure, Unit>> acceptCall(String callId) => _run(() async {
    await _remote.acceptCall(callId, viewerId: await _currentViewerId());
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> declineCall(String callId) => _run(() async {
    await _remote.declineCall(callId);
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> endCall(String callId) => _run(() async {
    await _remote.endCall(callId);
    return unit;
  });

  @override
  Future<Either<Failure, CallTokenEntity>> getCallToken(String callId) => _run(() => _remote.getToken(callId));

  /// Without the viewer's id a live call cannot be placed on the right side
  /// of the screen — a ringing call would show its own caller "Incoming
  /// call" — so an unresolved id fails the lookup rather than guessing. The
  /// next reconnect asks again.
  @override
  Future<Either<Failure, CallEntity?>> getActiveCall() => _run(() async {
    final viewerId = await _viewerId();
    if (viewerId == null) throw const ServerException('Could not tell which side of the call you are on.');
    return _remote.getActiveCall(viewerId: viewerId);
  });

  @override
  Future<Either<Failure, CallEntity?>> getConversationCall(String conversationId) => _run(() async {
    final viewerId = await _currentViewerId();
    return _remote.getConversationCall(conversationId, viewerId: viewerId);
  });

  @override
  Stream<CallEvent> watchCalls() async* {
    final viewerId = await _viewerId();
    _watchingAs = viewerId;
    // The current state first, so a subscriber that arrives after the socket
    // came up (a chat screen was holding it) still runs its recovery.
    yield CallLinkChanged(_socket.isConnected);
    try {
      yield* _merge(
        _socket.frames.map((frame) => CallFrameDecoder.decode(frame, viewerId: viewerId)),
        _socket.connectionChanges.map(CallLinkChanged.new),
      );
    } finally {
      if (_watchingAs == viewerId) _watchingAs = null;
    }
  }

  /// Both sources are subscribed in the same `onListen`, frames first: that
  /// subscription is what opens the socket, so no `auth.ok` can slip past
  /// before the connection listener is attached.
  static Stream<CallEvent> _merge(Stream<CallEvent?> frames, Stream<CallEvent> link) {
    final controller = StreamController<CallEvent>();
    StreamSubscription<CallEvent?>? frameSub;
    StreamSubscription<CallEvent>? linkSub;
    controller
      ..onListen = () {
        frameSub = frames.listen((event) {
          if (event != null) controller.add(event);
        });
        linkSub = link.listen(controller.add);
      }
      ..onCancel = () async {
        await frameSub?.cancel();
        await linkSub?.cancel();
      };
    return controller.stream;
  }
}
