import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/feedback_entity.dart';
import '../entities/post_report_entity.dart';
import '../repositories/safety_repository.dart';

/// The API's own limit on a feedback note. Enforced here as well as on the
/// composer's `maxLength` so a paste past the limit is refused with a
/// sentence the user can act on, rather than as a
/// `400 VALIDATION_FAILED` from the server.
const int kFeedbackNoteMaxLength = 500;

/// The API's own limit on a report's free-text `details`.
const int kReportDetailsMaxLength = 300;

class SafetyPageParams extends Equatable {
  const SafetyPageParams({this.page = 0});
  final int page;

  @override
  List<Object?> get props => [page];
}

class SubmitFeedbackParams extends Equatable {
  const SubmitFeedbackParams({required this.feature, required this.rating, this.note});

  final FeedbackFeature feature;

  /// 1-5.
  final int rating;

  final String? note;

  @override
  List<Object?> get props => [feature, rating, note];
}

class SubmitFeedbackUseCase implements UseCase<FeedbackEntity, SubmitFeedbackParams> {
  SubmitFeedbackUseCase(this._repository);
  final SafetyRepository _repository;

  @override
  Future<Either<Failure, FeedbackEntity>> call(SubmitFeedbackParams params) {
    if (params.rating < 1 || params.rating > 5) {
      return Future.value(const Left(ValidationFailure('Pick a rating from 1 to 5.')));
    }
    final note = params.note?.trim();
    if (note != null && note.length > kFeedbackNoteMaxLength) {
      return Future.value(
        const Left(ValidationFailure('Keep your note under $kFeedbackNoteMaxLength characters.')),
      );
    }
    return _repository.submitFeedback(feature: params.feature, rating: params.rating, note: note);
  }
}

class GetMyFeedbackUseCase implements UseCase<FeedbackPage, SafetyPageParams> {
  GetMyFeedbackUseCase(this._repository);
  final SafetyRepository _repository;

  @override
  Future<Either<Failure, FeedbackPage>> call(SafetyPageParams params) =>
      _repository.getMyFeedback(page: params.page);
}

class ReportPostParams extends Equatable {
  const ReportPostParams({required this.postId, required this.reason, this.details});

  final String postId;
  final ReportReason reason;

  /// Optional free text. Untrusted user input on the moderator's side too —
  /// it is shown in the moderation queue, which is why the API caps it.
  final String? details;

  @override
  List<Object?> get props => [postId, reason, details];
}

class ReportPostUseCase implements UseCase<PostReportEntity, ReportPostParams> {
  ReportPostUseCase(this._repository);
  final SafetyRepository _repository;

  @override
  Future<Either<Failure, PostReportEntity>> call(ReportPostParams params) {
    final details = params.details?.trim();
    if (details != null && details.length > kReportDetailsMaxLength) {
      return Future.value(
        const Left(ValidationFailure('Keep the extra detail under $kReportDetailsMaxLength characters.')),
      );
    }
    return _repository.reportPost(postId: params.postId, reason: params.reason, details: details);
  }
}

class GetMyReportsUseCase implements UseCase<ReportsPage, SafetyPageParams> {
  GetMyReportsUseCase(this._repository);
  final SafetyRepository _repository;

  @override
  Future<Either<Failure, ReportsPage>> call(SafetyPageParams params) => _repository.getMyReports(page: params.page);
}

/// Shared by [MuteUserUseCase] and [UnmuteUserUseCase]. Deliberately not
/// the friends feature's own `UserIdParams`: nothing about muting belongs
/// to that feature, and importing across the two would tie them together
/// for one field.
class MuteParams extends Equatable {
  const MuteParams(this.userId);
  final String userId;

  @override
  List<Object?> get props => [userId];
}

class MuteUserUseCase implements UseCase<void, MuteParams> {
  MuteUserUseCase(this._repository);
  final SafetyRepository _repository;

  @override
  Future<Either<Failure, void>> call(MuteParams params) => _repository.muteUser(params.userId);
}

class UnmuteUserUseCase implements UseCase<void, MuteParams> {
  UnmuteUserUseCase(this._repository);
  final SafetyRepository _repository;

  @override
  Future<Either<Failure, void>> call(MuteParams params) => _repository.unmuteUser(params.userId);
}

class GetMutedUsersUseCase implements UseCase<MutedUsersPage, SafetyPageParams> {
  GetMutedUsersUseCase(this._repository);
  final SafetyRepository _repository;

  @override
  Future<Either<Failure, MutedUsersPage>> call(SafetyPageParams params) =>
      _repository.getMutedUsers(page: params.page);
}

/// Shared by [HidePostUseCase] and [UnhidePostUseCase]. Same reasoning as
/// [MuteParams] for not reusing the feed feature's `PostIdParams`.
class HidePostParams extends Equatable {
  const HidePostParams(this.postId);
  final String postId;

  @override
  List<Object?> get props => [postId];
}

class HidePostUseCase implements UseCase<void, HidePostParams> {
  HidePostUseCase(this._repository);
  final SafetyRepository _repository;

  @override
  Future<Either<Failure, void>> call(HidePostParams params) => _repository.hidePost(params.postId);
}

class UnhidePostUseCase implements UseCase<void, HidePostParams> {
  UnhidePostUseCase(this._repository);
  final SafetyRepository _repository;

  @override
  Future<Either<Failure, void>> call(HidePostParams params) => _repository.unhidePost(params.postId);
}
