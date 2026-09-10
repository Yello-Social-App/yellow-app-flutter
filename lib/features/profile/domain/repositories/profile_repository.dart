import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../features/auth/domain/entities/user_entity.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../entities/public_user_entity.dart';

class UserPostsPage {
  const UserPostsPage({required this.posts, required this.hasMore});
  final List<PostEntity> posts;
  final bool hasMore;
}

/// Domain-facing contract for viewing/editing users, backed by the live
/// backend's `/users` resource. `UserEntity` (the "me" shape) is defined in
/// `features/auth` — see that entity's doc for why.
abstract interface class ProfileRepository {
  Future<Either<Failure, UserEntity>> getMe();
  Future<Either<Failure, UserEntity>> updateProfile({String? username, String? fullName, String? bio});

  /// Replaces the signed-in user's avatar (`PUT /users/me/avatar`, multipart)
  /// and returns the updated `UserEntity` (its new `avatarUrl`).
  Future<Either<Failure, UserEntity>> updateAvatar(File file);
  Future<Either<Failure, PublicUserEntity>> getUser(String userId);
  Future<Either<Failure, UserPostsPage>> getUserPosts(String userId, {int page = 0});
}
