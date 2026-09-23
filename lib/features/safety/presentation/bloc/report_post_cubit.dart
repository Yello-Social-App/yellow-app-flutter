import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/post_report_entity.dart';
import '../../domain/usecases/safety_usecases.dart';

/// How a submission ended. [alreadyReported] is a success as far as the
/// user is concerned — the report they wanted already exists — so the sheet
/// closes on it the same way it does on [sent], just with different copy.
enum ReportOutcome { none, sent, alreadyReported, failed }

class ReportPostState extends Equatable {
  const ReportPostState({this.reason, this.submitting = false, this.outcome = ReportOutcome.none, this.errorMessage});

  /// Null until the user picks one; the submit button stays disabled.
  final ReportReason? reason;

  final bool submitting;
  final ReportOutcome outcome;
  final String? errorMessage;

  bool get canSubmit => reason != null && !submitting;

  ReportPostState copyWith({
    ReportReason? reason,
    bool? submitting,
    ReportOutcome? outcome,
    String? errorMessage,
  }) {
    return ReportPostState(
      reason: reason ?? this.reason,
      submitting: submitting ?? this.submitting,
      outcome: outcome ?? this.outcome,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [reason, submitting, outcome, errorMessage];
}

/// Backs the "Report post" sheet — one per open, because a half-filled
/// report has no business surviving the sheet being dismissed.
class ReportPostCubit extends Cubit<ReportPostState> {
  ReportPostCubit({required this.postId, required ReportPostUseCase reportPost})
    : _reportPost = reportPost,
      super(const ReportPostState());

  final String postId;
  final ReportPostUseCase _reportPost;

  void selectReason(ReportReason reason) => emit(state.copyWith(reason: reason, errorMessage: null));

  /// Submits, and answers what the sheet should say. The in-flight flag is
  /// the guard the "every mutating action needs one" rule asks for: without
  /// it a double-tap on Submit fires two reports, and the second comes back
  /// `409 REPORT_ALREADY_EXISTS` against the first — an error message for
  /// something that actually worked.
  Future<ReportOutcome> submit({String? details}) async {
    final reason = state.reason;
    if (reason == null || state.submitting) return ReportOutcome.none;
    emit(state.copyWith(submitting: true, errorMessage: null));

    final result = await _reportPost(ReportPostParams(postId: postId, reason: reason, details: details));
    if (isClosed) return ReportOutcome.none;

    return result.fold(
      (failure) {
        // `REPORT_ALREADY_EXISTS` is the one rejection that is not a
        // failure: an open report on this post already exists, which is
        // exactly what the user was asking for. Branching on the code, not
        // the message — the message is copy the server may reword.
        if (failure is ValidationFailure && failure.code == ApiErrorCodes.reportAlreadyExists) {
          emit(state.copyWith(submitting: false, outcome: ReportOutcome.alreadyReported));
          return ReportOutcome.alreadyReported;
        }
        emit(state.copyWith(submitting: false, outcome: ReportOutcome.failed, errorMessage: failure.message));
        return ReportOutcome.failed;
      },
      (_) {
        emit(state.copyWith(submitting: false, outcome: ReportOutcome.sent));
        return ReportOutcome.sent;
      },
    );
  }
}
