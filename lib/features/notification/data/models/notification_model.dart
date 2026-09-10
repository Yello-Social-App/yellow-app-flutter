import '../../domain/entities/notification_entity.dart';

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required super.id,
    required super.type,
    required super.actorId,
    required super.actorUsername,
    super.actorAvatarUrl,
    super.targetId,
    required super.read,
    required super.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>? ?? const {};
    return NotificationModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'UNKNOWN',
      actorId: actor['id'] as String? ?? '',
      actorUsername: actor['username'] as String? ?? 'unknown',
      actorAvatarUrl: actor['avatarUrl'] as String?,
      targetId: json['targetId'] as String?,
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
