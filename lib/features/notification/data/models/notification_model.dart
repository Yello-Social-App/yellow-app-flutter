import '../../domain/entities/notification_entity.dart';

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required super.id,
    required super.type,
    required super.title,
    required super.body,
    required super.data,
    super.actorId,
    required super.aggregateCount,
    required super.read,
    super.readAt,
    required super.createdAt,
    required super.updatedAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] as Map<String, dynamic>? ?? const {};
    final createdAt = DateTime.parse(json['createdAt'] as String);
    return NotificationModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'UNKNOWN',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      // The FCM data map is string-valued only, but parse defensively in
      // case a future field ever comes back as a number/bool.
      data: rawData.map((key, value) => MapEntry(key, value.toString())),
      actorId: json['actorId'] as String?,
      aggregateCount: (json['aggregateCount'] as num?)?.toInt() ?? 1,
      read: json['read'] as bool? ?? (json['readAt'] != null),
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt'] as String) : null,
      createdAt: createdAt,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : createdAt,
    );
  }
}
