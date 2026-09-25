import 'dart:io';
import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/attachment_entity.dart';
import '../entities/conversation_entity.dart';
import '../entities/group_invite_entity.dart';
import '../entities/message_entity.dart';
import '../entities/participant_entity.dart';
import '../repositories/chat_repository.dart';

class CursorParams extends Equatable {
  const CursorParams({this.cursor});
  final String? cursor;

  @override
  List<Object?> get props => [cursor];
}

class GetConversationsUseCase implements UseCase<ConversationsPage, CursorParams> {
  GetConversationsUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, ConversationsPage>> call(CursorParams params) =>
      _repository.getConversations(cursor: params.cursor);
}

/// `GET /ws/conversations/{id}` — one conversation with its participants,
/// hydrated. The chat header and the group screen both start from this.
class GetConversationUseCase implements UseCase<ConversationEntity, String> {
  GetConversationUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, ConversationEntity>> call(String conversationId) =>
      _repository.getConversation(conversationId);
}

class GetMessagesParams extends Equatable {
  const GetMessagesParams({required this.conversationId, this.cursor});
  final String conversationId;
  final String? cursor;

  @override
  List<Object?> get props => [conversationId, cursor];
}

class GetMessagesUseCase implements UseCase<MessagesPage, GetMessagesParams> {
  GetMessagesUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, MessagesPage>> call(GetMessagesParams params) =>
      _repository.getMessages(params.conversationId, cursor: params.cursor);
}

/// The server's `CHAT_MESSAGE_MAX_LENGTH` default. Sanitising to the same
/// number means the client never truncates something the API would have
/// accepted, and never sends something it would reject with a 400.
const int chatMessageMaxLength = 4000;

/// `CHAT_MESSAGE_MAX_ATTACHMENTS` — files per message.
const int chatMessageMaxAttachments = 10;

final _clientIdRandom = Random();

/// Idempotency key for one composed message: time-ordered, collision-safe
/// enough for a single device, and well inside the server's 64-char limit.
/// Lives here rather than on `ChatCubit` because the notification's
/// direct-reply action needs one too, from an isolate that has no Cubit.
String newChatClientId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
    '${_clientIdRandom.nextInt(0x7fffffff).toRadixString(36)}';

class SendMessageParams extends Equatable {
  const SendMessageParams({
    required this.conversationId,
    required this.text,
    required this.clientId,
    this.replyToMessageId,
    this.attachmentIds = const [],
  });

  final String conversationId;
  final String text;

  /// Idempotency key — generated once by the caller and reused on retry.
  final String clientId;

  final String? replyToMessageId;

  /// Ids from `UploadAttachmentUseCase`, in display order.
  final List<String> attachmentIds;

  @override
  List<Object?> get props => [conversationId, text, clientId, replyToMessageId, attachmentIds];
}

class SendMessageUseCase implements UseCase<MessageEntity, SendMessageParams> {
  SendMessageUseCase(this._repository);
  final ChatRepository _repository;

  /// Kept as a static for the callers that already read it.
  static const int maxBodyLength = chatMessageMaxLength;

  @override
  Future<Either<Failure, MessageEntity>> call(SendMessageParams params) {
    final clean = InputSanitizer.sanitizeText(params.text, maxLength: maxBodyLength);
    // An empty body is only a message when it carries files.
    if (clean.isEmpty && params.attachmentIds.isEmpty) {
      return Future.value(const Left(ValidationFailure('Message cannot be empty.')));
    }
    if (params.attachmentIds.length > chatMessageMaxAttachments) {
      return Future.value(const Left(ValidationFailure('You can attach up to $chatMessageMaxAttachments files.')));
    }
    return _repository.sendMessage(
      conversationId: params.conversationId,
      body: clean,
      clientId: params.clientId,
      replyToMessageId: params.replyToMessageId,
      attachmentIds: params.attachmentIds,
    );
  }
}

class EditMessageParams extends Equatable {
  const EditMessageParams({
    required this.conversationId,
    required this.messageId,
    required this.text,
    this.hasAttachments = false,
  });

  final String conversationId;
  final String messageId;
  final String text;

  /// The server allows an empty body only on a message that still has
  /// files; the caller knows that from the message it is editing.
  final bool hasAttachments;

  @override
  List<Object?> get props => [conversationId, messageId, text, hasAttachments];
}

class EditMessageUseCase implements UseCase<MessageEntity, EditMessageParams> {
  EditMessageUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, MessageEntity>> call(EditMessageParams params) {
    final clean = InputSanitizer.sanitizeText(params.text, maxLength: chatMessageMaxLength);
    if (clean.isEmpty && !params.hasAttachments) {
      return Future.value(const Left(ValidationFailure('Message cannot be empty.')));
    }
    return _repository.editMessage(conversationId: params.conversationId, messageId: params.messageId, body: clean);
  }
}

class MessageRefParams extends Equatable {
  const MessageRefParams({required this.conversationId, required this.messageId});
  final String conversationId;
  final String messageId;

  @override
  List<Object?> get props => [conversationId, messageId];
}

