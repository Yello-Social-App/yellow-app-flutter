import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../security/secure_storage_service.dart';
import '../utils/logger.dart';
import 'api_versioning/versioned_endpoints.dart';

/// Exchanges the stored refresh token for a new access/refresh pair,
/// writing the result straight to [SecureStorageService]. This is the one
/// place that logic lives — both [AuthInterceptor] (mid-session, on a 401)
/// and [SessionManager] (cold-start `bootstrap()`, when the access token
/// has already expired by the time the app relaunches) call into it, so
/// there's exactly one definition of "how a refresh works" instead of two
/// copies drifting apart.
abstract interface class TokenRefreshService {
  /// Returns whether the refresh succeeded. `false` (never throws) if
  /// there's no refresh token stored, the call fails, or the response is
  /// missing an access token.
  Future<bool> refresh();
}

class TokenRefreshServiceImpl implements TokenRefreshService {
  TokenRefreshServiceImpl(this._secureStorage);

  final SecureStorageService _secureStorage;

  @override
  Future<bool> refresh() async {
    final refreshToken = await _secureStorage.readRefreshToken();
    if (refreshToken == null) return false;

    try {
      // Bare Dio with no interceptors — deliberately isolated from the main
      // app Dio so a failing refresh can never recursively trigger
      // AuthInterceptor (or itself) again.
      final bare = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
      final res = await bare.post<Map<String, dynamic>>(
        VersionedEndpoints.refresh(),
        data: {'refreshToken': refreshToken},
      );
      // `{ success, data: { accessToken, refreshToken, accessTokenExpiresAt,
      // tokenType }, timestamp }` — see ApiEnvelope; a bare Dio has no
      // interceptor to unwrap this for us.
      final data = res.data?['data'] as Map<String, dynamic>?;
      final newAccess = data?['accessToken'] as String?;
      final newRefresh = data?['refreshToken'] as String?;
      if (newAccess == null) return false;

      await _secureStorage.writeTokens(
        accessToken: newAccess,
        refreshToken: newRefresh ?? refreshToken,
      );
      return true;
    } catch (e) {
      appLogger.w('Token refresh failed: $e');
      return false;
    }
  }
}
