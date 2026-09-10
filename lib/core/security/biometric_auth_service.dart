import 'package:local_auth/local_auth.dart';

import '../utils/logger.dart';

enum BiometricAuthResult { success, failed, notAvailable, notEnrolled, error }

/// Optional step-up authentication (unlocking the app, confirming a
/// sensitive action) via the platform's biometric/PIN prompt. Deliberately
/// NOT part of the primary login flow — it gates access to an *already
/// established* session held in [SecureStorageService], it never itself
/// produces credentials.
abstract interface class BiometricAuthService {
  Future<bool> isDeviceSupported();
  Future<List<BiometricType>> availableBiometrics();
  Future<BiometricAuthResult> authenticate({required String reason});
}

class BiometricAuthServiceImpl implements BiometricAuthService {
  BiometricAuthServiceImpl([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (e) {
      appLogger.w('Biometric support check failed: $e');
      return false;
    }
  }

  @override
  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      appLogger.w('Could not list available biometrics: $e');
      return const [];
    }
  }

  @override
  Future<BiometricAuthResult> authenticate({required String reason}) async {
    try {
      if (!await isDeviceSupported()) return BiometricAuthResult.notAvailable;
      final biometrics = await availableBiometrics();
      if (biometrics.isEmpty) return BiometricAuthResult.notEnrolled;

      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricAuthResult.success : BiometricAuthResult.failed;
    } catch (e) {
      appLogger.w('Biometric authentication error: $e');
      return BiometricAuthResult.error;
    }
  }
}
