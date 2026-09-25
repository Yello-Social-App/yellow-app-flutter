import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/attachment_entity.dart';
import '../entities/conversation_entity.dart';
import '../entities/group_invite_entity.dart';
import '../entities/message_entity.dart';
import '../entities/participant_entity.dart';

/// A cursor page of conversations. `nextCursor` is opaque — pass it back
/// verbatim; when it is null there is nothing older to fetch.
class ConversationsPage {
  const ConversationsPage({required this.conversations, this.nextCursor});

  final List<ConversationEntity> conversations;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

/// A cursor page of messages, always oldest → newest.
class MessagesPage {
  const MessagesPage({required this.messages, this.nextCursor});

  final List<MessageEntity> messages;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

abstract interface class ChatRepository {
  Future<Either<Failure, ConversationsPage>> getConversations({String? cursor});
  Future<Either<Failure, ConversationEntity>> getConversation(String conversationId);

  /// Opens (or returns the existing) DIRECT conversation with [peerId] —
  /// the entry point from a profile's "Message" button.
  Future<Either<Failure, ConversationEntity>> startDirect(String peerId);

  Future<Either<Failure, ConversationEntity>> startGroup({
    required String title,
    required List<String> memberIds,
  });

  Future<Either<Failure, MessagesPage>> getMessages(String conversationId, {String? cursor});

  /// [clientId] is the caller's idempotency key — generate it once per
  /// composed message and reuse it on retry so a timeout cannot duplicate
  /// the message. See [MessageEntity.clientId].
  ///
  /// [body] may be empty only when [attachmentIds] is not; [replyToMessageId]
  /// must be a live message of the same conversation (else `404`).
  Future<Either<Failure, MessageEntity>> sendMessage({
    required String conversationId,
    required String body,
    required String clientId,
    String? replyToMessageId,
    List<String> attachmentIds = const [],
  });

  /// Text only — the reply target and attachments are fixed at send time.
  /// Sending the same text again is a server-side no-op (no `editedAt`).
  Future<Either<Failure, MessageEntity>> editMessage({
    required String conversationId,
    required String messageId,
    required String body,
  });

  /// Unsend for everyone: the server keeps a tombstone (`deletedAt` set,
  /// empty body, files and reactions removed).
  Future<Either<Failure, Unit>> deleteMessage({required String conversationId, required String messageId});

  /// Sets the viewer's reaction — exactly one emoji, replacing any previous
  /// one. Returns the message's *full* reaction list; replace, don't merge.
  Future<Either<Failure, List<ReactionEntity>>> setReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  });

  /// Idempotent — removing a reaction that isn't there still answers 200.
  Future<Either<Failure, List<ReactionEntity>>> removeReaction({
    required String conversationId,
    required String messageId,
  });

  /// Step one of sending a file: upload it, get an [AttachmentEntity] back
  /// in a *pending* state visible to the uploader only, then pass its id in
  /// `sendMessage(attachmentIds:)`. One file per call, up to 10 MiB.
  Future<Either<Failure, AttachmentEntity>> uploadAttachment({required String conversationId, required File file});

  /// Step one of sending a voice note, against the route that transcodes it
  /// and measures its duration and waveform. Otherwise identical to
  /// [uploadAttachment]: the attachment comes back pending, and sending it
  /// is `sendMessage(attachmentIds: [id])`.
  Future<Either<Failure, AttachmentEntity>> uploadVoiceAttachment({
    required String conversationId,
    required File file,
  });

  /// A fresh presigned URL once the one on the message has expired.
  Future<Either<Failure, AttachmentEntity>> getAttachment(String attachmentId);

  Future<Either<Failure, Unit>> markRead({
    required String conversationId,
    required String messageId,
  });

  // --- groups (every one of these is 400 on a DM) ---

  Future<Either<Failure, ConversationEntity>> renameGroup({required String conversationId, required String title});
  Future<Either<Failure, ConversationEntity>> setGroupPhoto({required String conversationId, required File file});
  Future<Either<Failure, ConversationEntity>> removeGroupPhoto(String conversationId);

  /// Skips people already in the group. Answers with the new full member
  /// list, hydrated.
  Future<Either<Failure, List<ParticipantEntity>>> addGroupMembers({
    required String conversationId,
    required List<String> userIds,
  });

  /// Not for yourself — that is [leaveGroup] (the server answers 400).
  Future<Either<Failure, Unit>> removeGroupMember({required String conversationId, required String userId});

