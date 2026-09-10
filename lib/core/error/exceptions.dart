/// Data-layer error type. Data sources (remote/local) throw these; nothing
/// above the repository boundary should ever catch a raw [DioException] or
/// platform exception directly — `error_handler.dart` / repositories
/// translate to [AppException], and repositories translate again to
/// [Failure] for the domain layer.
class AppException implements Exception {
  const AppException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => 'AppException($statusCode, $code): $message';
}

class ServerException extends AppException {
  const ServerException(super.message, {super.statusCode, super.code});
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection.']);
}

class TimeoutException extends AppException {
  const TimeoutException([super.message = 'Request timed out.']);
}

class CacheException extends AppException {
  const CacheException([super.message = 'Local read/write failed.']);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Unauthorized.'])
      : super(statusCode: 401);
}
