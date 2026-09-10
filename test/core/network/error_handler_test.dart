import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/core/error/error_handler.dart';
import 'package:yello_social_app/core/error/exceptions.dart';
import 'package:yello_social_app/core/error/failures.dart';

DioException _dioError(
  DioExceptionType type, {
  int? statusCode,
  Map<String, dynamic>? responseData,
}) {
  final options = RequestOptions(path: '/test');
  return DioException(
    requestOptions: options,
    type: type,
    response: statusCode == null
        ? null
        : Response(requestOptions: options, statusCode: statusCode, data: responseData),
  );
}

void main() {
  group('ErrorHandler.fromDioException', () {
    test('maps connection timeout to TimeoutException', () {
      final result = ErrorHandler.fromDioException(_dioError(DioExceptionType.connectionTimeout));
      expect(result, isA<TimeoutException>());
    });

    test('maps connectionError to NetworkException', () {
      final result = ErrorHandler.fromDioException(_dioError(DioExceptionType.connectionError));
      expect(result, isA<NetworkException>());
    });

    test('maps a 401 response to UnauthorizedException regardless of body', () {
      final result = ErrorHandler.fromDioException(
        _dioError(DioExceptionType.badResponse, statusCode: 401),
      );
      expect(result, isA<UnauthorizedException>());
    });

    test('prefers a fieldErrors message over the top-level message', () {
      final result = ErrorHandler.fromDioException(
        _dioError(
          DioExceptionType.badResponse,
          statusCode: 400,
          responseData: {
            'success': false,
            'message': 'Validation failed',
            'code': 'VALIDATION_ERROR',
            'fieldErrors': {
              'email': ['must be a valid email address'],
            },
          },
        ),
      );
      expect(result, isA<ServerException>());
      expect(result.message, 'must be a valid email address');
      expect((result as ServerException).code, 'VALIDATION_ERROR');
    });

    test('falls back to the top-level message with no fieldErrors', () {
      final result = ErrorHandler.fromDioException(
        _dioError(
          DioExceptionType.badResponse,
          statusCode: 500,
          responseData: {'success': false, 'message': 'Something broke', 'code': 'INTERNAL_ERROR'},
        ),
      );
      expect(result.message, 'Something broke');
    });
  });

  group('ErrorHandler.toFailure', () {
    test('maps UnauthorizedException to AuthFailure', () {
      expect(ErrorHandler.toFailure(const UnauthorizedException()), isA<AuthFailure>());
    });

    test('maps NetworkException to NetworkFailure', () {
      expect(ErrorHandler.toFailure(const NetworkException()), isA<NetworkFailure>());
    });

    test('maps a non-AppException to UnknownFailure', () {
      expect(ErrorHandler.toFailure(Exception('boom')), isA<UnknownFailure>());
    });
  });
}
