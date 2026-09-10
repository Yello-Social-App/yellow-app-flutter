import 'package:dio/dio.dart';

import '../../utils/logger.dart';

/// Human-readable request/response logging, gated by [enabled] so release
/// builds (see `AppConfig.enableLogging`) never log request/response
/// bodies that may carry tokens or PII.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({required this.enabled});

  final bool enabled;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      appLogger.d('→ ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (enabled) {
      appLogger.d(
        '← ${response.statusCode} ${response.requestOptions.uri}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      appLogger.w(
        '✗ ${err.requestOptions.method} ${err.requestOptions.uri} — '
        '${err.response?.statusCode ?? err.type}',
      );
    }
    handler.next(err);
  }
}
