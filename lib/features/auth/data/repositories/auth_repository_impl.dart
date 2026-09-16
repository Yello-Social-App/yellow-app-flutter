import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/security/session_manager.dart';
import '../../domain/entities/registration_result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._local, this._sessionManager, this._networkInfo);

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final SessionManager _sessionManager;
  final NetworkInfo _networkInfo;

  Future<Either<Failure, T>> _run<T>(Future<T> Function() body) async {
    if (!await _networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await body());
    } on AppException catch (e) {
      return Left(ErrorHandler.toFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, RegistrationResult>> register({
    required String email,
    required String password,
    required String username,
    String? fullName,
  }) => _run(() async {
    final res = await _remote.register(email: email, password: password, username: username, fullName: fullName);
    await _local.setLastEmail(email);
    return RegistrationResult(userId: res.userId, email: res.email, message: res.message);
  });

  @override
  Future<Either<Failure, String?>> verifyOtp({required String email, required String code}) => _run(() async {
    final result = await _remote.verifyOtp(email: email, code: code);
    if (result.purpose == 'RESET_PASSWORD') return result.resetToken;
    final tokens = result.tokens!;
    await _sessionManager.startSession(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken);
    return null;
  });

  @override
  Future<Either<Failure, void>> resendOtp(String email) => _run(() => _remote.resendOtp(email));

  @override
  Future<Either<Failure, void>> login({required String email, required String password, bool rememberMe = true}) =>
      _run(() async {
        final tokens = await _remote.login(email: email, password: password);
        await _local.setLastEmail(email);
        await _sessionManager.startSession(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          rememberMe: rememberMe,
        );
      });

  @override
  Future<Either<Failure, void>> logout() => _run(() async {
    try {
      await _remote.logout();
    } finally {
      // The session ends locally even if the server-side revoke call
      // fails (offline logout, expired token) — the user's intent to
      // sign out shouldn't be blocked by a network error.
      await _sessionManager.endSession();
    }
  });

  @override
  Future<Either<Failure, void>> forgotPassword(String email) => _run(() => _remote.forgotPassword(email));

  @override
  Future<Either<Failure, void>> resetPassword({required String token, required String newPassword}) =>
      _run(() => _remote.resetPassword(token: token, newPassword: newPassword));
}
