import 'package:equatable/equatable.dart';

/// Shaped after the backend's `PublicUserResponse` — someone else's
/// profile, viewed read-only (no email/status, unlike `UserEntity` which
/// is the auth feature's "me" shape).
class PublicUserEntity extends Equatable {
  const PublicUserEntity({
    required this.id,
    required this.username,
    this.fullName,
    this.bio,
    this.avatarUrl,
    this.coverUrl,
    this.friendStatus,
    this.postsCount = 0,
    this.friendsCount = 0,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String? fullName;
  final String? bio;
  final String? avatarUrl;
  final String? coverUrl;
  final String? friendStatus;
  final int postsCount;
  final int friendsCount;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    username,
    fullName,
    bio,
    avatarUrl,
    coverUrl,
    friendStatus,
    postsCount,
    friendsCount,
  ];
}
