import 'package:safe_device/safe_device.dart';

import '../utils/logger.dart';

/// Result of a full device-integrity sweep, kept as separate flags (rather
/// than a single bool) so the caller decides policy — e.g. block on
/// root/jailbreak but only *warn* on an emulator during internal QA builds.
class DeviceIntegrityReport {
  const DeviceIntegrityReport({
    required this.isRootedOrJailbroken,
    required this.isRealDevice,
    required this.isMockLocation,
    required this.isDevModeEnabled,
    required this.isUsbDebuggingEnabled,
  });

  final bool isRootedOrJailbroken;
  final bool isRealDevice;
  final bool isMockLocation;
  final bool isDevModeEnabled;
  final bool isUsbDebuggingEnabled;

  /// The single signal worth hard-blocking on for a social app handling
  /// user auth/session tokens: a compromised OS undermines every other
  /// control in `core/security` (secure storage, cert pinning, biometrics
  /// all assume the OS sandbox is intact).
  bool get shouldBlockLaunch => isRootedOrJailbroken;
}

/// OWASP Mobile **M8 — Security Misconfiguration** / device-tampering
/// checks. Wraps `safe_device` behind an interface so the app's launch
/// gate and tests don't depend on its platform channel directly.
abstract interface class RootJailbreakDetector {
  Future<DeviceIntegrityReport> check();
}

class RootJailbreakDetectorImpl implements RootJailbreakDetector {
  @override
  Future<DeviceIntegrityReport> check() async {
    try {
      final results = await Future.wait([
        SafeDevice.isJailBroken,
        SafeDevice.isRealDevice,
        SafeDevice.isMockLocation,
        SafeDevice.isDevelopmentModeEnable,
        SafeDevice.isUsbDebuggingEnabled,
      ]);
      return DeviceIntegrityReport(
        isRootedOrJailbroken: results[0],
        isRealDevice: results[1],
        isMockLocation: results[2],
        isDevModeEnabled: results[3],
        isUsbDebuggingEnabled: results[4],
      );
    } catch (e) {
      // Fail OPEN on a detection error (channel missing on an unsupported
      // platform, plugin bug) rather than locking every user out of the
      // app because one signal couldn't be read — this check is
      // defense-in-depth, not the app's only security boundary.
      appLogger.w('Device integrity check failed, defaulting to safe: $e');
      return const DeviceIntegrityReport(
        isRootedOrJailbroken: false,
        isRealDevice: true,
        isMockLocation: false,
        isDevModeEnabled: false,
        isUsbDebuggingEnabled: false,
      );
    }
  }
}
