import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/call_log_entry.dart';
import '../../domain/repositories/call_log_repository.dart';
import '../../domain/usecases/call_log_usecases.dart';

/// One conversation's finished calls, oldest first — the call lines a chat
/// thread draws between its messages. The state is the list itself.
///
/// Read once from the on-device log when the chat opens, then kept current
/// by every call `CallCubit` notes while the screen is up. Per chat page (a
/// factory), like `ConversationCallCubit`.
class CallLogCubit extends Cubit<List<CallLogEntry>> {
  CallLogCubit({
    required this.conversationId,
    required GetCallLogUseCase getCallLog,
    required CallLogRepository repository,
  }) : _getCallLog = getCallLog,
       _repository = repository,
       super(const []);

  final String conversationId;
  final GetCallLogUseCase _getCallLog;

  /// For [CallLogRepository.watch] alone — a stream has no single result for
  /// a `UseCase` to carry. Same exception `CallCubit` makes for `watchCalls`.
  final CallLogRepository _repository;
  StreamSubscription<CallLogEntry>? _sub;

  Future<void> load() async {
    _sub ??= _repository.watch().listen(_onRecorded);
    final result = await _getCallLog(conversationId);
    if (isClosed) return;
    // An unreadable log shows no call lines; the thread itself is unaffected.
    // Merged rather than swapped in: a call noted while this read was in
    // flight is already in the state and may be newer than what was read.
    result.fold((_) {}, (entries) => emit(_merged(entries, state)));
  }

  void _onRecorded(CallLogEntry entry) {
    if (isClosed || entry.conversationId != conversationId) return;
    emit(_merged(state, [entry]));
  }

  /// [base] with [newer] laid over it by call id, oldest first.
  static List<CallLogEntry> _merged(List<CallLogEntry> base, List<CallLogEntry> newer) {
    final ids = {for (final entry in newer) entry.callId};
    return [...base.where((e) => !ids.contains(e.callId)), ...newer]..sort((a, b) => a.at.compareTo(b.at));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
