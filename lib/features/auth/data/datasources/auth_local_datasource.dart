import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive, device-local auth state — NOT tokens (those live in
/// `SecureStorageService`/`SessionManager`). Just the "remember my email"
/// convenience on the login screen.
abstract interface class AuthLocalDataSource {
  Future<String?> getLastEmail();
  Future<void> setLastEmail(String email);
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  static const _key = 'auth.last_email';

  @override
  Future<String?> getLastEmail() async => (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> setLastEmail(String email) async =>
      (await SharedPreferences.getInstance()).setString(_key, email);
}
