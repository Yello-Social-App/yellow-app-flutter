import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_versioning/versioned_endpoints.dart';

/// A raw `TokenPairResponse` — kept out of the domain layer entirely; see
/// `AuthRepositoryImpl`, the only place this leaves the data layer (handed
/// straight to `SessionManager.startSession`).
class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;
}

class RegistrationResponse {
  const RegistrationResponse({required this.userId, required this.email, required this.message});
  final String userId;
  final String email;
  final String message;
}

abstract interface class AuthRemoteDataSource {
  Future<RegistrationResponse> register({
    required String email,
    required String password,
    required String username,
    String? fullName,
  });
  Future<TokenPair> verifyOtp({required String email, required String code});
  Future<TokenPair> login({required String email, required String password});
  Future<void> logout();
  Future<void> forgotPassword(String email);
  Future<void> resetPassword({required String token, required String newPassword});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  @override
  Future<RegistrationResponse> register({
    required String email,
    required String password,
    required String username,
    String? fullName,
  }) =>
      _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          VersionedEndpoints.register(),
          data: {
            'email': email,
            'password': password,
            'username': username,
            if (fullName != null) 'fullName': fullName,
          },
        );
        final data = ApiEnvelope.data(res);
        return RegistrationResponse(
          userId: data['userId'] as String,
          email: data['email'] as String,
          message: data['message'] as String? ?? '',
        );
      });

  @override
  Future<TokenPair> verifyOtp({required String email, required String code}) => _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          VersionedEndpoints.verifyOtp(),
          data: {'email': email, 'code': code},
        );
        return _toTokenPair(ApiEnvelope.data(res));
      });

  @override
  Future<TokenPair> login({required String email, required String password}) => _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          VersionedEndpoints.login(),
          data: {'email': email, 'password': password},
        );
        return _toTokenPair(ApiEnvelope.data(res));
      });

  TokenPair _toTokenPair(Map<String, dynamic> json) => TokenPair(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );

  @override
  Future<void> logout() => _guard(() => _dio.post<void>(VersionedEndpoints.logout()));

  @override
  Future<void> forgotPassword(String email) => _guard(
        () => _dio.post<void>(VersionedEndpoints.forgotPassword(), data: {'email': email}),
      );

  @override
  Future<void> resetPassword({required String token, required String newPassword}) => _guard(
        () => _dio.post<void>(
          VersionedEndpoints.resetPassword(),
          data: {'token': token, 'newPassword': newPassword},
        ),
      );

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : ErrorHandler.fromDioException(e);
    }
  }
}
