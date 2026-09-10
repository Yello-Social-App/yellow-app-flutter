import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../entities/public_user_entity.dart';
import '../repositories/profile_repository.dart';

class GetMeUseCase implements UseCase<UserEntity, NoParams> {
  GetMeUseCase(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Either<Failure, UserEntity>> call(NoParams params) => _repository.getMe();
}

class UpdateProfileParams extends Equatable {
  const UpdateProfileParams({this.username, this.fullName, this.bio});
  final String? username;
  final String? fullName;
  final String? bio;

  @override
  List<Object?> get props => [username, fullName, bio];
}

class UpdateProfileUseCase implements UseCase<UserEntity, UpdateProfileParams> {
  UpdateProfileUseCase(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Either<Failure, UserEntity>> call(UpdateProfileParams params) {
    if (params.username != null) {
      final error = Validators.handle(params.username);
      if (error != null) return Future.value(Left(ValidationFailure(error)));
    }
    return _repository.updateProfile(
      username: params.username,
      fullName: params.fullName == null ? null : InputSanitizer.sanitizeText(params.fullName!, maxLength: 100),
      bio: params.bio == null ? null : InputSanitizer.sanitizeText(params.bio!, maxLength: 500),
    );
  }
}

class UpdateAvatarUseCase implements UseCase<UserEntity, File> {
  UpdateAvatarUseCase(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Either<Failure, UserEntity>> call(File params) => _repository.updateAvatar(params);
}

class GetUserUseCase implements UseCase<PublicUserEntity, String> {
  GetUserUseCase(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Either<Failure, PublicUserEntity>> call(String userId) => _repository.getUser(userId);
}

class GetUserPostsParams extends Equatable {
  const GetUserPostsParams({required this.userId, this.page = 0});
  final String userId;
  final int page;

  @override
  List<Object?> get props => [userId, page];
}

class GetUserPostsUseCase implements UseCase<UserPostsPage, GetUserPostsParams> {
  GetUserPostsUseCase(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Either<Failure, UserPostsPage>> call(GetUserPostsParams params) =>
      _repository.getUserPosts(params.userId, page: params.page);
}
