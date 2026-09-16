import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/validators.dart';
import '../repositories/auth_repository.dart';

class VerifyOtpParams extends Equatable {
  const VerifyOtpParams({required this.email, required this.code});
  final String email;
  final String code;

  @override
  List<Object?> get props => [email, code];
}

/// Returns null for a `REGISTER`-purpose code (session already started —
/// see `AuthRepository.verifyOtp`); returns the reset token for a
/// `RESET_PASSWORD`-purpose one, to hand to `ResetPasswordUseCase`.
class VerifyOtpUseCase implements UseCase<String?, VerifyOtpParams> {
  VerifyOtpUseCase(this._repository);

  final AuthRepository _repository;

  static final _codeRe = RegExp(r'^[0-9]{6}$');

  @override
  Future<Either<Failure, String?>> call(VerifyOtpParams params) {
    if (!_codeRe.hasMatch(params.code.trim())) {
      return Future.value(const Left(ValidationFailure('Enter the 6-digit code.')));
    }
    return _repository.verifyOtp(email: params.email.trim(), code: params.code.trim());
  }
}

class ResendOtpUseCase implements UseCase<void, String> {
  ResendOtpUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, void>> call(String email) {
    final error = Validators.email(email);
    if (error != null) return Future.value(Left(ValidationFailure(error)));
    return _repository.resendOtp(email.trim());
  }
}
