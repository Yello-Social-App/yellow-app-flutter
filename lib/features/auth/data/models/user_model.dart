import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.username,
    super.fullName,
    super.bio,
    super.avatarUrl,
    super.coverUrl,
    super.postsCount,
    super.friendsCount,
    required super.createdAt,
    required super.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    email: json['email'] as String? ?? '',
    username: json['username'] as String,
    fullName: json['fullName'] as String?,
    bio: json['bio'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    coverUrl: json['coverUrl'] as String?,
    postsCount: (json['postsCount'] as num?)?.toInt() ?? 0,
    friendsCount: (json['friendsCount'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    status: json['status'] as String? ?? 'ACTIVE',
  );
}
