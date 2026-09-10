import 'package:dio/dio.dart';

import '../../error/error_handler.dart';

/// Last interceptor in the chain: normalizes every [DioException] into one
/// carrying an already-translated [AppException] in `error`, so repositories
/// only ever need `ErrorHandler.toFailure(e.error)` — never a Dio-specific
/// switch of their own.
class AppErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final appException = ErrorHandler.fromDioException(err);
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: appException,
        stackTrace: err.stackTrace,
        message: appException.message,
      ),
    );
  }
}
