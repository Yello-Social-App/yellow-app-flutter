import '../../domain/entities/notification_preferences_entity.dart';

class NotificationPreferencesModel extends NotificationPreferencesEntity {
  const NotificationPreferencesModel({required super.pushEnabled, required super.mutedTypes});

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) => NotificationPreferencesModel(
    pushEnabled: json['pushEnabled'] as bool? ?? true,
    // The server returns this deduplicated and alphabetically sorted, not
    // in whatever order a PUT sent — never assume it echoes the request.
    mutedTypes: (json['mutedTypes'] as List<dynamic>?)?.cast<String>() ?? const [],
  );
}
