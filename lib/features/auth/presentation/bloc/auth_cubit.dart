import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/password_reset_usecases.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';

enum AuthStatus { idle, submitting, awaitingOtp, resetEmailSent, success, failure }

class AuthState extends Equatable {
  const AuthState({this.status = AuthStatus.idle, this.pendingEmail, this.errorMessage});

  final AuthStatus status;

  /// Set once `register()` succeeds — the email the OTP screen verifies
  /// against.
  final String? pendingEmail;
  final String? errorMessage;

  bool get isSubmitting => status == AuthStatus.submitting;

  AuthState copyWith({AuthStatus? status, String? pendingEmail, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, pendingEmail, errorMessage];
}

/// Drives every auth screen (login, register, OTP, forgot/reset password).
/// One Cubit for the whole flow because the steps are sequential and share
/// `pendingEmail` state — a fresh instance is created per screen-visit via
/// DI's `registerFactory`.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required RegisterUseCase register,
    required VerifyOtpUseCase verifyOtp,
    required LoginUseCase login,
    required LogoutUseCase logout,
    required ForgotPasswordUseCase forgotPassword,
    required ResetPasswordUseCase resetPassword,
  })  : _register = register,
        _verifyOtp = verifyOtp,
        _login = login,
        _logout = logout,
        _forgotPassword = forgotPassword,
        _resetPassword = resetPassword,
        super(const AuthState());

  final RegisterUseCase _register;
  final VerifyOtpUseCase _verifyOtp;
  final LoginUseCase _login;
  final LogoutUseCase _logout;
  final ForgotPasswordUseCase _forgotPassword;
  final ResetPasswordUseCase _resetPassword;

  Future<void> login({required String email, required String password, bool rememberMe = true}) async {
    emit(state.copyWith(status: AuthStatus.submitting));
    final result = await _login(LoginParams(email: email, password: password, rememberMe: rememberMe));
    result.fold(
      (failure) => emit(state.copyWith(status: AuthStatus.failure, errorMessage: failure.message)),
      (_) => emit(state.copyWith(status: AuthStatus.success)),
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String username,
    String? fullName,
  }) async {
    emit(state.copyWith(status: AuthStatus.submitting));
    final result = await _register(
      RegisterParams(email: email, password: password, username: username, fullName: fullName),
    );
    result.fold(
      (failure) => emit(state.copyWith(status: AuthStatus.failure, errorMessage: failure.message)),
      (registration) =>
          emit(state.copyWith(status: AuthStatus.awaitingOtp, pendingEmail: registration.email)),
    );
  }

  Future<void> verifyOtp(String code) async {
    final email = state.pendingEmail;
    if (email == null) return;
    emit(state.copyWith(status: AuthStatus.submitting));
    final result = await _verifyOtp(VerifyOtpParams(email: email, code: code));
    result.fold(
      (failure) => emit(state.copyWith(status: AuthStatus.failure, errorMessage: failure.message)),
      (_) => emit(state.copyWith(status: AuthStatus.success)),
    );
  }

  Future<void> forgotPassword(String email) async {
    emit(state.copyWith(status: AuthStatus.submitting));
    final result = await _forgotPassword(email);
    result.fold(
      (failure) => emit(state.copyWith(status: AuthStatus.failure, errorMessage: failure.message)),
      (_) => emit(state.copyWith(status: AuthStatus.resetEmailSent)),
    );
  }

  Future<void> resetPassword({required String token, required String newPassword}) async {
    emit(state.copyWith(status: AuthStatus.submitting));
    final result = await _resetPassword(ResetPasswordParams(token: token, newPassword: newPassword));
    result.fold(
      (failure) => emit(state.copyWith(status: AuthStatus.failure, errorMessage: failure.message)),
      (_) => emit(state.copyWith(status: AuthStatus.success)),
    );
  }

  Future<void> logout() => _logout(const NoParams());

  /// Backs out of the OTP step to the registration form (the register
  /// page's back button when mid-flow).
  void reset() => emit(const AuthState());
}
