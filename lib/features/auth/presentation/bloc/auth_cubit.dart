import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/password_reset_usecases.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';

enum AuthStatus {
  idle,
  submitting,
  awaitingOtp,

  /// `forgotPassword()` succeeded — the code + new-password step of the
  /// reset sheet shows while this holds, so it must not be disturbed by
  /// [AuthState.isProcessing]'s own request the way [submitting] would be
  /// (see that field's doc).
  resetEmailSent,

  /// `submitPasswordReset()` finished successfully — sheet pops, no
  /// session is started (the backend revoked every refresh token), so the
  /// user signs in fresh with the new password.
  passwordResetDone,
  success,
  failure,
}

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.idle,
    this.pendingEmail,
    this.errorMessage,
    this.infoMessage,
    this.isProcessing = false,
  });

  final AuthStatus status;

  /// Set once `register()`/`forgotPassword()` succeeds — the email the
  /// OTP/reset-code step verifies against.
  final String? pendingEmail;
  final String? errorMessage;

  /// A non-error confirmation to toast — `resendOtp()`'s "we sent a new
  /// code" — kept separate from [status] because [resendOtp] fires while
  /// [status] is pinned to [AuthStatus.awaitingOtp]/[AuthStatus.resetEmailSent]
  /// to keep the right step on screen, and must not change it.
  final String? infoMessage;

  /// True while [resendOtp]/`submitPasswordReset` is in flight. Separate
  /// from [isSubmitting]/[AuthStatus.submitting] for the same reason as
  /// [infoMessage]: those two actions run *while* [status] is pinned to a
  /// specific step that flipping to [AuthStatus.submitting] would hide.
  final bool isProcessing;

  bool get isSubmitting => status == AuthStatus.submitting;

  AuthState copyWith({
    AuthStatus? status,
    String? pendingEmail,
    String? errorMessage,
    String? infoMessage,
    bool? isProcessing,
  }) {
    return AuthState(
      status: status ?? this.status,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  @override
  List<Object?> get props => [status, pendingEmail, errorMessage, infoMessage, isProcessing];
}

/// Drives every auth screen (login, register, OTP, forgot/reset password).
/// One Cubit for the whole flow because the steps are sequential and share
/// `pendingEmail` state — a fresh instance is created per screen-visit via
/// DI's `registerFactory`.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required RegisterUseCase register,
    required VerifyOtpUseCase verifyOtp,
    required ResendOtpUseCase resendOtp,
    required LoginUseCase login,
    required LogoutUseCase logout,
    required ForgotPasswordUseCase forgotPassword,
    required ResetPasswordUseCase resetPassword,
  }) : _register = register,
       _verifyOtp = verifyOtp,
       _resendOtp = resendOtp,
       _login = login,
       _logout = logout,
       _forgotPassword = forgotPassword,
       _resetPassword = resetPassword,
       super(const AuthState());

  final RegisterUseCase _register;
  final VerifyOtpUseCase _verifyOtp;
  final ResendOtpUseCase _resendOtp;
  final LoginUseCase _login;
  final LogoutUseCase _logout;
  final ForgotPasswordUseCase _forgotPassword;
  final ResetPasswordUseCase _resetPassword;

  Future<void> login({required String email, required String password, bool rememberMe = true}) async {
    emit(state.copyWith(status: AuthStatus.submitting));
    final result = await _login(LoginParams(email: email, password: password, rememberMe: rememberMe));
    // A route redirect or a back-out during submit can pop the auth screen
    // (closing this factory cubit) before this resolves.
    if (isClosed) return;
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
    // Same closed-screen race as `login()`.
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(status: AuthStatus.failure, errorMessage: failure.message)),
      (registration) => emit(state.copyWith(status: AuthStatus.awaitingOtp, pendingEmail: registration.email)),
    );
  }

  Future<void> verifyOtp(String code) async {
    final email = state.pendingEmail;
    if (email == null) return;
    emit(state.copyWith(status: AuthStatus.submitting));
    final result = await _verifyOtp(VerifyOtpParams(email: email, code: code));
    // Same closed-screen race as `login()`.
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(status: AuthStatus.failure, errorMessage: failure.message)),
      (_) => emit(state.copyWith(status: AuthStatus.success)),
    );
  }

  Future<void> forgotPassword(String email) async {
    emit(state.copyWith(status: AuthStatus.submitting));
    final result = await _forgotPassword(email);
    // Same closed-screen race as `login()`.
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(status: AuthStatus.failure, errorMessage: failure.message)),
      (_) => emit(state.copyWith(status: AuthStatus.resetEmailSent, pendingEmail: email)),
    );
  }

  /// Step 2 of the reset flow: exchanges [code] for a one-time reset token
  /// via `verifyOtp`, then immediately spends it via `resetPassword` — one
  /// screen, two backend calls, rather than a 3rd intermediate step just to
  /// show the token in between. [status] stays [AuthStatus.resetEmailSent]
  /// throughout (see [AuthState.isProcessing]'s doc) until it either fails
  /// (surfaced via [AuthState.errorMessage], same step stays on screen) or
  /// finishes (flips to [AuthStatus.passwordResetDone]).
  Future<void> submitPasswordReset({required String code, required String newPassword}) async {
    final email = state.pendingEmail;
    if (email == null || state.isProcessing) return;
    emit(state.copyWith(isProcessing: true));

    final verifyResult = await _verifyOtp(VerifyOtpParams(email: email, code: code));
    // Same closed-screen race as `login()`.
    if (isClosed) return;
    await verifyResult.fold(
      (failure) async => emit(state.copyWith(isProcessing: false, errorMessage: failure.message)),
      (resetToken) async {
        if (resetToken == null) {
          emit(state.copyWith(isProcessing: false, errorMessage: "That code didn't produce a reset token. Try again."));
          return;
        }
        final resetResult = await _resetPassword(ResetPasswordParams(token: resetToken, newPassword: newPassword));
        if (isClosed) return;
        resetResult.fold(
          (failure) => emit(state.copyWith(isProcessing: false, errorMessage: failure.message)),
          (_) => emit(state.copyWith(isProcessing: false, status: AuthStatus.passwordResetDone)),
        );
      },
    );
  }

  /// Re-sends whichever code [AuthState.pendingEmail] currently needs —
  /// the "Resend code" link on both the registration-OTP step and the
  /// reset-password code step. Surfaced via [AuthState.infoMessage]/
  /// [AuthState.errorMessage] rather than [status] (see their docs).
  Future<void> resendOtp() async {
    final email = state.pendingEmail;
    if (email == null || state.isProcessing) return;
    emit(state.copyWith(isProcessing: true));
    final result = await _resendOtp(email);
    // Same closed-screen race as `login()`.
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isProcessing: false, errorMessage: failure.message)),
      (_) => emit(state.copyWith(isProcessing: false, infoMessage: 'We sent a new code to $email.')),
    );
  }

  Future<void> logout() => _logout(const NoParams());

  /// Backs out of the OTP/reset step to the form before it (the register
  /// page's back button when mid-flow; called before opening the
  /// forgot-password sheet, so a previous attempt never leaves it stuck on
  /// a later step).
  void reset() => emit(const AuthState());
}
