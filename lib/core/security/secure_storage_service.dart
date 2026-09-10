import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

/// OWASP Mobile **M9 — Insecure Data Storage**: anything sensitive (tokens,
/// session identifiers) is written through here, never through
/// `shared_preferences` or a plain file. `flutter_secure_storage` backs onto
/// Keychain (iOS) / EncryptedSharedPreferences+Keystore (Android), so the
/// values are encrypted at rest and outlive the process without living in
/// plaintext on disk.
abstract interface class SecureStorageService {
  Future<void> writeTokens({required String accessToken, required String refreshToken});
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> clearTokens();

  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<void> clearAll();
}

class SecureStorageServiceImpl implements SecureStorageService {
  SecureStorageServiceImpl([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: AppConstants.secureKeyAccessToken, value: accessToken);
    await _storage.write(key: AppConstants.secureKeyRefreshToken, value: refreshToken);
  }

  @override
  Future<String?> readAccessToken() => _storage.read(key: AppConstants.secureKeyAccessToken);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: AppConstants.secureKeyRefreshToken);

  @override
  Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.secureKeyAccessToken);
    await _storage.delete(key: AppConstants.secureKeyRefreshToken);
  }

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> clearAll() => _storage.deleteAll();
}
