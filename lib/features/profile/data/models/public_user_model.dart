import '../../domain/entities/public_user_entity.dart';

class PublicUserModel extends PublicUserEntity {
  const PublicUserModel({
    required super.id,
    required super.username,
    super.fullName,
    super.bio,
    super.avatarUrl,
    super.coverUrl,
    super.friendStatus,
    super.postsCount,
    super.friendsCount,
    required super.createdAt,
  });

  factory PublicUserModel.fromJson(Map<String, dynamic> json) =>
      PublicUserModel(
        id: json['id'] as String,
        username: json['username'] as String,
        fullName: json['fullName'] as String?,
        bio: json['bio'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        coverUrl: json['coverUrl'] as String?,
        friendStatus: json['friendStatus'] as String?,
        postsCount: (json['postsCount'] as num?)?.toInt() ?? 0,
        friendsCount: (json['friendsCount'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
