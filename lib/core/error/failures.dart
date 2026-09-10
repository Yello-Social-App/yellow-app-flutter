import 'package:equatable/equatable.dart';

/// Domain-facing error type. Repositories catch [AppException]s from the
/// data layer and map them to one of these so use cases / Cubits never
/// depend on Dio, platform channels, or any other data-layer detail
/// (Dependency Inversion between layers).
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong on our end.']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'That took too long — try again.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Could not read local data.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Please sign in again.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Root/jailbreak or other device-integrity gate tripped (see
/// `core/security/root_jailbreak_detector.dart`).
class SecurityFailure extends Failure {
  const SecurityFailure([super.message = 'This device failed a security check.']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Unexpected error.']);
}
