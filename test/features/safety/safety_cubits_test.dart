import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/error/error_handler.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/features/safety/domain/entities/muted_user_entity.dart';
import 'package:yello_social_app/features/safety/domain/entities/post_report_entity.dart';
import 'package:yello_social_app/features/safety/domain/repositories/safety_repository.dart';
import 'package:yello_social_app/features/safety/domain/usecases/safety_usecases.dart';
import 'package:yello_social_app/features/safety/presentation/bloc/privacy_safety_cubit.dart';
import 'package:yello_social_app/features/safety/presentation/bloc/report_post_cubit.dart';

class _MockReportPost extends Mock implements ReportPostUseCase {}

class _MockGetMyReports extends Mock implements GetMyReportsUseCase {}

class _MockGetMutedUsers extends Mock implements GetMutedUsersUseCase {}

class _MockUnmuteUser extends Mock implements UnmuteUserUseCase {}

PostReportEntity _report({String id = 'r1', ReportStatus status = ReportStatus.underReview}) => PostReportEntity(
  id: id,
  postId: 'p1',
  reason: ReportReason.spam,
  status: status,
  createdAt: DateTime(2026, 9, 22),
);

MutedUserEntity _muted({String userId = 'u2'}) =>
    MutedUserEntity(userId: userId, username: 'rithy', since: DateTime(2026, 9, 10));

void main() {
  setUpAll(() {
    registerFallbackValue(const ReportPostParams(postId: 'p1', reason: ReportReason.spam));
    registerFallbackValue(const SafetyPageParams());
    registerFallbackValue(const MuteParams('u2'));
  });

  group('ReportPostCubit', () {
    late _MockReportPost reportPost;

    setUp(() => reportPost = _MockReportPost());

    ReportPostCubit build() => ReportPostCubit(postId: 'p1', reportPost: reportPost);

    test('does nothing until a reason is picked', () async {
      final cubit = build();
      expect(cubit.state.canSubmit, isFalse);
      expect(await cubit.submit(), ReportOutcome.none);
      verifyNever(() => reportPost(any()));
    });

    test('a filed report reports success', () async {
      when(() => reportPost(any())).thenAnswer((_) async => Right(_report()));
      final cubit = build()..selectReason(ReportReason.harassment);
      expect(await cubit.submit(details: 'again today'), ReportOutcome.sent);
      expect(cubit.state.errorMessage, isNull);
    });

    test('REPORT_ALREADY_EXISTS is treated as "already reported", not as an error', () async {
      // The 409 the backend answers when an UNDER_REVIEW report from this
      // viewer already exists. The user asked for a report on this post and
      // there is one — telling them it failed would be a lie.
      when(() => reportPost(any())).thenAnswer(
        (_) async => const Left(
          ValidationFailure('You already have an open report on this post.', code: ApiErrorCodes.reportAlreadyExists),
        ),
      );
      final cubit = build()..selectReason(ReportReason.spam);
      expect(await cubit.submit(), ReportOutcome.alreadyReported);
      expect(cubit.state.outcome, ReportOutcome.alreadyReported);
      // Nothing to show in red — the sheet closes with a confirmation.
      expect(cubit.state.errorMessage, isNull);
    });

    test('any other rejection keeps the sheet open with the server message', () async {
      when(() => reportPost(any())).thenAnswer(
        (_) async => const Left(ValidationFailure('Slow down a moment.', code: ApiErrorCodes.rateLimitExceeded)),
      );
      final cubit = build()..selectReason(ReportReason.spam);
      expect(await cubit.submit(), ReportOutcome.failed);
      expect(cubit.state.errorMessage, 'Slow down a moment.');
    });

    test('a second tap while the first is in flight is dropped', () async {
      // Without the guard the second report comes back 409 against the
      // first — an error message for something that actually worked.
      final gate = Completer<Either<Failure, PostReportEntity>>();
      when(() => reportPost(any())).thenAnswer((_) => gate.future);
      final cubit = build()..selectReason(ReportReason.spam);

      final first = cubit.submit();
      expect(await cubit.submit(), ReportOutcome.none);
      gate.complete(Right(_report()));
      expect(await first, ReportOutcome.sent);
      verify(() => reportPost(any())).called(1);
    });
  });

  group('PrivacySafetyCubit', () {
    late _MockGetMyReports getMyReports;
    late _MockGetMutedUsers getMutedUsers;
    late _MockUnmuteUser unmuteUser;

    setUp(() {
      getMyReports = _MockGetMyReports();
      getMutedUsers = _MockGetMutedUsers();
      unmuteUser = _MockUnmuteUser();
    });

    PrivacySafetyCubit build() =>
        PrivacySafetyCubit(getMyReports: getMyReports, getMutedUsers: getMutedUsers, unmuteUser: unmuteUser);

    test('one failing list does not blank the other', () async {
      when(() => getMyReports(any())).thenAnswer((_) async => const Left(ServerFailure()));
      when(
        () => getMutedUsers(any()),
      ).thenAnswer((_) async => Right(MutedUsersPage(items: [_muted()], hasMore: false)));

      final cubit = build();
      await cubit.load();

      expect(cubit.state.reportsStatus, PrivacySafetyStatus.error);
      expect(cubit.state.mutedStatus, PrivacySafetyStatus.loaded);
      expect(cubit.state.muted, hasLength(1));
    });

    test('unmute drops the row, and a failed one leaves it alone', () async {
      when(() => getMyReports(any())).thenAnswer((_) async => Right(ReportsPage(items: [_report()], hasMore: false)));
      when(
        () => getMutedUsers(any()),
      ).thenAnswer((_) async => Right(MutedUsersPage(items: [_muted()], hasMore: false)));
      final cubit = build();
      await cubit.load();

      when(() => unmuteUser(any())).thenAnswer((_) async => const Left(NetworkFailure()));
      expect(await cubit.unmute('u2'), isFalse);
      expect(cubit.state.muted, hasLength(1), reason: 'a row must not vanish for a request that failed');
      expect(cubit.state.unmuting, isEmpty);

      when(() => unmuteUser(any())).thenAnswer((_) async => const Right(null));
      expect(await cubit.unmute('u2'), isTrue);
      expect(cubit.state.muted, isEmpty);
    });
  });
}
