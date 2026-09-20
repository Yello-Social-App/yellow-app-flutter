import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/project_entity.dart';

/// One offset-paged page of `GET /projects`.
class ProjectsPage {
  const ProjectsPage({required this.projects, required this.hasMore});
  final List<ProjectEntity> projects;
  final bool hasMore;
}

/// Domain-facing contract for the Showcase.
abstract interface class ShowcaseRepository {
  Future<Either<Failure, ProjectsPage>> getProjects({
    ProjectSort sort = ProjectSort.trending,
    String? tech,
    bool? featured,
    int page = 0,
  });

  /// Most-used tech names across every project, for the filter row.
  Future<Either<Failure, List<TechCountEntity>>> getTech({int limit = 10});

  Future<Either<Failure, ProjectEntity>> getProject(String projectId);

  Future<Either<Failure, ProjectEntity>> publishProject({
    required String name,
    required String tagline,
    required String emoji,
    List<String> tech = const [],
    String? repoUrl,
    String? liveUrl,
  });

  /// Fire-and-forget view counter. Rate-limited server-side, so a rejected
  /// repeat is not an error worth surfacing — see the impl.
  Future<Either<Failure, void>> recordView(String projectId);

  /// Likes or unlikes depending on [project]'s current `isLiked`, returning the
  /// project with the server's authoritative count merged back in.
  Future<Either<Failure, ProjectEntity>> toggleLike(ProjectEntity project);
}