  Future<Either<Failure, List<ParticipantEntity>>> changeMemberRole({
    required String conversationId,
    required String userId,
    required ParticipantRole role,
  });

  Future<Either<Failure, Unit>> leaveGroup(String conversationId);

  // --- invite cards ---

  /// Drops an invite card into the viewer's DM with [userId] (opening that
  /// DM if needed). Re-inviting returns the same pending invite.
  Future<Either<Failure, GroupInviteResult>> inviteToGroup({required String conversationId, required String userId});

  /// Joins the group; answers with it, hydrated. Re-checks membership,
  /// capacity and blocks at that moment (`409` / `400` / `403`).
  Future<Either<Failure, ConversationEntity>> acceptInvite(String inviteId);
  Future<Either<Failure, Unit>> declineInvite(String inviteId);

  /// Live events for one conversation, over `yello-chat`'s WebSocket.
  ///
  /// Subscribing is what opens the socket (and the last unsubscribe closes
  /// it). Frames for other conversations are filtered out; frames without a
  /// conversation (`pong`, `presence`) are dropped. The stream also carries
  /// [LiveDeliveryChanged] so the screen knows when it can ease its
  /// history poll. See [ChatEvent] and `ChatFrameDecoder`.
  Stream<ChatEvent> watchEvents(String conversationId);

  /// Tells the other participants the viewer started or stopped typing.
  /// Socket-only and best-effort: a no-op when the socket is not live,
  /// never an error.
  void sendTyping({required String conversationId, required bool isTyping});
}

/// One server → client frame, decoded. The cubit switches over these; an
/// unrecognised frame never reaches it (`ChatFrameDecoder` drops it), which
/// is the documented behaviour — unknown events are safe to ignore.
sealed class ChatEvent {
  const ChatEvent();
}

/// `typing` — [userId] started ([isTyping]) or stopped typing. The viewer's
/// own echo, if the server sends one, is dropped by the cubit.
class TypingChanged extends ChatEvent {
  const TypingChanged({required this.userId, required this.isTyping});
  final String userId;
  final bool isTyping;
}

/// The socket came up (`auth.ok`) or went down. Not a server frame — the
/// transport reports it so the screen can poll less while delivery is live.
class LiveDeliveryChanged extends ChatEvent {
  const LiveDeliveryChanged(this.isLive);
  final bool isLive;
}

/// `message.new` — someone sent a message.
class MessageArrived extends ChatEvent {
  const MessageArrived(this.message);
  final MessageEntity message;
}

/// `message.updated` — replace the message by id (an edit).
class MessageUpdated extends ChatEvent {
  const MessageUpdated(this.message);
  final MessageEntity message;
}

/// `message.deleted` — flip the message to a tombstone and mark any reply
/// quoting it as `replyTo.deleted`.
class MessageDeleted extends ChatEvent {
  const MessageDeleted({required this.conversationId, required this.messageId, required this.deletedAt});
  final String conversationId;
  final String messageId;
  final DateTime deletedAt;
}

/// `message.reactions` — the full list; replace, don't merge.
class MessageReactionsChanged extends ChatEvent {
  const MessageReactionsChanged({required this.conversationId, required this.messageId, required this.reactions});
  final String conversationId;
  final String messageId;
  final List<ReactionEntity> reactions;
}

/// Someone read up to [messageId] — drives the "seen" marker.
class MessagesRead extends ChatEvent {
  const MessagesRead({required this.userId, required this.messageId});
  final String userId;
  final String messageId;
}

/// `conversation.updated` — a group was renamed, re-photographed, or its
/// members changed. [conversation] carries the new participants.
class ConversationUpdated extends ChatEvent {
  const ConversationUpdated({required this.conversation, required this.change});
  final ConversationEntity conversation;
  final ConversationChange change;
}

/// `conversation.removed` — the viewer was removed from, or left, a group.
class ConversationRemoved extends ChatEvent {
  const ConversationRemoved({required this.conversationId, required this.reason});
  final String conversationId;

  /// `REMOVED` or `LEFT`.
  final String reason;
}

/// `group.invite.updated` — the invite card's status changed.
class GroupInviteUpdated extends ChatEvent {
  const GroupInviteUpdated({required this.inviteId, required this.conversationId, required this.status});
  final String inviteId;
  final String conversationId;
  final GroupInviteStatus status;
}
