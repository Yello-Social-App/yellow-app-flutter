import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_versioning/versioned_endpoints.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../feed/data/models/post_model.dart';
import '../models/public_user_model.dart';

abstract interface class ProfileRemoteDataSource {
  Future<UserModel> getMe();
  Future<UserModel> updateProfile({String? username, String? fullName, String? bio});
  Future<UserModel> uploadAvatar(File file);
  Future<PublicUserModel> getUser(String userId);
  Future<({List<PostModel> items, bool hasMore})> getUserPosts(String userId, {int page});
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  static const _pageSize = 20;

  @override
  Future<UserModel> getMe() => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(VersionedEndpoints.me());
        return UserModel.fromJson(ApiEnvelope.data(res));
      });

  @override
  Future<UserModel> updateProfile({String? username, String? fullName, String? bio}) => _guard(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          VersionedEndpoints.me(),
          data: {
            'username': ?username,
            'fullName': ?fullName,
            'bio': ?bio,
          },
        );
        return UserModel.fromJson(ApiEnvelope.data(res));
      });

  @override
  Future<UserModel> uploadAvatar(File file) => _guard(() async {
        final form = FormData.fromMap({'file': await MultipartFile.fromFile(file.path)});
        final res = await _dio.put<Map<String, dynamic>>(VersionedEndpoints.meAvatar(), data: form);
        return UserModel.fromJson(ApiEnvelope.data(res));
      });

  @override
  Future<PublicUserModel> getUser(String userId) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(VersionedEndpoints.user(userId));
        return PublicUserModel.fromJson(ApiEnvelope.data(res));
      });

  @override
  Future<({List<PostModel> items, bool hasMore})> getUserPosts(String userId, {int page = 0}) =>
      _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          VersionedEndpoints.userPosts(userId),
          queryParameters: {'page': page, 'size': _pageSize},
        );
        final envelope = ApiEnvelope.page(res);
        return (items: envelope.content.map(PostModel.fromJson).toList(), hasMore: envelope.hasMore);
      });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : ErrorHandler.fromDioException(e);
    }
  }
}
