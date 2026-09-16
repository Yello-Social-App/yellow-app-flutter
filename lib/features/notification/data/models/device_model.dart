import '../../domain/entities/device_entity.dart';

class DeviceModel extends DeviceEntity {
  const DeviceModel({
    required super.id,
    required super.platform,
    super.appVersion,
    super.locale,
    required super.lastSeenAt,
    required super.createdAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
    id: json['id'] as String,
    platform: json['platform'] as String,
    appVersion: json['appVersion'] as String?,
    locale: json['locale'] as String?,
    lastSeenAt: DateTime.parse(json['lastSeenAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
