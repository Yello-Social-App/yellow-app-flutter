import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/public_user_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remote, this._networkInfo);

  final ProfileRemoteDataSource _remote;
  final NetworkInfo _networkInfo;

  Future<Either<Failure, T>> _run<T>(Future<T> Function() body) async {
    if (!await _networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await body());
    } on AppException catch (e) {
      return Left(ErrorHandler.toFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getMe() => _run(_remote.getMe);

  @override
  Future<Either<Failure, UserEntity>> updateProfile({String? username, String? fullName, String? bio}) =>
      _run(() => _remote.updateProfile(username: username, fullName: fullName, bio: bio));

  @override
  Future<Either<Failure, UserEntity>> updateAvatar(File file) => _run(() => _remote.uploadAvatar(file));

  @override
  Future<Either<Failure, PublicUserEntity>> getUser(String userId) => _run(() => _remote.getUser(userId));

  @override
  Future<Either<Failure, UserPostsPage>> getUserPosts(String userId, {int page = 0}) => _run(() async {
        final result = await _remote.getUserPosts(userId, page: page);
        return UserPostsPage(posts: result.items, hasMore: result.hasMore);
      });
}
