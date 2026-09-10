import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/constants/app_constants.dart';
import 'package:yello_social_app/core/network/token_refresh_service.dart';
import 'package:yello_social_app/core/security/jwt_manager.dart';
import 'package:yello_social_app/core/security/secure_storage_service.dart';
import 'package:yello_social_app/core/security/session_manager.dart';

import '../../helpers/mock_data.dart';

/// Minimal in-memory stand-in for the real Keychain/Keystore-backed
/// implementation — real enough (an actual key-value map) to assert what
/// [SessionManagerImpl] actually reads/writes/clears, without mocking every
/// call.
class _FakeSecureStorage implements SecureStorageService {
  final Map<String, String> store = {};

  @override
  Future<void> writeTokens({required String accessToken, required String refreshToken}) async {
    store[AppConstants.secureKeyAccessToken] = accessToken;
    store[AppConstants.secureKeyRefreshToken] = refreshToken;
  }

  @override
  Future<String?> readAccessToken() async => store[AppConstants.secureKeyAccessToken];

  @override
  Future<String?> readRefreshToken() async => store[AppConstants.secureKeyRefreshToken];

  @override
  Future<void> clearTokens() async {
    store.remove(AppConstants.secureKeyAccessToken);
    store.remove(AppConstants.secureKeyRefreshToken);
  }

  @override
  Future<void> write(String key, String value) async => store[key] = value;

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> delete(String key) async => store.remove(key);

  @override
  Future<void> clearAll() async => store.clear();
}

class _MockTokenRefreshService extends Mock implements TokenRefreshService {}

void main() {
  late _FakeSecureStorage secureStorage;
  late _MockTokenRefreshService tokenRefreshService;
  late SessionManagerImpl sessionManager;

  setUp(() {
    secureStorage = _FakeSecureStorage();
    tokenRefreshService = _MockTokenRefreshService();
    sessionManager = SessionManagerImpl(secureStorage, JwtManagerImpl(), tokenRefreshService);
  });

  group('bootstrap', () {
    test('authenticated immediately when the stored access token is still valid', () async {
      await secureStorage.writeTokens(
        accessToken: buildFakeJwt(expSecondsFromNow: 3600),
        refreshToken: 'refresh-token',
      );

      await sessionManager.bootstrap();

      expect(sessionManager.currentState, SessionState.authenticated);
      verifyNever(() => tokenRefreshService.refresh());
    });

    test('silently refreshes an expired access token instead of forcing a re-login', () async {
      // This was the actual bug: bootstrap used to only look at the access
      // token's own (short-lived, by design) expiry and never tried the
      // refresh token — so any cold start past that TTL forced a full
      // re-login even with a perfectly valid refresh token sitting right
      // next to it in storage.
      await secureStorage.writeTokens(
        accessToken: buildFakeJwt(expSecondsFromNow: -60),
        refreshToken: 'refresh-token',
      );
      when(() => tokenRefreshService.refresh()).thenAnswer((_) async => true);

      await sessionManager.bootstrap();

      expect(sessionManager.currentState, SessionState.authenticated);
      verify(() => tokenRefreshService.refresh()).called(1);
    });

    test('logs out when the access token is expired and the refresh attempt fails', () async {
      await secureStorage.writeTokens(
        accessToken: buildFakeJwt(expSecondsFromNow: -60),
        refreshToken: 'refresh-token',
      );
      when(() => tokenRefreshService.refresh()).thenAnswer((_) async => false);

      await sessionManager.bootstrap();

      expect(sessionManager.currentState, SessionState.unauthenticated);
      expect(await secureStorage.readAccessToken(), isNull);
    });

    test('logs out with no stored tokens at all, without crashing', () async {
      when(() => tokenRefreshService.refresh()).thenAnswer((_) async => false);

      await sessionManager.bootstrap();

      expect(sessionManager.currentState, SessionState.unauthenticated);
    });

    test('skips straight to unauthenticated when rememberMe was declined, without attempting a refresh', () async {
      await secureStorage.writeTokens(
        accessToken: buildFakeJwt(expSecondsFromNow: 3600),
        refreshToken: 'refresh-token',
      );
      await secureStorage.write(AppConstants.secureKeyRememberMe, 'false');

      await sessionManager.bootstrap();

      expect(sessionManager.currentState, SessionState.unauthenticated);
      expect(await secureStorage.readAccessToken(), isNull);
      verifyNever(() => tokenRefreshService.refresh());
    });

    test('treats an absent rememberMe flag as remembered (pre-existing sessions keep working)', () async {
      await secureStorage.writeTokens(
        accessToken: buildFakeJwt(expSecondsFromNow: 3600),
        refreshToken: 'refresh-token',
      );
      // secureKeyRememberMe deliberately never written.

      await sessionManager.bootstrap();

      expect(sessionManager.currentState, SessionState.authenticated);
    });
  });

  group('startSession', () {
    test('stores rememberMe alongside the tokens', () async {
      await sessionManager.startSession(accessToken: 'a', refreshToken: 'r', rememberMe: false);

      expect(secureStorage.store[AppConstants.secureKeyRememberMe], 'false');
      expect(sessionManager.currentState, SessionState.authenticated);
    });

    test('defaults rememberMe to true when not specified', () async {
      await sessionManager.startSession(accessToken: 'a', refreshToken: 'r');

      expect(secureStorage.store[AppConstants.secureKeyRememberMe], 'true');
    });
  });

  group('endSession / notifySessionExpired', () {
    test('endSession clears the tokens and the rememberMe flag', () async {
      await sessionManager.startSession(accessToken: 'a', refreshToken: 'r', rememberMe: false);

      await sessionManager.endSession();

      expect(secureStorage.store, isEmpty);
      expect(sessionManager.currentState, SessionState.unauthenticated);
    });

    test('notifySessionExpired clears the tokens and the rememberMe flag', () async {
      await sessionManager.startSession(accessToken: 'a', refreshToken: 'r');

      await sessionManager.notifySessionExpired();

      expect(secureStorage.store, isEmpty);
      expect(sessionManager.currentState, SessionState.unauthenticated);
    });
  });
}
