import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../domain/entities/app_build_info.dart';

/// Reads the installed build off the device. Local-only by necessity — the
/// API has no version resource to ask (`docs/BACKEND.md`), which is also why
/// there is no "check for updates" call anywhere in this feature.
abstract interface class AppInfoLocalDataSource {
  Future<AppBuildInfo> getBuildInfo();
}

class AppInfoLocalDataSourceImpl implements AppInfoLocalDataSource {
  AppInfoLocalDataSourceImpl([DeviceInfoPlugin? deviceInfo]) : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;

  @override
  Future<AppBuildInfo> getBuildInfo() async {
    final package = await PackageInfo.fromPlatform();
    final (osVersion, deviceModel) = await _device();
    return AppBuildInfo(
      appName: package.appName,
      version: package.version,
      buildNumber: package.buildNumber,
      packageName: package.packageName,
      platform: Platform.isAndroid
          ? 'Android'
          : Platform.isIOS
          ? 'iOS'
          : Platform.operatingSystem,
      osVersion: osVersion,
      deviceModel: deviceModel,
    );
  }

  /// Swallows its own failures: the OS and model rows are context, while
  /// `PackageInfo` above is the point of the screen. A `device_info_plus`
  /// channel that isn't there must not turn the whole screen into an error.
  Future<(String, String)> _device() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return (
          'Android ${info.version.release} (SDK ${info.version.sdkInt})',
          '${_titleCase(info.manufacturer)} ${info.model}'.trim(),
        );
      }
      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return ('${info.systemName} ${info.systemVersion}', info.utsname.machine);
      }
    } catch (_) {
      // Fall through to the empty pair.
    }
    return ('', '');
  }

  /// `google` → `Google`. Android reports the manufacturer lowercase, which
  /// reads as a typo next to the model's own casing.
  static String _titleCase(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}
