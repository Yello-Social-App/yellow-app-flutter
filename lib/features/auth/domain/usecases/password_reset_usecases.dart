import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/validators.dart';
import '../repositories/auth_repository.dart';

class ForgotPasswordUseCase implements UseCase<void, String> {
  ForgotPasswordUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, void>> call(String email) {
    final error = Validators.email(email);
    if (error != null) return Future.value(Left(ValidationFailure(error)));
    return _repository.forgotPassword(email.trim());
  }
}

class ResetPasswordParams extends Equatable {
  const ResetPasswordParams({required this.token, required this.newPassword});
  final String token;
  final String newPassword;

  @override
  List<Object?> get props => [token, newPassword];
}

class ResetPasswordUseCase implements UseCase<void, ResetPasswordParams> {
  ResetPasswordUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, void>> call(ResetPasswordParams params) {
    final error = Validators.password(params.newPassword);
    if (error != null) return Future.value(Left(ValidationFailure(error)));
    return _repository.resetPassword(token: params.token, newPassword: params.newPassword);
  }
}
