import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/feedback_entity.dart';
import '../../domain/entities/post_report_entity.dart';
import '../../domain/repositories/safety_repository.dart';
import '../datasources/safety_remote_datasource.dart';

class SafetyRepositoryImpl implements SafetyRepository {
  SafetyRepositoryImpl(this._remote, this._networkInfo);

  final SafetyRemoteDataSource _remote;
  final NetworkInfo _networkInfo;

  Future<Either<Failure, T>> _run<T>(Future<T> Function() body) async {
    if (!await _networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await body());
    } on AppException catch (e) {
      return Left(ErrorHandler.toFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, FeedbackEntity>> submitFeedback({
    required FeedbackFeature feature,
    required int rating,
    String? note,
  }) =>
      _run(() => _remote.submitFeedback(feature: feature, rating: rating, note: note));

  @override
  Future<Either<Failure, FeedbackPage>> getMyFeedback({int page = 0}) => _run(() async {
        final result = await _remote.getMyFeedback(page: page);
        return FeedbackPage(items: result.items, hasMore: result.hasMore);
      });

  @override
  Future<Either<Failure, PostReportEntity>> reportPost({
    required String postId,
    required ReportReason reason,
    String? details,
  }) =>
      _run(() => _remote.reportPost(postId: postId, reason: reason, details: details));

  @override
  Future<Either<Failure, ReportsPage>> getMyReports({int page = 0}) => _run(() async {
        final result = await _remote.getMyReports(page: page);
        return ReportsPage(items: result.items, hasMore: result.hasMore);
      });

  @override
  Future<Either<Failure, void>> muteUser(String userId) => _run(() => _remote.muteUser(userId));

  @override
  Future<Either<Failure, void>> unmuteUser(String userId) => _run(() => _remote.unmuteUser(userId));

  @override
  Future<Either<Failure, MutedUsersPage>> getMutedUsers({int page = 0}) => _run(() async {
        final result = await _remote.getMutedUsers(page: page);
        return MutedUsersPage(items: result.items, hasMore: result.hasMore);
      });

  @override
  Future<Either<Failure, void>> hidePost(String postId) => _run(() => _remote.hidePost(postId));

  @override
  Future<Either<Failure, void>> unhidePost(String postId) => _run(() => _remote.unhidePost(postId));
}
