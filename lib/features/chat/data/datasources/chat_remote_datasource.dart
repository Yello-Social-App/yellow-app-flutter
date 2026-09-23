import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/group_invite_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/participant_entity.dart';
import '../models/conversation_model.dart';
import '../models/group_invite_model.dart';
import '../models/message_model.dart';

/// Routes for `yello-chat`, a **separate service** from yello-api.
///
/// It shares the host and the bearer token but nothing else: no `/v1`
/// version segment, no `{success, data, timestamp}` envelope, and its own
/// error body (`{code, message, details}` — see [ChatErrorCodes]). That is
/// why these paths are not in `VersionedEndpoints` — its resolver would
/// prepend `/v1` and produce a 404.
///
/// Live spec: `/ws/docs` (Swagger UI), `/ws/docs-json`.
abstract final class ChatRoutes {
  static const String _root = '/ws';

  static const String conversations = '$_root/conversations';
  static String conversation(String id) => '$_root/conversations/$id';
  static String messages(String id) => '$_root/conversations/$id/messages';
  static String message(String id, String messageId) => '$_root/conversations/$id/messages/$messageId';
  static String reaction(String id, String messageId) => '${message(id, messageId)}/reaction';
  static String read(String id) => '$_root/conversations/$id/read';

  // Attachments: upload is per conversation, refresh is by attachment id.
  static String attachments(String id) => '$_root/conversations/$id/attachments';
  static String attachment(String attachmentId) => '$_root/attachments/$attachmentId';

  // Groups — every one of these is 400 on a DM.
  static String photo(String id) => '$_root/conversations/$id/photo';
  static String members(String id) => '$_root/conversations/$id/members';
  static String member(String id, String userId) => '$_root/conversations/$id/members/$userId';
  static String leave(String id) => '$_root/conversations/$id/leave';

  // Invite cards.
  static String invites(String id) => '$_root/conversations/$id/invites';
  static String acceptInvite(String inviteId) => '$_root/invites/$inviteId/accept';
  static String declineInvite(String inviteId) => '$_root/invites/$inviteId/decline';

  /// Live delivery endpoint — same path, upgraded. Frames are
  /// `{event, data}`; see `ChatRepository.watchEvents` and
  /// `ChatFrameDecoder`.
  static const String socketPath = _root;
}

abstract interface class ChatRemoteDataSource {
  /// The signed-in user's id. Mapping needs it to derive `fromMe`, each
  /// reaction's `reactedByMe`, an invite card's `forMe`, and to pick the
  /// peer of a DIRECT conversation — the chat payloads carry no notion of
  /// "you". The repository sets it before every call.
  set viewerId(String? value);

