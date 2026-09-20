import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/project_entity.dart';
import '../../domain/repositories/showcase_repository.dart';
import '../datasources/showcase_remote_datasource.dart';

class ShowcaseRepositoryImpl implements ShowcaseRepository {
  ShowcaseRepositoryImpl(this._remote, this._networkInfo);

  final ShowcaseRemoteDataSource _remote;
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
  Future<Either<Failure, ProjectsPage>> getProjects({
    ProjectSort sort = ProjectSort.trending,
    String? tech,
    bool? featured,
    int page = 0,
  }) => _run(() async {
    final result = await _remote.getProjects(sort: sort, tech: tech, featured: featured, page: page);
    return ProjectsPage(projects: result.items, hasMore: result.hasMore);
  });

  @override
  Future<Either<Failure, List<TechCountEntity>>> getTech({int limit = 10}) =>
      _run(() => _remote.getTech(limit: limit));

  @override
  Future<Either<Failure, ProjectEntity>> getProject(String projectId) =>
      _run(() => _remote.getProject(projectId));

  @override
  Future<Either<Failure, ProjectEntity>> publishProject({
    required String name,
    required String tagline,
    required String emoji,
    List<String> tech = const [],
    String? repoUrl,
    String? liveUrl,
  }) => _run(
    () => _remote.publishProject(
      name: name,
      tagline: tagline,
      emoji: emoji,
      tech: tech,
      repoUrl: repoUrl,
      liveUrl: liveUrl,
    ),
  );

  /// Swallows failures on purpose. A view is telemetry the *user* did not ask
  /// for: the endpoint is rate-limited (a second open inside the window is a
  /// `429`), and surfacing that as an error on a detail screen would be noise
  /// about something nobody was trying to do.
  @override
  Future<Either<Failure, void>> recordView(String projectId) async {
    try {
      await _remote.recordView(projectId);
    } on AppException {
      // Intentionally ignored — see above.
    }
    return Right<Failure, void>(null);
  }

  @override
  Future<Either<Failure, ProjectEntity>> toggleLike(ProjectEntity project) => _run(() async {
    final result = project.isLiked
        ? await _remote.unlike(project.id)
        : await _remote.like(project.id);
    return project.copyWith(likeCount: result.likeCount, isLiked: result.isLiked);
  });
}
