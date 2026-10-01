import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/call_log_entry.dart';
import '../../domain/repositories/call_log_repository.dart';
import '../datasources/call_log_local_datasource.dart';

/// The on-device call log. Nothing here can fail for a network reason; a
/// storage error comes back as a [CacheFailure] and costs one line in a
/// thread, never the call.
class CallLogRepositoryImpl implements CallLogRepository {
  CallLogRepositoryImpl(this._local);

  final CallLogLocalDataSource _local;
  final StreamController<CallLogEntry> _recorded = StreamController<CallLogEntry>.broadcast();

  /// The log is one stored value, so it stays small: the newest calls across
  /// every conversation.
  static const int maxEntries = 200;

  /// Writes run one after another. Each is read-modify-write of the whole
  /// log, and a hang-up's own note can be followed at once by the server's
  /// `call.ended` — two at a time would let the second overwrite the first.
  Future<void> _lastWrite = Future<void>.value();

  Future<Either<Failure, T>> _run<T>(Future<T> Function() body) async {
    try {
      return Right(await body());
    } catch (_) {
      return const Left(CacheFailure());
    }
  }

  Future<Either<Failure, Unit>> _write(Future<void> Function() body) {
    final result = _lastWrite.then(
      (_) => _run(() async {
        await body();
        return unit;
      }),
    );
    _lastWrite = result;
    return result;
  }

  @override
  Future<Either<Failure, Unit>> record(CallLogEntry entry) async {
    final result = await _write(() async {
      final entries = [...(await _local.read()).where((e) => e.callId != entry.callId), entry]
        ..sort((a, b) => a.at.compareTo(b.at));
      await _local.write(entries.length > maxEntries ? entries.sublist(entries.length - maxEntries) : entries);
    });
    if (result.isRight()) _recorded.add(entry);
    return result;
  }

  @override
  Future<Either<Failure, List<CallLogEntry>>> forConversation(String conversationId) => _run(
    () async =>
        (await _local.read()).where((e) => e.conversationId == conversationId).toList()
          ..sort((a, b) => a.at.compareTo(b.at)),
  );

  @override
  Future<Either<Failure, Unit>> clear() => _write(_local.clear);

  @override
  Stream<CallLogEntry> watch() => _recorded.stream;
}
