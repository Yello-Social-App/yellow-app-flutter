import 'package:equatable/equatable.dart';

/// The build of Yello installed on this device, as the App version screen
/// reports it.
///
/// Read from the platform (`package_info_plus` / `device_info_plus`), never
/// from the API: the backend serves no version resource, so there is nothing
/// to compare this against and no "an update is available" to show. See
/// `docs/BACKEND.md`.
///
/// [osVersion] and [deviceModel] are best-effort — a device read that throws
/// (a widget test has no platform channel) leaves them empty rather than
/// costing the screen the version rows people actually came for. The page
/// omits an empty row.
class AppBuildInfo extends Equatable {
  const AppBuildInfo({
    required this.appName,
    required this.version,
    required this.buildNumber,
    required this.packageName,
    required this.platform,
    this.osVersion = '',
    this.deviceModel = '',
  });

  /// The launcher name — `Yello`, as the store shows it.
  final String appName;

  /// Marketing version, `pubspec.yaml`'s `version:` before the `+`.
  final String version;

  /// The part after the `+`: Android `versionCode`, iOS `CFBundleVersion`.
  final String buildNumber;

  /// Android `applicationId` / iOS bundle id.
  final String packageName;

  /// `Android` or `iOS`.
  final String platform;

  /// `Android 15 (SDK 35)` / `iOS 18.2`. Empty when unreadable.
  final String osVersion;

  /// `Google Pixel 7` / `iPhone15,2`. Empty when unreadable.
  final String deviceModel;

  /// `1.0.0 (1)` — the form stores and crash reports use.
  String get versionLabel => buildNumber.isEmpty ? version : '$version ($buildNumber)';

  @override
  List<Object?> get props => [appName, version, buildNumber, packageName, platform, osVersion, deviceModel];
}
