import 'package:equatable/equatable.dart';

/// A build published to the update channel, as `latest.json` describes it.
///
/// Yello ships as a sideloaded APK, not through a store, so "is there a
/// newer build?" is answered by a small manifest the release publishes
/// alongside the APK — not by the API, which still has no version resource
/// (`docs/BACKEND.md`). See ADR-029.
///
/// [buildNumber] is the comparison key, never [version]: it is the Android
/// `versionCode`, the one number the platform itself guarantees increases
/// between installable builds. A semver string can be re-cut, re-ordered or
/// typo'd; the build number cannot go backwards without the install failing
/// anyway.
class AppUpdate extends Equatable {
  const AppUpdate({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    this.notes = '',
    this.sizeBytes = 0,
  });

  /// Marketing version of the published build — `0.4.0`.
  final String version;

  /// The published build's `versionCode`.
  final int buildNumber;

  /// Direct download for the APK. Must be https: the installer hands the
  /// downloaded file to the OS package installer, so a plaintext hop is a
  /// code-execution hole, not a privacy one.
  final String apkUrl;

  /// What changed, shown under the version. Optional — an empty release
  /// note shows the version alone rather than a blank paragraph.
  final String notes;

  /// Download size, for the "Download (58 MB)" label. 0 means the manifest
  /// didn't say, and the label drops the size instead of showing `0 MB`.
  final int sizeBytes;

  /// True when this manifest describes a build newer than [installedBuild].
  ///
  /// Equal build numbers are *not* an update: re-installing the build you
  /// already run is the one case where the OS shows a confusing "app not
  /// installed" failure rather than a no-op.
  bool isNewerThan(String installedBuild) {
    final current = int.tryParse(installedBuild.trim());
    // An unreadable installed build number is treated as "no update":
    // offering a download we cannot justify is worse than staying quiet.
    if (current == null) return false;
    return buildNumber > current;
  }

  /// `58.4 MB`, or an empty string when the manifest gave no size.
  String get sizeLabel {
    if (sizeBytes <= 0) return '';
    final megabytes = sizeBytes / (1024 * 1024);
    return '${megabytes.toStringAsFixed(1)} MB';
  }

  @override
  List<Object?> get props => [version, buildNumber, apkUrl, notes, sizeBytes];
}
