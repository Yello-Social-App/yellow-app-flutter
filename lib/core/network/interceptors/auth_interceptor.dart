import 'package:dio/dio.dart';

import '../../constants/api_constants.dart';
import '../../security/jwt_manager.dart';
import '../../security/secure_storage_service.dart';
import '../../security/session_manager.dart';
import '../token_refresh_service.dart';

/// Attaches the bearer access token to every outgoing request and,
/// transparently, refreshes an expired one on a 401 before retrying the
/// original call exactly once. Callers never see the refresh happen — a
/// repository just gets its data (or a real, final [DioException]).
///
/// OWASP Mobile M6/M10 (insecure authorization / insufficient cryptography):
/// the token itself never touches memory outside [SecureStorageService]'s
/// encrypted-at-rest store, and expiry is checked locally via [JwtManager]
/// before every request so an already-dead token is never sent at all.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.secureStorage,
    required this.jwtManager,
    required this.sessionManager,
    required this.dio,
    required this.tokenRefreshService,
  });

  final SecureStorageService secureStorage;
  final JwtManager jwtManager;
  final SessionManager sessionManager;
  final TokenRefreshService tokenRefreshService;

  /// The main app [Dio] — used to retry the original request post-refresh.
  final Dio dio;

  /// One-at-a-time refresh gate: concurrent 401s from several in-flight
  /// requests must not each fire their own refresh call.
  Future<bool>? _refreshing;

  static const _retriedKey = 'auth_retried';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await secureStorage.readAccessToken();
    if (token != null && !jwtManager.isExpired(token)) {
      options.headers[ApiConstants.headerAuthorization] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;

    if (response?.statusCode != 401 || alreadyRetried) {
      handler.next(err);
      return;
    }

    final refreshed = await (_refreshing ??= tokenRefreshService.refresh());
    _refreshing = null;

    if (!refreshed) {
      await sessionManager.notifySessionExpired();
      handler.next(err);
      return;
    }

    try {
      final token = await secureStorage.readAccessToken();
      final retryOptions = err.requestOptions
        ..extra[_retriedKey] = true
        ..headers[ApiConstants.headerAuthorization] = 'Bearer $token';
      // Dio consumes multipart streams on the first attempt. Clone the form
      // so avatar/cover uploads can be replayed after refreshing the JWT.
      final body = retryOptions.data;
      if (body is FormData) retryOptions.data = body.clone();
      final response = await dio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
