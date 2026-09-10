import '../../domain/entities/friendship_entity.dart';

class FriendshipModel extends FriendshipEntity {
  const FriendshipModel({
    required super.id,
    required super.userId,
    required super.username,
    super.avatarUrl,
    required super.status,
    required super.createdAt,
    super.respondedAt,
  });

  factory FriendshipModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    final respondedAt = json['respondedAt'] as String?;
    return FriendshipModel(
      id: json['id'] as String,
      userId: user['id'] as String? ?? '',
      username: user['username'] as String? ?? 'unknown',
      avatarUrl: user['avatarUrl'] as String?,
      status: FriendshipStatus.fromWire(json['status'] as String?),
      createdAt: DateTime.parse(json['createdAt'] as String),
      respondedAt: respondedAt == null ? null : DateTime.parse(respondedAt),
    );
  }
}
