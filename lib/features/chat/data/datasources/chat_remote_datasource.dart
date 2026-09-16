import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

/// Routes for `yello-chat`, a **separate service** from yello-api.
///
/// It shares the host and the bearer token but nothing else: no `/v1`
/// version segment, no `{success, data, timestamp}` envelope, and its own
/// error body (`{code, message, details}` with codes like `UNAUTHORIZED` and
/// `RATE_LIMITED`). That is why these paths are not in `VersionedEndpoints`
/// — its resolver would prepend `/v1` and produce a 404.
abstract final class ChatRoutes {
  static const String _root = '/ws';

  static const String conversations = '$_root/conversations';
  static String conversation(String id) => '$_root/conversations/$id';
  static String messages(String id) => '$_root/conversations/$id/messages';
  static String read(String id) => '$_root/conversations/$id/read';

  /// Live delivery endpoint — same path, upgraded. Frames are
  /// `{event, data}`; see `ChatRepository.watchEvents`.
  static const String socketPath = _root;
}

abstract interface class ChatRemoteDataSource {
  /// The signed-in user's id. Mapping needs it to derive `fromMe` and to
  /// pick the peer of a DIRECT conversation — the chat payloads carry no
  /// notion of "you". The repository sets it before every call.
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
  });
  Future<void> markRead({required String conversationId, required String messageId});
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
  @override
  Future<MessageEntity> sendMessage({
    required String conversationId,
    required String clientId,
    required String body,
  }) =>
      _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          ChatRoutes.messages(conversationId),
          data: {'clientId': clientId, 'body': body},
        );
        return MessageMapper.fromJson(_body(res), viewerId: viewerId);
      });

  /// 204, no body. The server never moves a read marker backwards, so
  /// sending a stale [messageId] is harmless.
  @override
  Future<void> markRead({required String conversationId, required String messageId}) => _guard(
        () => _dio.post<void>(ChatRoutes.read(conversationId), data: {'messageId': messageId}),
      );

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
