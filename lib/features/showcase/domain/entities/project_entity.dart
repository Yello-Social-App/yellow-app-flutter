import 'package:equatable/equatable.dart';

/// `GET /projects`' `sort` parameter. `trending` is the server default.
enum ProjectSort {
  trending,
  newest,
  stars;

  String get wireValue => switch (this) {
    ProjectSort.trending => 'trending',
    ProjectSort.newest => 'newest',
    ProjectSort.stars => 'stars',
  };

  String get label => switch (this) {
    ProjectSort.trending => 'Trending',
    ProjectSort.newest => 'New',
    ProjectSort.stars => 'Stars',
  };
}

/// The only emoji `POST /projects` accepts — a closed `enum` on the wire, not
/// free text, so the publish form offers exactly these and nothing else. Order
/// is the spec's own.
const List<String> kProjectEmojis = ['🚀', '🧩', '🗺️', '🧾', '🤖', '🎨', '📱', '🛠️', '📚', '🎮'];

/// Longest a single tech tag may be, and the most tags one project may carry
/// (`CreateProjectRequest.tech`: `maxItems: 6`, each `maxLength: 24`).
const int kProjectTechMaxLength = 24;
const int kProjectTechMaxCount = 6;

/// Field caps from `CreateProjectRequest`.
const int kProjectNameMaxChars = 60;
const int kProjectTaglineMaxChars = 120;
const int kProjectUrlMaxChars = 2048;

/// One entry in the showcase grid — the backend's `Project`.
class ProjectEntity extends Equatable {
  const ProjectEntity({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.emoji,
    this.tech = const [],
    required this.authorId,
    required this.authorUsername,
    this.authorFullName,
    this.authorAvatarUrl,
    this.repoUrl,
    this.liveUrl,
    this.starCount,
    this.likeCount = 0,
    this.viewCount = 0,
    required this.createdAt,
    this.isLiked = false,
    this.isFeatured = false,
    this.isOwner = false,
  });

  final String id;
  final String name;
  final String tagline;

  /// Longer write-up. Present on the response but **not** settable through
  /// `POST /projects`, whose body has no `description` field — so a freshly
  /// published project comes back with this empty and there is no client-side
  /// way to fill it in. Not an oversight here; the create contract simply
  /// doesn't carry it.
  final String description;
  final String emoji;

  /// Up to [kProjectTechMaxCount] tech names. Doubles as the `tech` filter's
  /// vocabulary — see `GetProjectTechUseCase`.
  final List<String> tech;
  final String authorId;
  final String authorUsername;
  final String? authorFullName;
  final String? authorAvatarUrl;
  final String? repoUrl;
  final String? liveUrl;

  /// Upstream repository stars, when the backend could resolve them. Nullable
  /// rather than 0 so "not known" and "genuinely zero" stay distinguishable —
  /// `sort=stars` orders by this.
  final int? starCount;
  final int likeCount;
  final int viewCount;
  final DateTime createdAt;
  final bool isLiked;
  final bool isFeatured;
  final bool isOwner;

  String get authorDisplayName =>
      (authorFullName == null || authorFullName!.isEmpty) ? authorUsername : authorFullName!;

  bool get hasRepo => repoUrl != null && repoUrl!.isNotEmpty;
  bool get hasLive => liveUrl != null && liveUrl!.isNotEmpty;
  bool get hasDescription => description.trim().isNotEmpty;

  ProjectEntity copyWith({int? likeCount, bool? isLiked, int? viewCount}) {
    return ProjectEntity(
      id: id,
      name: name,
      tagline: tagline,
      description: description,
      emoji: emoji,
      tech: tech,
      authorId: authorId,
      authorUsername: authorUsername,
      authorFullName: authorFullName,
      authorAvatarUrl: authorAvatarUrl,
      repoUrl: repoUrl,
      liveUrl: liveUrl,
      starCount: starCount,
      likeCount: likeCount ?? this.likeCount,
      viewCount: viewCount ?? this.viewCount,
      createdAt: createdAt,
      isLiked: isLiked ?? this.isLiked,
      isFeatured: isFeatured,
      isOwner: isOwner,
    );
  }

  @override
  List<Object?> get props => [id, name, likeCount, viewCount, isLiked, isFeatured];
}

/// One row of `GET /projects/tech` — a tech name and how many projects use it.
/// Drives the filter chips, so the vocabulary always matches what is actually
/// published rather than a hardcoded list.
class TechCountEntity extends Equatable {
  const TechCountEntity({required this.name, required this.projectCount});

  final String name;
  final int projectCount;

  @override
  List<Object?> get props => [name, projectCount];
}

/// `POST`/`DELETE /projects/{id}/like`'s response (`ProjectLike`).
class ProjectLikeResult extends Equatable {
  const ProjectLikeResult({required this.id, required this.likeCount, required this.isLiked});

  final String id;
  final int likeCount;
  final bool isLiked;

  @override
  List<Object?> get props => [id, likeCount, isLiked];
}
