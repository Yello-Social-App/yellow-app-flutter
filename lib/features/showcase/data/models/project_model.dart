import '../../domain/entities/project_entity.dart';

/// JSON mapping for the backend's `Project` schema.
class ProjectModel extends ProjectEntity {
  const ProjectModel({
    required super.id,
    required super.name,
    required super.tagline,
    required super.description,
    required super.emoji,
    super.tech,
    required super.authorId,
    required super.authorUsername,
    super.authorFullName,
    super.authorAvatarUrl,
    super.repoUrl,
    super.liveUrl,
    super.starCount,
    super.likeCount,
    super.viewCount,
    required super.createdAt,
    super.isLiked,
    super.isFeatured,
    super.isOwner,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>? ?? const {};
    return ProjectModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      description: json['description'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🚀',
      tech: [
        for (final item in (json['tech'] as List<dynamic>? ?? const []))
          if (item is String && item.isNotEmpty) item,
      ],
      authorId: author['id'] as String? ?? '',
      authorUsername: author['username'] as String? ?? 'unknown',
      authorFullName: author['fullName'] as String?,
      authorAvatarUrl: author['avatarUrl'] as String?,
      repoUrl: json['repoUrl'] as String?,
      liveUrl: json['liveUrl'] as String?,
      // Kept nullable: "stars unknown" and "zero stars" are different things
      // and `sort=stars` depends on the difference.
      starCount: (json['starCount'] as num?)?.toInt(),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isLiked: json['isLiked'] as bool? ?? false,
      isFeatured: json['isFeatured'] as bool? ?? false,
      isOwner: json['isOwner'] as bool? ?? false,
    );
  }
}

class TechCountModel extends TechCountEntity {
  const TechCountModel({required super.name, required super.projectCount});

  factory TechCountModel.fromJson(Map<String, dynamic> json) => TechCountModel(
    name: json['name'] as String? ?? '',
    projectCount: (json['projectCount'] as num?)?.toInt() ?? 0,
  );
}

class ProjectLikeResultModel extends ProjectLikeResult {
  const ProjectLikeResultModel({
    required super.id,
    required super.likeCount,
    required super.isLiked,
  });

  factory ProjectLikeResultModel.fromJson(Map<String, dynamic> json) => ProjectLikeResultModel(
    id: json['id'] as String? ?? '',
    likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    isLiked: json['isLiked'] as bool? ?? false,
  );
}
