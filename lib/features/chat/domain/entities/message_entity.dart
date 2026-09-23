import 'package:equatable/equatable.dart';

import 'attachment_entity.dart';
import 'group_invite_entity.dart';

/// Where an outgoing message is in its lifecycle. Incoming messages are
/// always [sent]; [sending] and [failed] only ever describe the optimistic
/// copy this client created before the server acknowledged it.
enum MessageDeliveryStatus { sending, sent, failed }

/// The quoted message a reply points at (`ReplyPreview`) — a trimmed copy,
/// not a reference: the transcript can render the quote without the original
/// being loaded (it may be pages back, or gone).
class ReplyPreviewEntity extends Equatable {
  const ReplyPreviewEntity({
    required this.id,
    required this.senderId,
    required this.body,
    this.hasAttachments = false,
    this.deleted = false,
  });

  final String id;
  final String senderId;

  /// First 200 characters; empty when the original was unsent or file-only.
  final String body;
  final bool hasAttachments;

  /// The quoted message has since been deleted — render "Message deleted"
  /// in the quote rather than an empty box.
  final bool deleted;

  ReplyPreviewEntity copyWith({bool? deleted}) => ReplyPreviewEntity(
        id: id,
        senderId: senderId,
        body: deleted == true ? '' : body,
        hasAttachments: hasAttachments,
        deleted: deleted ?? this.deleted,
      );

  @override
  List<Object?> get props => [id, senderId, body, hasAttachments, deleted];
}

/// One emoji's tally on a message (`Reaction`). A user appears at most once
/// across a message's whole reaction list — reacting again replaces, never
/// stacks.
class ReactionEntity extends Equatable {
  const ReactionEntity({
    required this.emoji,
    required this.count,
    required this.userIds,
    required this.reactedByMe,
  });

  final String emoji;
  final int count;
  final List<String> userIds;

  /// Derived at mapping time from the viewer's id — the wire has no "you".
  final bool reactedByMe;

  @override
  List<Object?> get props => [emoji, count, userIds, reactedByMe];
}

/// A message as `yello-chat` models it.
///
/// [clientId] is the idempotency key *this* client generates before sending:
/// the server echoes it back on the created message, which is how an
/// optimistic bubble is matched to its confirmed version instead of being
/// rendered twice. It is also what makes a retry safe.
///
/// [body] is `""` for three different things — an attachment-only message,
/// an invite card, and a deleted one — so nothing may render on the text
/// alone: check [isDeleted], [groupInvite] and [attachments] first (in that
/// order — a tombstone has none of the others).
class MessageEntity extends Equatable {
  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.clientId,
    required this.body,
    required this.createdAt,
    required this.fromMe,
    this.status = MessageDeliveryStatus.sent,
    this.replyTo,
    this.attachments = const [],
    this.reactions = const [],
    this.groupInvite,
    this.editedAt,
    this.deletedAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String clientId;
  final String body;
  final DateTime createdAt;

  /// Derived at mapping time by comparing [senderId] with the signed-in
  /// user's id — the wire format has no such field.
  final bool fromMe;

  final MessageDeliveryStatus status;

  final ReplyPreviewEntity? replyTo;

  /// Empty when there are none — and after a delete, which also drops the
  /// files server-side.
  final List<AttachmentEntity> attachments;
  final List<ReactionEntity> reactions;

  /// Set on an invite card; the message then has no text of its own.
  final GroupInviteCardEntity? groupInvite;

  /// Set once the sender has edited the text — show an "edited" label.
  final DateTime? editedAt;

  /// Set on a tombstone: the text is wiped, files and reactions gone, but
  /// the row stays in history. Render "Message deleted".
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null;
  bool get isInviteCard => groupInvite != null;
  bool get hasAttachments => attachments.isNotEmpty;
  bool get hasText => body.isNotEmpty;

  /// The viewer's own reaction, if any — reacting again replaces it, so
  /// there is at most one.
  ReactionEntity? get myReaction {
    for (final r in reactions) {
      if (r.reactedByMe) return r;
    }
    return null;
  }

  /// What may be edited: the sender's own live text message. Attachments and
  /// the reply target are fixed at send time, and a card has no text.
  bool get canEdit => fromMe && !isDeleted && !isInviteCard && status == MessageDeliveryStatus.sent;
  bool get canDelete => fromMe && !isDeleted && status == MessageDeliveryStatus.sent;

  /// Anything sent can be reacted to, replied to and quoted — except a
  /// tombstone, which is 404 for every action.
  bool get canInteract => !isDeleted && status == MessageDeliveryStatus.sent;

  // Names the existing chat UI reads. Kept as getters so the presentation
  // layer did not have to change when this entity moved to the real API.
  String get text => body;
  DateTime get sentAt => createdAt;

  /// The trimmed copy of this message a reply to it carries — the same shape
  /// the server builds for `replyTo`, so an optimistic reply renders exactly
  /// as its confirmed version will.
  ReplyPreviewEntity toReplyPreview() => ReplyPreviewEntity(
        id: id,
        senderId: senderId,
        body: isDeleted ? '' : (body.length > 200 ? body.substring(0, 200) : body),
        hasAttachments: hasAttachments,
        deleted: isDeleted,
      );

  /// The tombstone the server leaves behind after a delete: empty body, no
  /// files, no reactions, [deletedAt] set. Applied locally on a successful
  /// `DELETE` (or a `message.deleted` frame) so the bubble flips without a
  /// refetch.
  MessageEntity asDeleted(DateTime at) => MessageEntity(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        clientId: clientId,
        body: '',
        createdAt: createdAt,
        fromMe: fromMe,
        status: status,
        replyTo: replyTo,
        attachments: const [],
        reactions: const [],
        groupInvite: groupInvite,
        editedAt: editedAt,
        deletedAt: at,
      );

  MessageEntity copyWith({
    String? id,
    MessageDeliveryStatus? status,
    DateTime? createdAt,
    String? body,
    ReplyPreviewEntity? replyTo,
    List<AttachmentEntity>? attachments,
    List<ReactionEntity>? reactions,
    GroupInviteCardEntity? groupInvite,
    DateTime? editedAt,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      clientId: clientId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      fromMe: fromMe,
      status: status ?? this.status,
      replyTo: replyTo ?? this.replyTo,
      attachments: attachments ?? this.attachments,
      reactions: reactions ?? this.reactions,
      groupInvite: groupInvite ?? this.groupInvite,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        senderId,
        clientId,
        body,
        createdAt,
        fromMe,
        status,
        replyTo,
        attachments,
        reactions,
        groupInvite,
        editedAt,
        deletedAt,
      ];
}
