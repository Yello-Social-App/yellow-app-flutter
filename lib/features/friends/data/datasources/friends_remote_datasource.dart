import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_versioning/versioned_endpoints.dart';
import '../models/friendship_model.dart';

abstract interface class FriendsRemoteDataSource {
  Future<({List<FriendshipModel> items, bool hasMore})> getFriends({int page});
  Future<({List<FriendshipModel> items, bool hasMore})> getRequests({int page});
  Future<void> sendRequest(String userId);
  Future<FriendshipModel> acceptRequest(String requestId);
  Future<void> declineRequest(String requestId);
  Future<void> unfriend(String userId);
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
        final envelope = ApiEnvelope.page(res);
        return (items: envelope.content.map(FriendshipModel.fromJson).toList(), hasMore: envelope.hasMore);
      });

  @override
  Future<({List<FriendshipModel> items, bool hasMore})> getRequests({int page = 0}) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          VersionedEndpoints.friendRequests(),
          queryParameters: {'page': page, 'size': _pageSize},
        );
        final envelope = ApiEnvelope.page(res);
        return (items: envelope.content.map(FriendshipModel.fromJson).toList(), hasMore: envelope.hasMore);
      });

  @override
  Future<void> sendRequest(String userId) =>
      _guard(() => _dio.post<void>(VersionedEndpoints.sendFriendRequest(userId)));

  @override
  Future<FriendshipModel> acceptRequest(String requestId) => _guard(() async {
        final res =
            await _dio.put<Map<String, dynamic>>(VersionedEndpoints.acceptFriendRequest(requestId));
        return FriendshipModel.fromJson(ApiEnvelope.data(res));
      });

  @override
  Future<void> declineRequest(String requestId) =>
      _guard(() => _dio.put<void>(VersionedEndpoints.declineFriendRequest(requestId)));

  @override
  Future<void> unfriend(String userId) => _guard(() => _dio.delete<void>(VersionedEndpoints.unfriend(userId)));

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : ErrorHandler.fromDioException(e);
    }
  }
}
