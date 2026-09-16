import 'package:dio/dio.dart';

import 'exceptions.dart';
import 'failures.dart';

/// Central translation point between transport-level errors and the app's
/// own [AppException] / [Failure] vocabulary. Interceptors and repositories
/// call this instead of pattern-matching Dio/platform errors themselves.
abstract final class ErrorHandler {
  static AppException fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badCertificate:
        return const AppException(
          'Could not verify the server\'s identity.',
          code: 'cert_pin_failed',
        );
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status == 401) return const UnauthorizedException();
        final serverMessage = _extractServerMessage(e.response?.data);
        final code = _extractErrorCode(e.response?.data);
        // A 413 is often thrown by a proxy in front of the app (oversized
        // multipart upload) before the request ever reaches the backend's
        // own JSON error envelope, so `serverMessage` is usually null here
        // — fall back to something actionable instead of "Server error
        // (413)." (see `postImageMaxDimension` in `AppConstants`, which
        // keeps normal uploads from hitting this).
        final fallback = status == 413
            ? 'That upload is too large. Try fewer or smaller photos.'
            : 'Server error ($status).';
        return ServerException(
          serverMessage ?? fallback,
          statusCode: status,
          code: code,
        );
      case DioExceptionType.cancel:
        return const AppException('Request cancelled.', code: 'cancelled');
      case DioExceptionType.unknown:
        return AppException(e.message ?? 'Unknown network error.');
    }
  }

  /// The backend's `ApiErrorResponse` shape is `{ success, code, message,
  /// fieldErrors, path, timestamp }` — prefer the first field-level message
  /// when present (more actionable than the generic top-level one), falling
  /// back to `message` itself.
  static String? _extractServerMessage(dynamic data) {
    if (data is! Map) return null;
    final fieldErrors = data['fieldErrors'];
    if (fieldErrors is Map && fieldErrors.isNotEmpty) {
      final firstField = fieldErrors.values.first;
      if (firstField is List && firstField.isNotEmpty) {
        return firstField.first as String;
      }
    }
    if (data['message'] is String) return data['message'] as String;
    return null;
  }

  static String? _extractErrorCode(dynamic data) {
    if (data is Map && data['code'] is String) return data['code'] as String;
    return null;
  }

  /// Maps a data-layer [AppException] to the domain-facing [Failure] a
  /// repository returns from its `Either<Failure, T>`.
  static Failure toFailure(Object error) {
    return switch (error) {
      UnauthorizedException e => AuthFailure(e.message),
      NetworkException e => NetworkFailure(e.message),
      TimeoutException e => TimeoutFailure(e.message),
      CacheException e => CacheFailure(e.message),
      ServerException e => ServerFailure(e.message),
      AppException e => UnknownFailure(e.message),
      _ => const UnknownFailure(),
    };
  }
}
