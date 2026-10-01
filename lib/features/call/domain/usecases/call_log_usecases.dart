import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/call_log_entry.dart';
import '../repositories/call_log_repository.dart';

/// Notes a finished call for its conversation's thread.
class RecordCallUseCase implements UseCase<Unit, CallLogEntry> {
  RecordCallUseCase(this._repository);
  final CallLogRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(CallLogEntry entry) => _repository.record(entry);
}

/// One conversation's finished calls, oldest first — the params are the
/// conversation id.
class GetCallLogUseCase implements UseCase<List<CallLogEntry>, String> {
  GetCallLogUseCase(this._repository);
  final CallLogRepository _repository;

  @override
  Future<Either<Failure, List<CallLogEntry>>> call(String conversationId) =>
      _repository.forConversation(conversationId);
}

/// Forgets every noted call — sign-out.
class ClearCallLogUseCase implements UseCase<Unit, NoParams> {
  ClearCallLogUseCase(this._repository);
  final CallLogRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(NoParams params) => _repository.clear();
}
