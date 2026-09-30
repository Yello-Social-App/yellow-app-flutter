import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../constants/api_constants.dart';
import '../network/token_refresh_service.dart';
import '../security/certificate_pinning.dart';
import '../security/jwt_manager.dart';
import '../security/secure_storage_service.dart';

/// What a notification action needs to reach the API from whichever isolate
/// it landed in — the main one while the app is alive, the plugin's own
/// background engine when it is not. `sl` is empty over there and
/// `bootstrap()` never ran, so nothing here reaches into DI.
///
/// Token handling mirrors [AuthInterceptor]: never send a token already
/// known to be expired, and refresh once on a 401. The bearer header goes on
/// per request rather than on the client, because the retry runs with a
/// *different* token than the first attempt.
Dio backgroundDio() {
  // Statics don't cross an isolate boundary, so in the background engine
  // this is the first thing that sets the base URL at all.
  if (!AppConfig.isInitialized) AppConfig.init(baseUrl: AppConfig.defaultBaseUrl);
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      sendTimeout: ApiConstants.sendTimeout,
      headers: {'Accept': ApiConstants.contentTypeJson, ApiConstants.headerContentType: ApiConstants.contentTypeJson},
    ),
  )..httpClientAdapter = CertificatePinning.buildAdapter();
}

/// The stored access token, refreshed first when it has already expired.
/// Null when signed out or the refresh failed.
Future<String?> backgroundAccessToken(SecureStorageService storage) async {
  final token = await storage.readAccessToken();
  if (token == null) return null;
  return JwtManagerImpl().isExpired(token) ? refreshedAccessToken(storage) : token;
}

Future<String?> refreshedAccessToken(SecureStorageService storage) async {
  final refreshed = await TokenRefreshServiceImpl(storage).refresh();
  return refreshed ? storage.readAccessToken() : null;
}

Options bearer(String token) => Options(headers: {ApiConstants.headerAuthorization: 'Bearer $token'});
