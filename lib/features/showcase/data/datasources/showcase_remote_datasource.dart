import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_versioning/versioned_endpoints.dart';
import '../../domain/entities/project_entity.dart';
import '../models/project_model.dart';

abstract interface class ShowcaseRemoteDataSource {
  /// `GET /projects?sort=&tech=&featured=&page=&size=` (offset-paged).
  Future<({List<ProjectModel> items, bool hasMore})> getProjects({
    ProjectSort sort,
    String? tech,
    bool? featured,
    int page,
  });

  /// `GET /projects/tech?limit=` — **not paged**: `data` is a bare array, so
  /// this reads it with `ApiEnvelope.list` rather than `.page`.
  Future<List<TechCountModel>> getTech({int limit});

  Future<ProjectModel> getProject(String projectId);

  /// `POST /projects`. Note the create contract has **no** `description`
  /// field even though the response carries one — see
  /// [ProjectEntity.description].
  Future<ProjectModel> publishProject({
    required String name,
    required String tagline,
    required String emoji,
    List<String> tech,
    String? repoUrl,
    String? liveUrl,
  });

  /// `POST /projects/{id}/views` — answers `204` with no body, and is
  /// rate-limited server-side (a repeat inside the window is a `429`, not a
  /// second counted view).
  Future<void> recordView(String projectId);

  /// POST likes, DELETE unlikes — same path, both answering `ProjectLike`.
  Future<ProjectLikeResultModel> like(String projectId);
  Future<ProjectLikeResultModel> unlike(String projectId);
}

class ShowcaseRemoteDataSourceImpl implements ShowcaseRemoteDataSource {
  ShowcaseRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  static const _pageSize = 20;

  @override
  Future<({List<ProjectModel> items, bool hasMore})> getProjects({
    ProjectSort sort = ProjectSort.trending,
    String? tech,
    bool? featured,
    int page = 0,
  }) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      VersionedEndpoints.projects(),
      queryParameters: {
        'sort': sort.wireValue,
        'tech': ?tech,
        'featured': ?featured,
        'page': page,
        'size': _pageSize,
      },
    );
    final envelope = ApiEnvelope.page(res);
    return (items: envelope.content.map(ProjectModel.fromJson).toList(), hasMore: envelope.hasMore);
  });

  @override
  Future<List<TechCountModel>> getTech({int limit = 10}) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      VersionedEndpoints.projectsTech(),
      queryParameters: {'limit': limit},
    );
    return ApiEnvelope.list(res).map(TechCountModel.fromJson).toList();
  });

  @override
  Future<ProjectModel> getProject(String projectId) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(VersionedEndpoints.project(projectId));
    return ProjectModel.fromJson(ApiEnvelope.data(res));
  });

  @override
  Future<ProjectModel> publishProject({
    required String name,
    required String tagline,
    required String emoji,
    List<String> tech = const [],
    String? repoUrl,
    String? liveUrl,
  }) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      VersionedEndpoints.projects(),
      data: {
        'name': name,
        'tagline': tagline,
        'emoji': emoji,
        if (tech.isNotEmpty) 'tech': tech,
        'repoUrl': ?repoUrl,
        'liveUrl': ?liveUrl,
      },
    );
    return ProjectModel.fromJson(ApiEnvelope.data(res));
  });

  @override
  Future<void> recordView(String projectId) =>
      _guard(() => _dio.post<void>(VersionedEndpoints.projectViews(projectId)));

  @override
  Future<ProjectLikeResultModel> like(String projectId) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(VersionedEndpoints.projectLike(projectId));
    return ProjectLikeResultModel.fromJson(ApiEnvelope.data(res));
  });

  @override
  Future<ProjectLikeResultModel> unlike(String projectId) => _guard(() async {
    final res = await _dio.delete<Map<String, dynamic>>(VersionedEndpoints.projectLike(projectId));
    return ProjectLikeResultModel.fromJson(ApiEnvelope.data(res));
  });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : ErrorHandler.fromDioException(e);
    }
  }
}
