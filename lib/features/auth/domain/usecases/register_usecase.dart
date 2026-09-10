import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/validators.dart';
import '../entities/registration_result.dart';
import '../repositories/auth_repository.dart';

class RegisterParams extends Equatable {
  const RegisterParams({
    required this.email,
    required this.password,
    required this.username,
    this.fullName,
  });

  final String email;
  final String password;
  final String username;
  final String? fullName;

  @override
  List<Object?> get props => [email, password, username, fullName];
}

class RegisterUseCase implements UseCase<RegistrationResult, RegisterParams> {
  RegisterUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, RegistrationResult>> call(RegisterParams params) {
    final emailError = Validators.email(params.email);
    if (emailError != null) return Future.value(Left(ValidationFailure(emailError)));

    final passwordError = Validators.password(params.password);
    if (passwordError != null) return Future.value(Left(ValidationFailure(passwordError)));

    final handleError = Validators.handle(params.username);
    if (handleError != null) return Future.value(Left(ValidationFailure(handleError)));

    return _repository.register(
      email: params.email.trim(),
      password: params.password,
      username: params.username.trim(),
      fullName: params.fullName == null || params.fullName!.trim().isEmpty
          ? null
          : InputSanitizer.sanitizeText(params.fullName!, maxLength: 100),
    );
  }
}
