import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../../profile/domain/usecases/profile_usecases.dart';
import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/group_invite_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/participant_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_frame_decoder.dart';
import '../datasources/chat_remote_datasource.dart';
import '../datasources/chat_socket.dart';
import '../datasources/user_directory.dart';

/// Backs the chat feature with the real `yello-chat` service.
///
/// Two things this layer owns that the service does not give us:
///
///  * **viewer identity.** `fromMe`, `reactedByMe`, an invite card's `forMe`
///    and "who is the other person in this DIRECT conversation" all need the
///    signed-in user's id, which the chat payloads never carry. It is
///    resolved once via [GetMeUseCase] and memoised — [_viewerId] — then
///    handed to the mappers.
///  * **display identity.** Participants arrive as bare ids; [UserDirectory]
///    turns them into names and avatars from yello-api. Every route that
///    answers with a conversation or a member list is hydrated here, so no
///    caller ever sees an unhydrated group.
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._remote, this._directory, this._getMe, this._networkInfo, this._socket);

  final ChatRemoteDataSource _remote;
  final UserDirectory _directory;
  final GetMeUseCase _getMe;
  final NetworkInfo _networkInfo;
  final ChatSocket _socket;

  String? _viewerId;

  /// Resolved lazily and kept for the session. A failure here is not fatal:
  /// mapping degrades to "nothing is mine" rather than failing the call, and
  /// the next request retries the lookup.
  Future<String?> _ensureViewerId() async {
    if (_viewerId != null) return _viewerId;
    final result = await _getMe(const NoParams());
    return _viewerId = result.fold((_) => null, (me) => me.id);
  }

  Future<Either<Failure, T>> _run<T>(Future<T> Function() body) async {
    if (!await _networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await body());
    } on AppException catch (e) {
      return Left(ErrorHandler.toFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  /// Every call funnels through here so the datasource always has a viewer
  /// id before it maps anything.
  Future<void> _prime() async => _remote.viewerId = await _ensureViewerId();

  @override
  Future<Either<Failure, ConversationsPage>> getConversations({String? cursor}) => _run(() async {
        await _prime();
        final page = await _remote.getConversations(cursor: cursor);
        final hydrated = await _directory.hydrateAll(page.items);
        return ConversationsPage(conversations: hydrated, nextCursor: page.nextCursor);
      });

  @override
  Future<Either<Failure, ConversationEntity>> getConversation(String conversationId) => _run(() async {
        await _prime();
        return _directory.hydrateConversation(await _remote.getConversation(conversationId));
      });

  @override
  Future<Either<Failure, ConversationEntity>> startDirect(String peerId) => _run(() async {
        await _prime();
        return _directory.hydrateConversation(await _remote.createDirect(peerId));
      });

  @override
  Future<Either<Failure, ConversationEntity>> startGroup({
    required String title,
    required List<String> memberIds,
  }) =>
      _run(() async {
        await _prime();
        return _directory.hydrateConversation(
          await _remote.createGroup(title: title, memberIds: memberIds),
        );
      });

  @override
  Future<Either<Failure, MessagesPage>> getMessages(String conversationId, {String? cursor}) =>
      _run(() async {
        await _prime();
        final page = await _remote.getMessages(conversationId, cursor: cursor);
        return MessagesPage(messages: page.items, nextCursor: page.nextCursor);
      });

  @override
  Future<Either<Failure, MessageEntity>> sendMessage({
    required String conversationId,
    required String body,
    required String clientId,
    String? replyToMessageId,
    List<String> attachmentIds = const [],
  }) =>
      _run(() async {
        await _prime();
        return _remote.sendMessage(
          conversationId: conversationId,
          clientId: clientId,
          body: body,
          replyToMessageId: replyToMessageId,
          attachmentIds: attachmentIds,
        );
      });

  @override
  Future<Either<Failure, MessageEntity>> editMessage({
    required String conversationId,
    required String messageId,
    required String body,
  }) =>
      _run(() async {
        await _prime();
        return _remote.editMessage(conversationId: conversationId, messageId: messageId, body: body);
      });

  @override
  Future<Either<Failure, Unit>> deleteMessage({required String conversationId, required String messageId}) =>
      _run(() async {
        await _remote.deleteMessage(conversationId: conversationId, messageId: messageId);
        return unit;
      });

  @override
  Future<Either<Failure, List<ReactionEntity>>> setReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) =>
      _run(() async {
        await _prime();
        return _remote.setReaction(conversationId: conversationId, messageId: messageId, emoji: emoji);
      });

  @override
  Future<Either<Failure, List<ReactionEntity>>> removeReaction({
    required String conversationId,
    required String messageId,
  }) =>
      _run(() async {
        await _prime();
        return _remote.removeReaction(conversationId: conversationId, messageId: messageId);
      });

  @override
  Future<Either<Failure, AttachmentEntity>> uploadAttachment({required String conversationId, required File file}) =>
      _run(() => _remote.uploadAttachment(conversationId: conversationId, file: file));

  @override
  Future<Either<Failure, AttachmentEntity>> getAttachment(String attachmentId) =>
      _run(() => _remote.getAttachment(attachmentId));

  @override
  Future<Either<Failure, Unit>> markRead({
    required String conversationId,
    required String messageId,
  }) =>
      _run(() async {
        await _remote.markRead(conversationId: conversationId, messageId: messageId);
        return unit;
      });

  // --- groups ---

  @override
  Future<Either<Failure, ConversationEntity>> renameGroup({required String conversationId, required String title}) =>
      _run(() async {
        await _prime();
        return _directory.hydrateConversation(await _remote.renameGroup(conversationId: conversationId, title: title));
      });

  @override
  Future<Either<Failure, ConversationEntity>> setGroupPhoto({required String conversationId, required File file}) =>
      _run(() async {
        await _prime();
        return _directory.hydrateConversation(await _remote.setGroupPhoto(conversationId: conversationId, file: file));
      });

  @override
  Future<Either<Failure, ConversationEntity>> removeGroupPhoto(String conversationId) => _run(() async {
        await _prime();
        return _directory.hydrateConversation(await _remote.removeGroupPhoto(conversationId));
      });

  @override
  Future<Either<Failure, List<ParticipantEntity>>> addGroupMembers({
    required String conversationId,
    required List<String> userIds,
  }) =>
      _run(() async {
        final members = await _remote.addMembers(conversationId: conversationId, userIds: userIds);
        return _directory.hydrate(members);
      });

  @override
  Future<Either<Failure, Unit>> removeGroupMember({required String conversationId, required String userId}) =>
      _run(() async {
        await _remote.removeMember(conversationId: conversationId, userId: userId);
        return unit;
      });

  @override
  Future<Either<Failure, List<ParticipantEntity>>> changeMemberRole({
    required String conversationId,
    required String userId,
    required ParticipantRole role,
  }) =>
      _run(() async {
        final members = await _remote.setMemberRole(conversationId: conversationId, userId: userId, role: role);
        return _directory.hydrate(members);
      });

  @override
  Future<Either<Failure, Unit>> leaveGroup(String conversationId) => _run(() async {
        await _remote.leaveGroup(conversationId);
        return unit;
      });

  // --- invite cards ---

  @override
  Future<Either<Failure, GroupInviteResult>> inviteToGroup({required String conversationId, required String userId}) =>
      _run(() async {
        await _prime();
        return _remote.inviteToGroup(conversationId: conversationId, userId: userId);
      });

  @override
  Future<Either<Failure, ConversationEntity>> acceptInvite(String inviteId) => _run(() async {
        await _prime();
        return _directory.hydrateConversation(await _remote.acceptInvite(inviteId));
      });

  @override
  Future<Either<Failure, Unit>> declineInvite(String inviteId) => _run(() async {
        await _remote.declineInvite(inviteId);
        return unit;
      });

  /// One socket for the whole app, filtered here to [conversationId]. The
  /// viewer id is resolved first so `fromMe` / `reactedByMe` on live frames
  /// match the HTTP path. Server `error` frames are logged rather than
  /// surfaced: the only requests this client makes over the socket are
  /// best-effort typing signals, and the log line carries the server's
  /// `details.issues` paths, which is how a wrong field name shows itself.
  @override
  Stream<ChatEvent> watchEvents(String conversationId) async* {
    await _prime();
    final viewerId = _viewerId;

    final live = _socket.connectionChanges.map<ChatEvent>(LiveDeliveryChanged.new);
    final frames = _socket.frames.map<ChatEvent?>((frame) {
      final data = frame['data'];
      if (frame['event'] == 'error') {
        appLogger.w('yello-chat error frame: $frame');
        return null;
      }
      if (data is Map<String, dynamic>) {
        final target = data['conversationId'];
        if (target is String && target != conversationId) return null;
      }
      return ChatFrameDecoder.decodeFrame(frame, viewerId: viewerId);
    });

    // Report the current state first, so a screen opened while the socket
    // is already up does not wait for the next flip.
    yield LiveDeliveryChanged(_socket.isConnected);
    yield* _merge(frames, live);
  }

  static Stream<ChatEvent> _merge(Stream<ChatEvent?> a, Stream<ChatEvent> b) {
    final controller = StreamController<ChatEvent>();
    late final StreamSubscription<ChatEvent?> subA;
    late final StreamSubscription<ChatEvent> subB;
    controller
      ..onListen = () {
        subA = a.listen((e) {
          if (e != null) controller.add(e);
        });
        subB = b.listen(controller.add);
      }
      ..onCancel = () async {
        await subA.cancel();
        await subB.cancel();
      };
    return controller.stream;
  }

  @override
  void sendTyping({required String conversationId, required bool isTyping}) =>
      _socket.send('typing', {'conversationId': conversationId, 'isTyping': isTyping});
}
