import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../constants/api_constants.dart';
import '../security/certificate_pinning.dart';
import '../security/jwt_manager.dart';
import '../security/secure_storage_service.dart';
import '../security/session_manager.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'network_info.dart';
import 'token_refresh_service.dart';

/// Thin wrapper around a fully-configured [Dio] instance. Data sources take
/// an [ApiClient] (not a raw `Dio`) so every outgoing request — auth
/// header, retry, logging, cert pinning, error normalization — is
/// guaranteed to go through the same pipeline; nothing in `features/*`
/// constructs its own Dio.
class ApiClient {
  ApiClient({
    required SecureStorageService secureStorage,
    required JwtManager jwtManager,
    required SessionManager sessionManager,
    required NetworkInfo networkInfo,
    required TokenRefreshService tokenRefreshService,
  }) : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.baseUrl,
            connectTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
            sendTimeout: ApiConstants.sendTimeout,
            headers: {
              ApiConstants.headerContentType: ApiConstants.contentTypeJson,
              ApiConstants.headerApiVersion: 'v2',
            },
          ),
        ) {
    // Certificate pinning (M5) sits on the transport adapter itself, before
    // any interceptor runs.
    dio.httpClientAdapter = CertificatePinning.buildAdapter();

    dio.interceptors.addAll([
      AuthInterceptor(
        secureStorage: secureStorage,
        jwtManager: jwtManager,
        sessionManager: sessionManager,
        dio: dio,
        tokenRefreshService: tokenRefreshService,
      ),
      RetryInterceptor(dio, networkInfo),
      LoggingInterceptor(enabled: AppConfig.enableLogging),
      AppErrorInterceptor(),
    ]);
  }

  final Dio dio;
}
