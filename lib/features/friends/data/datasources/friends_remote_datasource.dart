import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_versioning/versioned_endpoints.dart';
import '../models/friendship_model.dart';

/// Which side of the pending-request list to read. `received` (the default)
/// is what the Circle tab shows; `sent` is the outgoing list.
enum RequestDirection {
  received,
  sent;

  String get wire => name;
}

abstract interface class FriendsRemoteDataSource {
  Future<({List<FriendshipModel> items, bool hasMore})> getFriends({int page});
  Future<({List<FriendshipModel> items, bool hasMore})> getRequests({
    int page,
    RequestDirection direction,
  });
  Future<({List<FriendshipModel> items, bool hasMore})> getBlocked({int page});

  Future<void> sendRequest(String userId);

  /// Withdraws a request *you* sent. Same path as [sendRequest], DELETE.
  Future<void> cancelRequest(String userId);

  Future<FriendshipModel> acceptRequest(String userId);
  Future<void> declineRequest(String userId);
  Future<void> unfriend(String userId);

  Future<FriendshipModel> blockUser(String userId);
  Future<FriendshipModel> unblockUser(String userId);
}

class FriendsRemoteDataSourceImpl implements FriendsRemoteDataSource {
  FriendsRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  static const _pageSize = 20;

  @override
  Future<({List<FriendshipModel> items, bool hasMore})> getFriends({int page = 0}) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          VersionedEndpoints.friends(),
          queryParameters: {'page': page, 'size': _pageSize},
        );
        return _page(res);
      });

  @override
  Future<({List<FriendshipModel> items, bool hasMore})> getRequests({
    int page = 0,
    RequestDirection direction = RequestDirection.received,
  }) =>
      _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          VersionedEndpoints.friendRequests(),
          queryParameters: {'page': page, 'size': _pageSize, 'direction': direction.wire},
        );
        return _page(res);
      });

  @override
  Future<({List<FriendshipModel> items, bool hasMore})> getBlocked({int page = 0}) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          VersionedEndpoints.friendsBlocked(),
          queryParameters: {'page': page, 'size': _pageSize},
        );
        return _page(res);
      });

  @override
  Future<void> sendRequest(String userId) =>
      _guard(() => _dio.post<void>(VersionedEndpoints.sendFriendRequest(userId)));

  @override
  Future<void> cancelRequest(String userId) =>
      _guard(() => _dio.delete<void>(VersionedEndpoints.sendFriendRequest(userId)));

  /// [userId] is the *sender's* user id — the backend addresses friend
  /// requests by the other user, never by a request id. POST, not PUT: an
  /// unknown method on a known path answers `404 RESOURCE_NOT_FOUND`.
  @override
  Future<FriendshipModel> acceptRequest(String userId) => _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(VersionedEndpoints.acceptFriendRequest(userId));
        return FriendshipModel.fromJson(ApiEnvelope.data(res));
      });

  /// See [acceptRequest] — same addressing rule, also POST.
  @override
  Future<void> declineRequest(String userId) =>
      _guard(() => _dio.post<void>(VersionedEndpoints.declineFriendRequest(userId)));

  @override
  Future<void> unfriend(String userId) => _guard(() => _dio.delete<void>(VersionedEndpoints.unfriend(userId)));

  /// Severs any friendship or pending request and hides both users' posts
  /// from each other. Idempotent, and never revealed to the other user.
  @override
  Future<FriendshipModel> blockUser(String userId) => _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(VersionedEndpoints.userBlock(userId));
        return FriendshipModel.fromJson(ApiEnvelope.data(res));
      });

  @override
  Future<FriendshipModel> unblockUser(String userId) => _guard(() async {
        final res = await _dio.delete<Map<String, dynamic>>(VersionedEndpoints.userBlock(userId));
        return FriendshipModel.fromJson(ApiEnvelope.data(res));
      });

  ({List<FriendshipModel> items, bool hasMore}) _page(Response<Map<String, dynamic>> res) {
    final envelope = ApiEnvelope.page(res);
    return (items: envelope.content.map(FriendshipModel.fromJson).toList(), hasMore: envelope.hasMore);
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : ErrorHandler.fromDioException(e);
    }
  }
}
