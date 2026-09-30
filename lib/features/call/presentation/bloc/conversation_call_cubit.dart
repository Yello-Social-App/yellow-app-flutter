import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/call_entity.dart';
import '../../domain/repositories/call_repository.dart';
import '../../domain/usecases/call_usecases.dart';

/// The live call in one conversation, or null — what a chat's "Join call"
/// bar shows. The state is the call itself.
///
/// Loaded once from `GET /ws/conversations/{id}/call` when the chat opens,
/// then kept current by the same `call.accepted`, `call.updated` and
/// `call.ended` frames `CallCubit` reads, and re-read after every reconnect
/// (a frame sent while the socket was down is not replayed). Per chat page
/// (a factory): it has no reason to outlive the screen that shows it.
class ConversationCallCubit extends Cubit<CallEntity?> {
  ConversationCallCubit({
    required this.conversationId,
    required GetConversationCallUseCase getConversationCall,
    required CallRepository repository,
  }) : _getConversationCall = getConversationCall,
       _repository = repository,
       super(null);

  final String conversationId;
  final GetConversationCallUseCase _getConversationCall;

  /// For [CallRepository.watchCalls] alone, as in `CallCubit`.
  final CallRepository _repository;
  StreamSubscription<CallEvent>? _sub;

  /// Bumped by every frame, so a lookup that was in flight when one landed
  /// does not overwrite the fresher news with its older answer.
  int _version = 0;

  void start() {
    _sub ??= _repository.watchCalls().listen(_onEvent);
  }

  Future<void> refresh() async {
    final version = ++_version;
    final result = await _getConversationCall(conversationId);
    if (isClosed || version != _version) return;
    // A failed lookup keeps whatever is showing; the next reconnect retries.
    result.fold((_) {}, (call) => emit(call != null && call.isLive ? call : null));
  }

  void _onEvent(CallEvent event) {
    if (isClosed) return;
    switch (event) {
      case CallLinkChanged(:final isLive):
        if (isLive) unawaited(refresh());
      case CallRinging(:final call) || CallAccepted(:final call) || CallUpdated(:final call):
        if (!_isHere(call)) return;
        _version++;
        emit(call.isLive ? call : null);
      case CallEnded(:final call):
        if (!_isHere(call)) return;
        _version++;
        emit(null);
    }
  }

  /// By conversation, or by the call already showing — the guide's frame
  /// samples abbreviate the call, and the id is the one field always there.
  bool _isHere(CallEntity call) => call.conversationId == conversationId || call.id == state?.id;

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