class DeleteMessageUseCase implements UseCase<Unit, MessageRefParams> {
  DeleteMessageUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(MessageRefParams params) =>
      _repository.deleteMessage(conversationId: params.conversationId, messageId: params.messageId);
}

class ReactToMessageParams extends Equatable {
  const ReactToMessageParams({required this.conversationId, required this.messageId, this.emoji});
  final String conversationId;
  final String messageId;

  /// Null removes the viewer's reaction (`DELETE …/reaction`); otherwise
  /// exactly one emoji, which replaces any previous one.
  final String? emoji;

  @override
  List<Object?> get props => [conversationId, messageId, emoji];
}

/// Set or clear the viewer's reaction. Both branches answer with the
/// message's full reaction list, which the caller swaps in wholesale.
class ReactToMessageUseCase implements UseCase<List<ReactionEntity>, ReactToMessageParams> {
  ReactToMessageUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, List<ReactionEntity>>> call(ReactToMessageParams params) {
    final emoji = params.emoji?.trim();
    if (emoji == null || emoji.isEmpty) {
      return _repository.removeReaction(conversationId: params.conversationId, messageId: params.messageId);
    }
    return _repository.setReaction(conversationId: params.conversationId, messageId: params.messageId, emoji: emoji);
  }
}

class UploadAttachmentParams extends Equatable {
  const UploadAttachmentParams({required this.conversationId, required this.file});
  final String conversationId;
  final File file;

  @override
  List<Object?> get props => [conversationId, file.path];
}

/// `CHAT_ATTACHMENT_MAX_BYTES` — the server answers 413 above this. Checked
/// here so a too-large pick fails before the bytes leave the phone.
const int chatAttachmentMaxBytes = 10 * 1024 * 1024;

class UploadAttachmentUseCase implements UseCase<AttachmentEntity, UploadAttachmentParams> {
  UploadAttachmentUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, AttachmentEntity>> call(UploadAttachmentParams params) async {
    final size = await params.file.length();
    if (size > chatAttachmentMaxBytes) return const Left(ValidationFailure('That file is over 10 MB.'));
    return _repository.uploadAttachment(conversationId: params.conversationId, file: params.file);
  }
}

/// `VOICE_MAX_DURATION_MS` — the server rejects anything longer with a 400.
/// The recorder stops itself at this, so hitting it here means something
/// went wrong rather than a user holding the button too long.
const Duration voiceMaxDuration = Duration(minutes: 5);

/// Shorter than this and there is nothing to listen to — a mis-tap on the
/// mic rather than a message. Discarded without an upload, as the API's own
/// client checklist asks.
const Duration voiceMinDuration = Duration(seconds: 1);

/// `POST /ws/conversations/{id}/attachments/voice`.
///
/// Size is checked here for the same reason [UploadAttachmentUseCase] checks
/// it — a 413 after uploading a 10 MiB body is a slow way to learn — but the
/// duration cap is the recorder's job: by the time a file exists it is too
/// late to do anything but refuse it.
class UploadVoiceAttachmentUseCase implements UseCase<AttachmentEntity, UploadAttachmentParams> {
  UploadVoiceAttachmentUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, AttachmentEntity>> call(UploadAttachmentParams params) async {
    final size = await params.file.length();
    if (size > chatAttachmentMaxBytes) return const Left(ValidationFailure('That recording is over 10 MB.'));
    return _repository.uploadVoiceAttachment(conversationId: params.conversationId, file: params.file);
  }
}

/// `GET /ws/attachments/{id}` — a fresh presigned URL for one whose link has
/// expired.
class RefreshAttachmentUseCase implements UseCase<AttachmentEntity, String> {
  RefreshAttachmentUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, AttachmentEntity>> call(String attachmentId) => _repository.getAttachment(attachmentId);
}

class MarkReadParams extends Equatable {
  const MarkReadParams({required this.conversationId, required this.messageId});
  final String conversationId;
  final String messageId;

  @override
  List<Object?> get props => [conversationId, messageId];
}

class MarkReadUseCase implements UseCase<Unit, MarkReadParams> {
  MarkReadUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(MarkReadParams params) =>
      _repository.markRead(conversationId: params.conversationId, messageId: params.messageId);
}

/// Opens or reuses the DIRECT conversation with another user — the entry
/// point from a profile's "Message" action.
class StartDirectConversationUseCase implements UseCase<ConversationEntity, String> {
  StartDirectConversationUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, ConversationEntity>> call(String peerId) => _repository.startDirect(peerId);
}

class StartGroupParams extends Equatable {
  const StartGroupParams({required this.title, required this.memberIds});
  final String title;
  final List<String> memberIds;

  @override
  List<Object?> get props => [title, memberIds];
}

/// `POST /ws/conversations` with `type: GROUP` — the caller becomes OWNER.
class StartGroupConversationUseCase implements UseCase<ConversationEntity, StartGroupParams> {
  StartGroupConversationUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, ConversationEntity>> call(StartGroupParams params) {
    final title = InputSanitizer.sanitizeText(params.title, maxLength: groupTitleMaxLength);
    if (title.isEmpty) return Future.value(const Left(ValidationFailure('Give the group a name.')));
    if (params.memberIds.isEmpty) return Future.value(const Left(ValidationFailure('Add at least one person.')));
    return _repository.startGroup(title: title, memberIds: params.memberIds);
  }
}

