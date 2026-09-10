import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/registration_result.dart';

/// Auth is a set of commands, not a resource to fetch — successful
/// login/OTP-verify calls end by handing the returned token pair to
/// `SessionManager.startSession` internally (see `AuthRepositoryImpl`), so
/// nothing above this repository ever touches a raw access/refresh token.
abstract interface class AuthRepository {
  Future<Either<Failure, RegistrationResult>> register({
    required String email,
    required String password,
    required String username,
    String? fullName,
  });

  /// On success, starts the session (see class doc).
  Future<Either<Failure, void>> verifyOtp({required String email, required String code});

  /// On success, starts the session (see class doc). [rememberMe] (default
  /// `true`) is passed straight through to `SessionManager.startSession` —
  /// see its doc for what turning it off actually changes.
  Future<Either<Failure, void>> login({
    required String email,
    required String password,
    bool rememberMe = true,
  });

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, void>> forgotPassword(String email);

  Future<Either<Failure, void>> resetPassword({required String token, required String newPassword});
}