  Future<ConversationPage> getConversations({String? cursor, int? limit});
  Future<ConversationEntity> getConversation(String id);
  Future<ConversationEntity> createDirect(String peerId);
  Future<ConversationEntity> createGroup({required String title, required List<String> memberIds});
  Future<MessagePage> getMessages(String conversationId, {String? cursor, int? limit});
  Future<MessageEntity> sendMessage({
    required String conversationId,
    required String clientId,
    required String body,
    String? replyToMessageId,
    List<String> attachmentIds = const [],
  });
  Future<MessageEntity> editMessage({required String conversationId, required String messageId, required String body});
  Future<void> deleteMessage({required String conversationId, required String messageId});
  Future<List<ReactionEntity>> setReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  });
  Future<List<ReactionEntity>> removeReaction({required String conversationId, required String messageId});
  Future<AttachmentEntity> uploadAttachment({required String conversationId, required File file});
  Future<AttachmentEntity> getAttachment(String attachmentId);
  Future<void> markRead({required String conversationId, required String messageId});

  Future<ConversationEntity> renameGroup({required String conversationId, required String title});
  Future<ConversationEntity> setGroupPhoto({required String conversationId, required File file});
  Future<ConversationEntity> removeGroupPhoto(String conversationId);
  Future<List<ParticipantEntity>> addMembers({required String conversationId, required List<String> userIds});
  Future<void> removeMember({required String conversationId, required String userId});
  Future<List<ParticipantEntity>> setMemberRole({
    required String conversationId,
    required String userId,
    required ParticipantRole role,
  });
  Future<void> leaveGroup(String conversationId);

  Future<GroupInviteResult> inviteToGroup({required String conversationId, required String userId});
  Future<ConversationEntity> acceptInvite(String inviteId);
  Future<void> declineInvite(String inviteId);
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  ChatRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  @override
  String? viewerId;

  @override
  Future<ConversationPage> getConversations({String? cursor, int? limit}) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          ChatRoutes.conversations,
          queryParameters: {
            'limit': ?limit,
            'cursor': ?cursor,
          },
        );
        return ConversationPage.fromJson(_body(res), viewerId: viewerId);
      });

  @override
  Future<ConversationEntity> getConversation(String id) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(ChatRoutes.conversation(id));
        return ConversationMapper.fromJson(_body(res), viewerId: viewerId);
      });

  @override
  Future<ConversationEntity> createDirect(String peerId) => _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          ChatRoutes.conversations,
          data: {'type': 'DIRECT', 'peerId': peerId},
        );
        return ConversationMapper.fromJson(_body(res), viewerId: viewerId);
      });

  @override
  Future<ConversationEntity> createGroup({required String title, required List<String> memberIds}) =>
      _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          ChatRoutes.conversations,
          data: {'type': 'GROUP', 'title': title, 'memberIds': memberIds},
        );
        return ConversationMapper.fromJson(_body(res), viewerId: viewerId);
      });

  @override
  Future<MessagePage> getMessages(String conversationId, {String? cursor, int? limit}) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          ChatRoutes.messages(conversationId),
          queryParameters: {
            'limit': ?limit,
            'cursor': ?cursor,
          },
        );
        return MessagePage.fromJson(_body(res), viewerId: viewerId);
      });

  /// [clientId] is an idempotency key: re-sending the same one after a
  /// timeout returns the original message instead of creating a duplicate.
  /// `body` is only sent when non-empty — the server accepts its absence
  /// for an attachment-only message but rejects `""` when there are none.
  @override
  Future<MessageEntity> sendMessage({
    required String conversationId,
    required String clientId,
    required String body,
    String? replyToMessageId,
    List<String> attachmentIds = const [],
  }) =>
      _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          ChatRoutes.messages(conversationId),
          data: {
            'clientId': clientId,
            if (body.isNotEmpty) 'body': body,
            'replyToMessageId': ?replyToMessageId,
            if (attachmentIds.isNotEmpty) 'attachmentIds': attachmentIds,
          },
        );
        return MessageMapper.fromJson(_body(res), viewerId: viewerId);
      });

  @override
  Future<MessageEntity> editMessage({
    required String conversationId,
    required String messageId,
    required String body,
  }) =>
      _guard(() async {
        final res = await _dio.patch<Map<String, dynamic>>(
          ChatRoutes.message(conversationId, messageId),
          data: {'body': body},
        );
        return MessageMapper.fromJson(_body(res), viewerId: viewerId);
      });

  /// 204, no body.
  @override
  Future<void> deleteMessage({required String conversationId, required String messageId}) =>
      _guard(() => _dio.delete<void>(ChatRoutes.message(conversationId, messageId)));

  @override
  Future<List<ReactionEntity>> setReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) =>
      _guard(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          ChatRoutes.reaction(conversationId, messageId),
          data: {'emoji': emoji},
        );
        return ReactionMapper.fromMessageReactions(_body(res), viewerId: viewerId);
      });

  @override
  Future<List<ReactionEntity>> removeReaction({required String conversationId, required String messageId}) =>
      _guard(() async {
        final res = await _dio.delete<Map<String, dynamic>>(ChatRoutes.reaction(conversationId, messageId));
        return ReactionMapper.fromMessageReactions(_body(res), viewerId: viewerId);
      });

  /// `multipart/form-data`, one field `file`. The server types the upload
  /// from its bytes, so the filename only feeds `fileName`.
  @override
  Future<AttachmentEntity> uploadAttachment({required String conversationId, required File file}) =>
      _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          ChatRoutes.attachments(conversationId),
          data: await _fileForm(file),
        );
        return AttachmentMapper.fromJson(_body(res));
      });

  @override
  Future<AttachmentEntity> getAttachment(String attachmentId) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(ChatRoutes.attachment(attachmentId));
        return AttachmentMapper.fromJson(_body(res));
      });

  /// 204, no body. The server never moves a read marker backwards, so
  /// sending a stale [messageId] is harmless.
  @override
  Future<void> markRead({required String conversationId, required String messageId}) => _guard(
        () => _dio.post<void>(ChatRoutes.read(conversationId), data: {'messageId': messageId}),
      );

  // --- groups ---

  @override
  Future<ConversationEntity> renameGroup({required String conversationId, required String title}) =>
      _guard(() async {
        final res = await _dio.patch<Map<String, dynamic>>(
          ChatRoutes.conversation(conversationId),
          data: {'title': title},
        );
        return ConversationMapper.fromJson(_body(res), viewerId: viewerId);
      });

  @override
  Future<ConversationEntity> setGroupPhoto({required String conversationId, required File file}) =>
      _guard(() async {
        final res = await _dio.put<Map<String, dynamic>>(ChatRoutes.photo(conversationId), data: await _fileForm(file));
        return ConversationMapper.fromJson(_body(res), viewerId: viewerId);
      });

  @override
  Future<ConversationEntity> removeGroupPhoto(String conversationId) => _guard(() async {
        final res = await _dio.delete<Map<String, dynamic>>(ChatRoutes.photo(conversationId));
        return ConversationMapper.fromJson(_body(res), viewerId: viewerId);
      });

  @override
  Future<List<ParticipantEntity>> addMembers({required String conversationId, required List<String> userIds}) =>
      _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          ChatRoutes.members(conversationId),
          data: {'userIds': userIds},
        );
        return ConversationMapper.participantsFromJson(_body(res));
      });

  /// 204, no body.
  @override
  Future<void> removeMember({required String conversationId, required String userId}) =>
      _guard(() => _dio.delete<void>(ChatRoutes.member(conversationId, userId)));

  @override
  Future<List<ParticipantEntity>> setMemberRole({
    required String conversationId,
    required String userId,
    required ParticipantRole role,
  }) =>
      _guard(() async {
        final res = await _dio.patch<Map<String, dynamic>>(
          ChatRoutes.member(conversationId, userId),
          data: {'role': role.wire},
        );
        return ConversationMapper.participantsFromJson(_body(res));
      });

  /// 204, no body.
  @override
  Future<void> leaveGroup(String conversationId) => _guard(() => _dio.post<void>(ChatRoutes.leave(conversationId)));

  // --- invite cards ---

  @override
  Future<GroupInviteResult> inviteToGroup({required String conversationId, required String userId}) =>
      _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          ChatRoutes.invites(conversationId),
          data: {'userId': userId},
        );
        return GroupInviteMapper.resultFromJson(_body(res), viewerId: viewerId);
      });

  @override
  Future<ConversationEntity> acceptInvite(String inviteId) => _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(ChatRoutes.acceptInvite(inviteId));
        return ConversationMapper.fromJson(_body(res), viewerId: viewerId);
      });

  /// 204, no body.
  @override
  Future<void> declineInvite(String inviteId) => _guard(() => _dio.post<void>(ChatRoutes.declineInvite(inviteId)));

  Future<FormData> _fileForm(File file) async =>
      FormData.fromMap({'file': await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last)});

  Map<String, dynamic> _body(Response<Map<String, dynamic>> res) =>
      res.data ?? const <String, dynamic>{};

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : ErrorHandler.fromDioException(e);
    }
  }
}
