import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/registration_result.dart';

/// Auth is mostly a set of commands, not a resource to fetch — a
/// successful login, or a `REGISTER`-purpose OTP verify, ends by handing
/// the returned token pair to `SessionManager.startSession` internally
/// (see `AuthRepositoryImpl`), so nothing above this repository ever
/// touches a raw access/refresh token. The one exception is
/// `RESET_PASSWORD`-purpose OTP verify, which has no session to start —
/// see [verifyOtp]'s doc.
abstract interface class AuthRepository {
  Future<Either<Failure, RegistrationResult>> register({
    required String email,
    required String password,
    required String username,
    String? fullName,
  });

  /// A `REGISTER`-purpose [code] starts the session and returns null. A
  /// `RESET_PASSWORD`-purpose one starts no session — the caller gets the
  /// backend's one-time reset token back instead, to spend on
  /// [resetPassword].
  Future<Either<Failure, String?>> verifyOtp({required String email, required String code});

  /// `POST /auth/resend-otp` — re-sends whichever code [email]'s account
  /// currently needs. Always succeeds even for an unknown/suspended
  /// account or one still inside the resend cooldown — the backend never
  /// confirms whether an address is registered this way.
  Future<Either<Failure, void>> resendOtp(String email);

  /// On success, starts the session (see class doc). [rememberMe] (default
  /// `true`) is passed straight through to `SessionManager.startSession` —
  /// see its doc for what turning it off actually changes.
  Future<Either<Failure, void>> login({required String email, required String password, bool rememberMe = true});

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, void>> forgotPassword(String email);

  Future<Either<Failure, void>> resetPassword({required String token, required String newPassword});
}