// --- groups ---

/// `PATCH /ws/conversations/{id}` takes 1–100 characters.
const int groupTitleMaxLength = 100;

/// `CHAT_GROUP_MAX_MEMBERS` — people in a group, the viewer included.
const int groupMaxMembers = 50;

class RenameGroupParams extends Equatable {
  const RenameGroupParams({required this.conversationId, required this.title});
  final String conversationId;
  final String title;

  @override
  List<Object?> get props => [conversationId, title];
}

class RenameGroupUseCase implements UseCase<ConversationEntity, RenameGroupParams> {
  RenameGroupUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, ConversationEntity>> call(RenameGroupParams params) {
    final title = InputSanitizer.sanitizeText(params.title, maxLength: groupTitleMaxLength);
    if (title.isEmpty) return Future.value(const Left(ValidationFailure('Give the group a name.')));
    return _repository.renameGroup(conversationId: params.conversationId, title: title);
  }
}

class SetGroupPhotoParams extends Equatable {
  const SetGroupPhotoParams({required this.conversationId, required this.file});
  final String conversationId;
  final File file;

  @override
  List<Object?> get props => [conversationId, file.path];
}

/// `PUT /ws/conversations/{id}/photo` — JPEG, PNG, GIF or WebP by content;
/// the same 10 MiB ceiling as an attachment.
class SetGroupPhotoUseCase implements UseCase<ConversationEntity, SetGroupPhotoParams> {
  SetGroupPhotoUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, ConversationEntity>> call(SetGroupPhotoParams params) async {
    final size = await params.file.length();
    if (size > chatAttachmentMaxBytes) return const Left(ValidationFailure('That photo is over 10 MB.'));
    return _repository.setGroupPhoto(conversationId: params.conversationId, file: params.file);
  }
}

class RemoveGroupPhotoUseCase implements UseCase<ConversationEntity, String> {
  RemoveGroupPhotoUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, ConversationEntity>> call(String conversationId) =>
      _repository.removeGroupPhoto(conversationId);
}

class GroupMembersParams extends Equatable {
  const GroupMembersParams({required this.conversationId, required this.userIds});
  final String conversationId;
  final List<String> userIds;

  @override
  List<Object?> get props => [conversationId, userIds];
}

class AddGroupMembersUseCase implements UseCase<List<ParticipantEntity>, GroupMembersParams> {
  AddGroupMembersUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, List<ParticipantEntity>>> call(GroupMembersParams params) {
    if (params.userIds.isEmpty) return Future.value(const Left(ValidationFailure('Pick someone to add.')));
    return _repository.addGroupMembers(conversationId: params.conversationId, userIds: params.userIds);
  }
}

class GroupMemberParams extends Equatable {
  const GroupMemberParams({required this.conversationId, required this.userId});
  final String conversationId;
  final String userId;

  @override
  List<Object?> get props => [conversationId, userId];
}

class RemoveGroupMemberUseCase implements UseCase<Unit, GroupMemberParams> {
  RemoveGroupMemberUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(GroupMemberParams params) =>
      _repository.removeGroupMember(conversationId: params.conversationId, userId: params.userId);
}

class ChangeMemberRoleParams extends Equatable {
  const ChangeMemberRoleParams({required this.conversationId, required this.userId, required this.role});
  final String conversationId;
  final String userId;

  /// `admin` or `member` — the owner's seat cannot be handed over this way.
  final ParticipantRole role;

  @override
  List<Object?> get props => [conversationId, userId, role];
}

class ChangeMemberRoleUseCase implements UseCase<List<ParticipantEntity>, ChangeMemberRoleParams> {
  ChangeMemberRoleUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, List<ParticipantEntity>>> call(ChangeMemberRoleParams params) {
    if (params.role == ParticipantRole.owner) {
      return Future.value(const Left(ValidationFailure('Ownership cannot be transferred.')));
    }
    return _repository.changeMemberRole(
      conversationId: params.conversationId,
      userId: params.userId,
      role: params.role,
    );
  }
}

class LeaveGroupUseCase implements UseCase<Unit, String> {
  LeaveGroupUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String conversationId) => _repository.leaveGroup(conversationId);
}

// --- invite cards ---

class InviteToGroupUseCase implements UseCase<GroupInviteResult, GroupMemberParams> {
  InviteToGroupUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, GroupInviteResult>> call(GroupMemberParams params) =>
      _repository.inviteToGroup(conversationId: params.conversationId, userId: params.userId);
}

class AcceptGroupInviteUseCase implements UseCase<ConversationEntity, String> {
  AcceptGroupInviteUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, ConversationEntity>> call(String inviteId) => _repository.acceptInvite(inviteId);
}

class DeclineGroupInviteUseCase implements UseCase<Unit, String> {
  DeclineGroupInviteUseCase(this._repository);
  final ChatRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String inviteId) => _repository.declineInvite(inviteId);
}
