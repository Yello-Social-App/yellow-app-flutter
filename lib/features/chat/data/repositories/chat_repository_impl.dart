import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../profile/domain/usecases/profile_usecases.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';
import '../datasources/user_directory.dart';

/// Backs the chat feature with the real `yello-chat` service.
///
/// Two things this layer owns that the service does not give us:
///
///  * **viewer identity.** `fromMe` and "who is the other person in this
///    DIRECT conversation" both need the signed-in user's id, which the chat
///    payloads never carry. It is resolved once via [GetMeUseCase] and
///    memoised — [_viewerId] — then handed to the mappers.
///  * **display identity.** Participants arrive as bare ids; [UserDirectory]
///    turns them into names and avatars from yello-api.
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._remote, this._directory, this._getMe, this._networkInfo);

  final ChatRemoteDataSource _remote;
  final UserDirectory _directory;
  final GetMeUseCase _getMe;
  final NetworkInfo _networkInfo;

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
  }) =>
      _run(() async {
        await _prime();
        return _remote.sendMessage(conversationId: conversationId, clientId: clientId, body: body);
      });

  @override
  Future<Either<Failure, Unit>> markRead({
    required String conversationId,
    required String messageId,
  }) =>
      _run(() async {
        await _remote.markRead(conversationId: conversationId, messageId: messageId);
        return unit;
      });

  /// No socket yet — see [ChatRepository.watchEvents]. Returns an empty
  /// stream rather than null so [ChatCubit] needs no special case, and so
  /// swapping in the real client is a one-line change here.
  @override
  Stream<ChatEvent> watchEvents(String conversationId) => Stream<ChatEvent>.empty();
}
