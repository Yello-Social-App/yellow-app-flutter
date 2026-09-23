import 'package:equatable/equatable.dart';

import '../../../../core/utils/presigned_url.dart';
import 'message_entity.dart';

enum GroupInviteStatus {
  pending,
  accepted,
  declined;

  static GroupInviteStatus fromWire(String? value) => switch (value) {
        'ACCEPTED' => GroupInviteStatus.accepted,
        'DECLINED' => GroupInviteStatus.declined,
        _ => GroupInviteStatus.pending,
      };
}

/// The card a group invite renders as, embedded on a DM message
/// (`Message.groupInvite`). Only the invitee may answer it, and only while
/// [status] is still pending — [canRespond] is that rule in one place.
///
/// [photoUrl] is presigned like an attachment's and is left out of [props]
/// for the same reason (see `AttachmentEntity`).
class GroupInviteCardEntity extends Equatable {
  const GroupInviteCardEntity({
    required this.id,
    required this.conversationId,
    required this.inviterId,
    required this.inviteeId,
    required this.status,
    this.title,
    required this.memberCount,
    this.photoUrl,
    this.photoUrlExpiresAt,
    required this.forMe,
  });

  /// The invite id — what `POST /ws/invites/{id}/accept|decline` takes.
  final String id;

  /// The group being joined.
  final String conversationId;
  final String inviterId;
  final String inviteeId;
  final GroupInviteStatus status;

  /// The group's current name; null when it has none.
  final String? title;
  final int memberCount;
  final String? photoUrl;
  final DateTime? photoUrlExpiresAt;

  /// Derived at mapping time — `inviteeId == viewer` — the wire carries no
  /// notion of "you". False when the viewer is unknown, which hides the
  /// Join/Decline buttons rather than offering someone else's invite.
  final bool forMe;

  bool get isPending => status == GroupInviteStatus.pending;
  bool get canRespond => forMe && isPending;

  /// See `ConversationEntity.avatarCacheKey` — same presigned-URL reasoning.
  String? get photoCacheKey => photoUrl == null || photoUrl!.isEmpty ? null : presignedObjectKey(photoUrl!);

  String get displayTitle {
    final t = title?.trim();
    return (t != null && t.isNotEmpty) ? t : 'Group';
  }

  GroupInviteCardEntity copyWith({GroupInviteStatus? status, int? memberCount}) => GroupInviteCardEntity(
        id: id,
        conversationId: conversationId,
        inviterId: inviterId,
        inviteeId: inviteeId,
        status: status ?? this.status,
        title: title,
        memberCount: memberCount ?? this.memberCount,
        photoUrl: photoUrl,
        photoUrlExpiresAt: photoUrlExpiresAt,
        forMe: forMe,
      );

  @override
  List<Object?> get props => [id, conversationId, inviterId, inviteeId, status, title, memberCount, forMe];
}

/// The invite row itself (`GroupInvite`), as `POST /ws/conversations/{id}/
/// invites` returns it beside the card message.
class GroupInviteEntity extends Equatable {
  const GroupInviteEntity({
    required this.id,
    required this.conversationId,
    required this.inviterId,
    required this.inviteeId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String inviterId;
  final String inviteeId;
  final GroupInviteStatus status;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, conversationId, inviterId, inviteeId, status, createdAt];
}

/// What sending an invite hands back: the invite, and the card message the
/// service dropped into the inviter's DM with the invitee. Re-inviting the
/// same person returns the same pending pair — no duplicate card.
class GroupInviteResult extends Equatable {
  const GroupInviteResult({required this.invite, required this.message});

  final GroupInviteEntity invite;
  final MessageEntity message;

  @override
  List<Object?> get props => [invite, message];
}
