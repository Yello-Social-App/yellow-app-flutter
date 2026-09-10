import '../../domain/entities/public_user_entity.dart';

class PublicUserModel extends PublicUserEntity {
  const PublicUserModel({
    required super.id,
    required super.username,
    super.fullName,
    super.bio,
    super.avatarUrl,
    required super.createdAt,
  });

  factory PublicUserModel.fromJson(Map<String, dynamic> json) => PublicUserModel(
        id: json['id'] as String,
        username: json['username'] as String,
        fullName: json['fullName'] as String?,
        bio: json['bio'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
