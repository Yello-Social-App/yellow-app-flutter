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
    required this.createdAt,
  });

  final String id;
  final String username;
  final String? fullName;
  final String? bio;
  final String? avatarUrl;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, username, fullName, bio, avatarUrl];
}
