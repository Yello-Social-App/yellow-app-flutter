import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/call_log_entry.dart';

/// The finished calls this device has seen, for the chat thread's call lines.
///
/// On-device only — `yello-chat` has no call history to read
/// (`docs/BACKEND.md`), so nothing here reaches the network.
abstract interface class CallLogRepository {
  /// Notes a finished call. A second note for the same call replaces the
  /// first, so the device's own guess (it hung up) can be followed by the
  /// server's `call.ended` without doubling the line.
  Future<Either<Failure, Unit>> record(CallLogEntry entry);

  /// One conversation's calls, oldest first.
  Future<Either<Failure, List<CallLogEntry>>> forConversation(String conversationId);

  /// Sign-out: the log belongs to the account that made it.
  Future<Either<Failure, Unit>> clear();

  /// Every entry as it is [record]ed, so an open chat draws the line at once.
  Stream<CallLogEntry> watch();
}
