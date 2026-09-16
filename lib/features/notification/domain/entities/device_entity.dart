import 'package:equatable/equatable.dart';

/// A row from `PUT /notifications/v1/devices` — this device's own push
/// registration. The token itself is never returned by the backend (by
/// design — kept out of every response, log and cache), so it isn't a
/// field here; the caller already has it and identifies the device by
/// [id] instead.
class DeviceEntity extends Equatable {
  const DeviceEntity({
    required this.id,
    required this.platform,
    this.appVersion,
    this.locale,
    required this.lastSeenAt,
    required this.createdAt,
  });

  final String id;
  final String platform;
  final String? appVersion;
  final String? locale;
  final DateTime lastSeenAt;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, lastSeenAt];
}
