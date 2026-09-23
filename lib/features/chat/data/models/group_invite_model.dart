import '../../domain/entities/group_invite_entity.dart';
import 'message_model.dart';

/// Wire → domain for `POST /ws/conversations/{id}/invites`'s
/// `{ invite, message }` answer. Bare JSON, like every `yello-chat` route.
abstract final class GroupInviteMapper {
  static GroupInviteEntity fromJson(Map<String, dynamic> json) => GroupInviteEntity(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String? ?? '',
        inviterId: json['inviterId'] as String? ?? '',
        inviteeId: json['inviteeId'] as String? ?? '',
        status: GroupInviteStatus.fromWire(json['status'] as String?),
        createdAt: (json['createdAt'] is String ? DateTime.tryParse(json['createdAt'] as String) : null) ?? DateTime.now(),
      );

  static GroupInviteResult resultFromJson(Map<String, dynamic> json, {String? viewerId}) => GroupInviteResult(
        invite: fromJson(json['invite'] as Map<String, dynamic>),
        message: MessageMapper.fromJson(json['message'] as Map<String, dynamic>, viewerId: viewerId),
      );
}
