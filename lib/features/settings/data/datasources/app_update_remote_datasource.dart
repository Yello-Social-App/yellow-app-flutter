import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/app_update.dart';

/// Reads the sideload update channel: a small `latest.json` published
/// beside each release's APK.
///
/// Deliberately **not** on [ApiClient]'s Dio. The manifest and the APK live
/// off the Yello host, and `AuthInterceptor` attaches the session's bearer
/// token to every request it sees — pointing that at a third-party download
/// host would hand the session to whoever runs it. This datasource owns a
/// bare [Dio] with no interceptors for exactly that reason.
abstract interface class AppUpdateRemoteDataSource {
  /// The published build, or `null` when the manifest is well-formed but
  /// describes nothing (an empty channel).
  Future<AppUpdate?> fetchManifest();

  /// Downloads [update]'s APK to [targetPath] and returns that path.
  Future<String> downloadApk(AppUpdate update, String targetPath, {void Function(double progress)? onProgress});
}

class AppUpdateRemoteDataSourceImpl implements AppUpdateRemoteDataSource {
  AppUpdateRemoteDataSourceImpl([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              // Short, because this runs behind a button the user is
              // watching. The APK download below overrides the receive
              // timeout — 60 MB does not arrive in 15 seconds.
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              followRedirects: true,
              // GitHub's `releases/latest/download/...` is a redirect chain,
              // and a 404 here is a normal answer ("nothing published yet"),
              // so let this datasource read the status itself.
              validateStatus: (status) => status != null && status < 500,
            ),
          );

  final Dio _dio;

  @override
  Future<AppUpdate?> fetchManifest() async {
    final Response<dynamic> response;
    try {
      response = await _dio.getUri<dynamic>(Uri.parse(AppConfig.updateManifestUrl));
    } on DioException catch (e) {
      throw _asException(e);
    }

    // No manifest published yet reads as "you are up to date", not as a
    // failure the user has to retry.
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw ServerException('The update channel answered ${response.statusCode}.', statusCode: response.statusCode);
    }

    final data = response.data;
    // A release asset is served as text/plain, so Dio hands back a String
    // rather than a decoded Map.
    final decoded = data is String ? _decode(data) : data;
    if (decoded is! Map) throw const ServerException('The update channel sent something unreadable.');

    return _parse(Map<String, dynamic>.from(decoded));
  }

  @override
  Future<String> downloadApk(
    AppUpdate update,
    String targetPath, {
    void Function(double progress)? onProgress,
  }) async {
    // Plaintext would let anyone on the path swap the file the OS installer
    // is about to execute.
    if (!update.apkUrl.startsWith('https://')) {
      throw const ServerException('That download link is not secure, so it was not opened.');
    }

    // A half-written APK from an interrupted attempt would fail to install
    // with the OS's own unhelpful message.
    final file = File(targetPath);
    if (file.existsSync()) await file.delete();

    try {
      await _dio.download(
        update.apkUrl,
        targetPath,
        // No ceiling: the transfer is minutes long on a slow connection and
        // Dio's receive timeout is per-chunk-gap, not per-download.
        options: Options(receiveTimeout: const Duration(minutes: 30)),
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
        },
      );
    } on DioException catch (e) {
      if (file.existsSync()) await file.delete();
      throw _asException(e);
    }
    return targetPath;
  }

  static dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const ServerException('The update channel sent something unreadable.');
    }
  }

  static AppUpdate? _parse(Map<String, dynamic> json) {
    final version = (json['version'] as String?)?.trim() ?? '';
    final apkUrl = (json['apkUrl'] as String?)?.trim() ?? '';
    final build = json['buildNumber'];
    final buildNumber = build is int ? build : int.tryParse('$build');

    // An empty channel, not a broken one.
    if (version.isEmpty && apkUrl.isEmpty && buildNumber == null) return null;
    if (version.isEmpty || apkUrl.isEmpty || buildNumber == null) {
      throw const ServerException('The published update is missing its version or download link.');
    }

    final size = json['sizeBytes'];
    return AppUpdate(
      version: version,
      buildNumber: buildNumber,
      apkUrl: apkUrl,
      notes: (json['notes'] as String?)?.trim() ?? '',
      sizeBytes: size is int ? size : int.tryParse('$size') ?? 0,
    );
  }

  static AppException _asException(DioException e) => switch (e.type) {
    DioExceptionType.connectionError => const NetworkException('Could not reach the update channel.'),
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout => const TimeoutException('The update channel took too long to answer.'),
    _ => ServerException(e.message ?? 'The update check failed.', statusCode: e.response?.statusCode),
  };
}
