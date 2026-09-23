import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/feedback_entity.dart';
import '../entities/muted_user_entity.dart';
import '../entities/post_report_entity.dart';

class FeedbackPage {
  const FeedbackPage({required this.items, required this.hasMore});
  final List<FeedbackEntity> items;
  final bool hasMore;
}

class ReportsPage {
  const ReportsPage({required this.items, required this.hasMore});
  final List<PostReportEntity> items;
  final bool hasMore;
}

class MutedUsersPage {
  const MutedUsersPage({required this.items, required this.hasMore});
  final List<MutedUserEntity> items;
  final bool hasMore;
}

/// Domain-facing contract for feedback, post reports, muting and hiding —
/// `yello-api`'s `/feedback`, `/reports`, `/users/{id}/mute` and
/// `/posts/{id}/hide` resources.
///
/// The moderator side of reports (`GET`/`PATCH /v1/admin/reports`) is
/// deliberately not here: it answers `403 ACCESS_DENIED` for every account
/// this app signs in. See `docs/BACKEND.md`.
abstract interface class SafetyRepository {
  /// Rates one feature 1-5 with an optional note. Capped at 10 per hour per
  /// user — over that is a `RATE_LIMIT_EXCEEDED` [ValidationFailure].
  Future<Either<Failure, FeedbackEntity>> submitFeedback({
    required FeedbackFeature feature,
    required int rating,
    String? note,
  });

  /// Your own feedback, newest first.
  Future<Either<Failure, FeedbackPage>> getMyFeedback({int page = 0});

  /// Reports a post you did not write. A second report while your first is
  /// still `UNDER_REVIEW` fails with `REPORT_ALREADY_EXISTS`, which callers
  /// read off [ValidationFailure.code] and treat as "already reported"
  /// rather than as an error.
  Future<Either<Failure, PostReportEntity>> reportPost({
    required String postId,
    required ReportReason reason,
    String? details,
  });

  /// Your reports and their outcomes, newest first.
  Future<Either<Failure, ReportsPage>> getMyReports({int page = 0});

  /// Takes someone's posts out of your feed. Idempotent, and never visible
  /// to them.
  Future<Either<Failure, void>> muteUser(String userId);

  /// Idempotent — unmuting someone who was not muted still succeeds.
  Future<Either<Failure, void>> unmuteUser(String userId);

  Future<Either<Failure, MutedUsersPage>> getMutedUsers({int page = 0});

  /// Hides one post from your own feed, on this account, across devices.
  /// Idempotent, and not a report: nothing is sent to a moderator and the
  /// author is never told.
  Future<Either<Failure, void>> hidePost(String postId);

  /// Idempotent — unhiding a post that was not hidden still succeeds.
  Future<Either<Failure, void>> unhidePost(String postId);
}
