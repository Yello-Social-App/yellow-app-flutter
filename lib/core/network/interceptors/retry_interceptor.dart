import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

import '../../constants/api_constants.dart';
import '../../utils/logger.dart';
import '../network_info.dart';

/// Retries idempotent (GET) requests on transient failures — timeouts,
/// connection errors, and 502/503/504 — with capped exponential backoff.
/// Never retries a request that already carries a body-mutating method,
/// so a POST can't accidentally double-submit.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, this._networkInfo);

  final Dio _dio;
  final NetworkInfo _networkInfo;
  static const _retryCountKey = 'retry_count';

  bool _isRetryable(DioException err) {
    final method = err.requestOptions.method.toUpperCase();
    if (method != 'GET') return false;

    final status = err.response?.statusCode;
    final isTransientStatus = status == 502 || status == 503 || status == 504;
    final isTransientType = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;

    return isTransientStatus || isTransientType;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_retryCountKey] as int?) ?? 0;

    if (!_isRetryable(err) || attempt >= ApiConstants.maxRetries) {
      handler.next(err);
      return;
    }
    if (!await _networkInfo.isConnected) {
      handler.next(err);
      return;
    }

    final delay = ApiConstants.retryBaseDelay * pow(2, attempt);
    appLogger.i(
      'Retrying ${options.method} ${options.path} '
      '(attempt ${attempt + 1}/${ApiConstants.maxRetries}) after ${delay.inMilliseconds}ms',
    );
    await Future<void>.delayed(delay);

    try {
      options.extra[_retryCountKey] = attempt + 1;
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
