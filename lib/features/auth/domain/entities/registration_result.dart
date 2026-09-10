import 'package:equatable/equatable.dart';

/// The backend's `RegisterResponse` — registering does NOT log the user in
/// directly; it kicks off the OTP flow (`POST /auth/verify-otp` next).
class RegistrationResult extends Equatable {
  const RegistrationResult({required this.userId, required this.email, required this.message});

  final String userId;
  final String email;
  final String message;

  @override
  List<Object?> get props => [userId, email];
}
