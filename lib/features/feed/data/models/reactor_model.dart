import '../../domain/entities/post_entity.dart' show ReactionType;
import '../../domain/entities/reactor_entity.dart';

class ReactorModel extends ReactorEntity {
  const ReactorModel({
    required super.userId,
    required super.username,
    super.fullName,
    super.avatarUrl,
    required super.reactionType,
    required super.reactedAt,
    super.friendStatus,
  });

  factory ReactorModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    return ReactorModel(
      userId: user['id'] as String? ?? '',
      username: user['username'] as String? ?? 'unknown',
      fullName: user['fullName'] as String?,
      avatarUrl: user['avatarUrl'] as String?,
      reactionType: ReactionType.fromWire(json['type'] as String?),
      reactedAt: DateTime.parse(json['reactedAt'] as String),
      friendStatus: FriendRelationStatus.fromWire(json['friendStatus'] as String?),
    );
  }
}
