import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

class VerifyOtpParams extends Equatable {
  const VerifyOtpParams({required this.email, required this.code});
  final String email;
  final String code;

  @override
  List<Object?> get props => [email, code];
}

class VerifyOtpUseCase implements UseCase<void, VerifyOtpParams> {
  VerifyOtpUseCase(this._repository);

  final AuthRepository _repository;

  static final _codeRe = RegExp(r'^[0-9]{6}$');

  @override
  Future<Either<Failure, void>> call(VerifyOtpParams params) {
    if (!_codeRe.hasMatch(params.code.trim())) {
      return Future.value(const Left(ValidationFailure('Enter the 6-digit code.')));
    }
    return _repository.verifyOtp(email: params.email.trim(), code: params.code.trim());
  }
}
