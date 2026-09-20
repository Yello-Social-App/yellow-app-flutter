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
  Future<UserModel> updateProfile({
    String? username,
    String? fullName,
    String? bio,
    bool clearFullName = false,
    bool clearBio = false,
    File? avatar,
    File? cover,
    bool? removeAvatar,
    bool? removeCover,
  });
  Future<UserModel> uploadAvatar(File file);
  Future<PublicUserModel> getUser(String userId);
  Future<({List<PostModel> items, bool hasMore})> getUserPosts(
    String userId, {
    int page,
  });
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
  Future<UserModel> updateProfile({
    String? username,
    String? fullName,
    String? bio,
    bool clearFullName = false,
    bool clearBio = false,
    File? avatar,
    File? cover,
    bool? removeAvatar,
    bool? removeCover,
  }) => _guard(() async {
    final fields = <String, dynamic>{
      'username': ?username,
      if (clearFullName || fullName != null)
        'fullName': clearFullName ? null : fullName,
      if (clearBio || bio != null) 'bio': clearBio ? null : bio,
    };

    // `POST /users/me` has two request bodies in the spec, and they are not
    // interchangeable: the `application/json` one carries *only* username /
    // fullName / bio, while `removeAvatar` / `removeCover` (and the image
    // parts themselves) exist on the `multipart/form-data` one alone. Sent
    // as JSON, a remove flag is simply not a field the server reads — the
    // call succeeds, the response still has the old `avatarUrl`, and
    // "remove photo" looks like it silently failed. So anything touching an
    // image — uploading one *or* clearing one — goes multipart.
    final wantsRemoval = removeAvatar == true || removeCover == true;
    final isMultipart = avatar != null || cover != null || wantsRemoval;

    Object body = fields;
    if (isMultipart) {
      body = FormData.fromMap({
        for (final entry in fields.entries) entry.key: entry.value ?? '',
        // Laravel's `boolean` rule accepts "1"/"0" as well as true/false;
        // multipart has no native boolean, so send the digit form.
        if (removeAvatar != null) 'removeAvatar': removeAvatar ? '1' : '0',
        if (removeCover != null) 'removeCover': removeCover ? '1' : '0',
        if (avatar != null) 'avatar': await _imagePart(avatar),
        if (cover != null) 'cover': await _imagePart(cover),
      });
    }

    final res = await _dio.post<Map<String, dynamic>>(
      VersionedEndpoints.me(),
      data: body,
    );
    return UserModel.fromJson(ApiEnvelope.data(res));
  });

  @override
  Future<UserModel> uploadAvatar(File file) => updateProfile(avatar: file);

  Future<MultipartFile> _imagePart(File file) async {
    if (await file.length() > 5 * 1024 * 1024) {
      throw const AppException('Images must be 5 MB or smaller.');
    }
    final handle = await file.open();
    late List<int> bytes;
    try {
      bytes = await handle.read(12);
    } finally {
      await handle.close();
    }
    final mime = switch (bytes) {
      [0xff, 0xd8, 0xff, ...] => 'image/jpeg',
      [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, ...] => 'image/png',
      [0x47, 0x49, 0x46, 0x38, 0x37 || 0x39, 0x61, ...] => 'image/gif',
      [0x52, 0x49, 0x46, 0x46, _, _, _, _, 0x57, 0x45, 0x42, 0x50] =>
        'image/webp',
      _ => null,
    };
    if (mime == null) {
      throw const AppException('Choose a JPEG, PNG, GIF, or WebP image.');
    }
    return MultipartFile.fromFile(
      file.path,
      contentType: DioMediaType.parse(mime),
    );
  }

  @override
  Future<PublicUserModel> getUser(String userId) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      VersionedEndpoints.user(userId),
    );
    return PublicUserModel.fromJson(ApiEnvelope.data(res));
  });

  @override
  Future<({List<PostModel> items, bool hasMore})> getUserPosts(
    String userId, {
    int page = 0,
  }) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      VersionedEndpoints.userPosts(userId),
      queryParameters: {'page': page, 'size': _pageSize},
    );
    final envelope = ApiEnvelope.page(res);
    return (
      items: envelope.content.map(PostModel.fromJson).toList(),
      hasMore: envelope.hasMore,
    );
  });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : ErrorHandler.fromDioException(e);
    }
  }
}
