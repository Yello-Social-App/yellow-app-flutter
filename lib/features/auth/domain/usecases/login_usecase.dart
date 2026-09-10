import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/validators.dart';
import '../repositories/auth_repository.dart';

class LoginParams extends Equatable {
  const LoginParams({required this.email, required this.password, this.rememberMe = true});
  final String email;
  final String password;

  /// See `AuthRepository.login`/`SessionManager.startSession` for what this
  /// actually controls (whether a future cold start can resume the session).
  final bool rememberMe;

  @override
  List<Object?> get props => [email, password, rememberMe];
}

class LoginUseCase implements UseCase<void, LoginParams> {
  LoginUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, void>> call(LoginParams params) {
    final emailError = Validators.email(params.email);
    if (emailError != null) return Future.value(Left(ValidationFailure(emailError)));
    if (params.password.isEmpty) {
      return Future.value(const Left(ValidationFailure('Enter your password.')));
    }
    return _repository.login(
      email: params.email.trim(),
      password: params.password,
      rememberMe: params.rememberMe,
    );
  }
}
