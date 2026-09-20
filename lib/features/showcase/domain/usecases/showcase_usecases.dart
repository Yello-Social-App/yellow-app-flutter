import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/project_entity.dart';
import '../repositories/showcase_repository.dart';

class GetProjectsParams extends Equatable {
  const GetProjectsParams({this.sort = ProjectSort.trending, this.tech, this.featured, this.page = 0});

  final ProjectSort sort;

  /// A single tech name from `GET /projects/tech`, or null for no filter.
  final String? tech;

  /// True restricts to featured projects; null means no filter. False would ask
  /// the server for the explicitly-not-featured ones, which no screen wants, so
  /// call sites pass true or null.
  final bool? featured;
  final int page;

  @override
  List<Object?> get props => [sort, tech, featured, page];
}

class GetProjectsUseCase implements UseCase<ProjectsPage, GetProjectsParams> {
  GetProjectsUseCase(this._repository);
  final ShowcaseRepository _repository;

  @override
  Future<Either<Failure, ProjectsPage>> call(GetProjectsParams params) => _repository.getProjects(
    sort: params.sort,
    tech: params.tech,
    featured: params.featured,
    page: params.page,
  );
}

class GetProjectTechParams extends Equatable {
  const GetProjectTechParams({this.limit = 10});

  /// The endpoint caps this at 20.
  final int limit;

  @override
  List<Object?> get props => [limit];
}

class GetProjectTechUseCase implements UseCase<List<TechCountEntity>, GetProjectTechParams> {
  GetProjectTechUseCase(this._repository);
  final ShowcaseRepository _repository;

  @override
  Future<Either<Failure, List<TechCountEntity>>> call(GetProjectTechParams params) =>
      _repository.getTech(limit: params.limit);
}

class GetProjectUseCase implements UseCase<ProjectEntity, String> {
  GetProjectUseCase(this._repository);
  final ShowcaseRepository _repository;

  @override
  Future<Either<Failure, ProjectEntity>> call(String projectId) => _repository.getProject(projectId);
}

class RecordProjectViewUseCase implements UseCase<void, String> {
  RecordProjectViewUseCase(this._repository);
  final ShowcaseRepository _repository;

  @override
  Future<Either<Failure, void>> call(String projectId) => _repository.recordView(projectId);
}

class ToggleProjectLikeUseCase implements UseCase<ProjectEntity, ProjectEntity> {
  ToggleProjectLikeUseCase(this._repository);
  final ShowcaseRepository _repository;

  @override
  Future<Either<Failure, ProjectEntity>> call(ProjectEntity project) =>
      _repository.toggleLike(project);
}

class PublishProjectParams extends Equatable {
  const PublishProjectParams({
    required this.name,
    required this.tagline,
    required this.emoji,
    this.tech = const [],
    this.repoUrl,
    this.liveUrl,
  });

  final String name;
  final String tagline;

  /// Must be one of [kProjectEmojis] — a closed enum server-side.
  final String emoji;
  final List<String> tech;
  final String? repoUrl;
  final String? liveUrl;

  @override
  List<Object?> get props => [name, tagline, emoji, tech, repoUrl, liveUrl];
}

/// Publishes a project — `POST /projects`.
///
/// Validates client-side what the server validates anyway, so a typo comes back
/// as a field message on the form rather than as a round-trip and a red banner:
/// required name/tagline, an emoji from the closed set, at most
/// [kProjectTechMaxCount] tech tags, and absolute http(s) URLs.
class PublishProjectUseCase implements UseCase<ProjectEntity, PublishProjectParams> {
  PublishProjectUseCase(this._repository);
  final ShowcaseRepository _repository;

  @override
  Future<Either<Failure, ProjectEntity>> call(PublishProjectParams params) {
    final name = InputSanitizer.sanitizeText(params.name, maxLength: kProjectNameMaxChars);
    if (name.isEmpty) {
      return Future.value(const Left(ValidationFailure('Give your project a name.')));
    }
    final tagline = InputSanitizer.sanitizeText(params.tagline, maxLength: kProjectTaglineMaxChars);
    if (tagline.isEmpty) {
      return Future.value(const Left(ValidationFailure('Add a one-line tagline.')));
    }
    if (!kProjectEmojis.contains(params.emoji)) {
      return Future.value(const Left(ValidationFailure('Pick one of the project icons.')));
    }

    final tech = <String>[];
    for (final raw in params.tech) {
      final clean = InputSanitizer.sanitizeText(raw, maxLength: kProjectTechMaxLength);
      if (clean.isEmpty || tech.contains(clean)) continue;
      tech.add(clean);
    }
    if (tech.length > kProjectTechMaxCount) {
      return Future.value(
        const Left(ValidationFailure('Up to $kProjectTechMaxCount tech tags.')),
      );
    }

    final repoUrl = _normalizeUrl(params.repoUrl);
    if (repoUrl == _invalidUrl) {
      return Future.value(const Left(ValidationFailure('That repo link is not a valid URL.')));
    }
    final liveUrl = _normalizeUrl(params.liveUrl);
    if (liveUrl == _invalidUrl) {
      return Future.value(const Left(ValidationFailure('That live link is not a valid URL.')));
    }

    return _repository.publishProject(
      name: name,
      tagline: tagline,
      emoji: params.emoji,
      tech: tech,
      repoUrl: repoUrl,
      liveUrl: liveUrl,
    );
  }

  /// Sentinel for "the user typed something, and it isn't a URL" — distinct
  /// from null, which means they left the field empty.
  static const String _invalidUrl = '\u0000invalid';

  static String? _normalizeUrl(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.length > kProjectUrlMaxChars) return _invalidUrl;
    // Accept a bare host and add the scheme rather than rejecting it — the
    // server wants an absolute `uri`, and "github.com/me/thing" is what people
    // actually paste.
    final candidate = value.startsWith('http://') || value.startsWith('https://')
        ? value
        : 'https://$value';
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasAuthority || !uri.host.contains('.')) return _invalidUrl;
    return candidate;
  }
}
