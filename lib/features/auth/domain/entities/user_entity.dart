import 'package:equatable/equatable.dart';

/// The authenticated user's own profile — shaped after the backend's
/// `UserResponse` (`GET/POST /api/v1/users/me`). Lives in `features/auth`
/// because "who is signed in" is an auth-domain concept even though the
/// CRUD for it (`features/profile`) is a separate feature that imports this
/// entity rather than redefining it.
class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.email,
    required this.username,
    this.fullName,
    this.bio,
    this.avatarUrl,
    this.coverUrl,
    this.postsCount = 0,
    this.friendsCount = 0,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String email;
  final String username;
  final String? fullName;
  final String? bio;
  final String? avatarUrl;
  final String? coverUrl;
  final int postsCount;
  final int friendsCount;
  final DateTime createdAt;
  final String status;

  UserEntity copyWith({
    String? username,
    String? fullName,
    String? bio,
    String? avatarUrl,
  }) {
    return UserEntity(
      id: id,
      email: email,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl,
      postsCount: postsCount,
      friendsCount: friendsCount,
      createdAt: createdAt,
      status: status,
    );
  }

  @override
  List<Object?> get props => [
    id,
    username,
    fullName,
    bio,
    avatarUrl,
    coverUrl,
    postsCount,
    friendsCount,
  ];
}
