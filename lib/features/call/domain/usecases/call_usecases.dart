import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/call_entity.dart';
import '../repositories/call_repository.dart';

class StartCallParams extends Equatable {
  const StartCallParams({required this.conversationId, required this.media});

  final String conversationId;
  final CallMedia media;

  @override
  List<Object?> get props => [conversationId, media];
}

/// `call.start`, in a DM or a group. In a group that already has a live call
/// this joins that call instead (`CALL_IN_PROGRESS`).
class StartCallUseCase implements UseCase<CallEntity, StartCallParams> {
  StartCallUseCase(this._repository);
  final CallRepository _repository;

  @override
  Future<Either<Failure, CallEntity>> call(StartCallParams params) =>
      _repository.startCall(conversationId: params.conversationId, media: params.media);
}

/// `call.accept` — answers a ring, or joins a group call under way. The
/// params are the call id.
class AcceptCallUseCase implements UseCase<Unit, String> {
  AcceptCallUseCase(this._repository);
  final CallRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String callId) => _repository.acceptCall(callId);
}

/// `call.decline` — the params are the call id.
class DeclineCallUseCase implements UseCase<Unit, String> {
  DeclineCallUseCase(this._repository);
  final CallRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String callId) => _repository.declineCall(callId);
}

/// `call.end` — leave. The params are the call id.
class EndCallUseCase implements UseCase<Unit, String> {
  EndCallUseCase(this._repository);
  final CallRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String callId) => _repository.endCall(callId);
}

/// `POST /ws/calls/{id}/token` — the params are the call id.
class GetCallTokenUseCase implements UseCase<CallTokenEntity, String> {
  GetCallTokenUseCase(this._repository);
  final CallRepository _repository;

  @override
  Future<Either<Failure, CallTokenEntity>> call(String callId) => _repository.getCallToken(callId);
}

/// `GET /ws/calls/active`.
class GetActiveCallUseCase implements UseCase<CallEntity?, NoParams> {
  GetActiveCallUseCase(this._repository);
  final CallRepository _repository;

  @override
  Future<Either<Failure, CallEntity?>> call(NoParams params) => _repository.getActiveCall();
}

/// `GET /ws/conversations/{id}/call` — the params are the conversation id.
class GetConversationCallUseCase implements UseCase<CallEntity?, String> {
  GetConversationCallUseCase(this._repository);
  final CallRepository _repository;

  @override
  Future<Either<Failure, CallEntity?>> call(String conversationId) => _repository.getConversationCall(conversationId);
}
