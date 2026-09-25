import 'package:flutter/services.dart';

import '../../../../core/error/exceptions.dart';

/// The Android half of the sideload updater: where to put the APK, whether
/// the OS will let Yello install one, and handing the finished file to the
/// system package installer.
///
/// A platform channel rather than a package: all three calls are a handful
/// of lines of Kotlin (`MainActivity.kt`), and the pub.dev options in this
/// space each bundle their own download stack, which this app already has
/// in `dio`.
///
/// iOS has no equivalent and never will — the App Store is the only way to
/// install an iOS build — so every call throws there and the update card is
/// gated on `Platform.isAndroid` before it is ever built.
abstract interface class ApkInstaller {
  /// App-private directory the APK is downloaded into. Private storage, so
  /// no storage permission is involved; the FileProvider in the manifest is
  /// what lets the installer read back out of it.
  Future<String> updateDirectory();

  /// Whether "Install unknown apps" is on for Yello. Always true below
  /// Android 8, where the permission is granted at install time.
  Future<bool> canInstallPackages();

  /// Opens the OS screen that grants the above. Returns once the screen is
  /// launched, not once the user decides — the result is read by calling
  /// [canInstallPackages] again when the app resumes.
  Future<void> openInstallPermissionSettings();

  /// Hands [filePath] to the package installer. False means the permission
  /// above is still missing and nothing was launched.
  Future<bool> install(String filePath);
}

class ApkInstallerImpl implements ApkInstaller {
  ApkInstallerImpl([MethodChannel? channel]) : _channel = channel ?? const MethodChannel('yello/installer');

  final MethodChannel _channel;

  @override
  Future<String> updateDirectory() async {
    final path = await _invoke<String>('updateDirectory');
    if (path == null || path.isEmpty) throw const CacheException('Could not find anywhere to save the download.');
    return path;
  }

  @override
  Future<bool> canInstallPackages() async => await _invoke<bool>('canInstallPackages') ?? false;

  @override
  Future<void> openInstallPermissionSettings() => _invoke<void>('openInstallPermissionSettings');

  @override
  Future<bool> install(String filePath) async =>
      await _invoke<bool>('install', {'filePath': filePath}) ?? false;

  /// Channel errors become [AppException]s so the repository above can treat
  /// them like every other failure instead of special-casing platform
  /// plumbing. A missing implementation (iOS, or a widget test with no
  /// engine) is the same answer as a refusal: this device cannot do it.
  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      throw const CacheException('Installing an update is only supported on Android.');
    } on PlatformException catch (e) {
      throw CacheException(e.message ?? 'The installer could not be started.');
    }
  }
}
