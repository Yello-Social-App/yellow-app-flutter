import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_versioning/versioned_endpoints.dart';
import '../models/user_search_result_model.dart';

abstract interface class SearchRemoteDataSource {
  /// `GET /users/search?q=&page=` — offset-paged. Note there is **no** `size`
  /// parameter on this route (unlike every other paged endpoint); the page
  /// size is the server's choice, so `hasMore` is the only thing worth
  /// reading off the envelope.
  Future<({List<UserSearchResultModel> items, bool hasMore})> searchUsers(
    String query, {
    int page,
  });
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  SearchRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  @override
  Future<({List<UserSearchResultModel> items, bool hasMore})> searchUsers(
    String query, {
    int page = 0,
  }) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      VersionedEndpoints.usersSearch(),
      queryParameters: {'q': query, 'page': page},
    );
    final envelope = ApiEnvelope.page(res);
    return (
      items: envelope.content.map(UserSearchResultModel.fromJson).toList(),
      hasMore: envelope.hasMore,
    );
  });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : ErrorHandler.fromDioException(e);
    }
  }
}
