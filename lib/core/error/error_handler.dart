import 'package:dio/dio.dart';

import 'exceptions.dart';
import 'failures.dart';

/// Every value of the backend's `ErrorCode` enum, as named constants so call
/// sites branch on one of these instead of an inline string literal that
/// silently stops matching when the spec renames a code.
///
/// Kept in the spec's own order (see the `ErrorCode` schema in
/// `/docs/json?api-docs.json`). Clients branch on `code`, never on
/// `message` — the message is human copy and may be reworded at any time.
abstract final class ApiErrorCodes {
  static const String validationFailed = 'VALIDATION_FAILED';
  static const String resourceNotFound = 'RESOURCE_NOT_FOUND';
  static const String emailAlreadyUsed = 'EMAIL_ALREADY_USED';
  static const String usernameAlreadyUsed = 'USERNAME_ALREADY_USED';
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String accountNotVerified = 'ACCOUNT_NOT_VERIFIED';
  static const String accountSuspended = 'ACCOUNT_SUSPENDED';
  static const String tokenInvalid = 'TOKEN_INVALID';
  static const String tokenExpired = 'TOKEN_EXPIRED';
  static const String tokenRevoked = 'TOKEN_REVOKED';
  static const String rateLimitExceeded = 'RATE_LIMIT_EXCEEDED';
  static const String accessDenied = 'ACCESS_DENIED';
  static const String postNotVisible = 'POST_NOT_VISIBLE';
  static const String communityMembershipRequired = 'COMMUNITY_MEMBERSHIP_REQUIRED';
  static const String otpInvalid = 'OTP_INVALID';
  static const String otpTooManyAttempts = 'OTP_TOO_MANY_ATTEMPTS';
  static const String resetTokenInvalid = 'RESET_TOKEN_INVALID';
  static const String invalidImage = 'INVALID_IMAGE';
  static const String alreadyReposted = 'ALREADY_REPOSTED';
  static const String friendRequestConflict = 'FRIEND_REQUEST_CONFLICT';
  static const String usernameChangeCooldown = 'USERNAME_CHANGE_COOLDOWN';
  static const String payloadTooLarge = 'PAYLOAD_TOO_LARGE';
  static const String internalError = 'INTERNAL_ERROR';
}

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
            : _messageForCode(code) ?? 'Server error ($status).';
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

  /// Human copy for the codes whose own server message is either absent
  /// (a proxy answered before the backend's envelope was built) or too terse
  /// to show a user as-is. Only consulted when [_extractServerMessage] found
  /// nothing — the backend's own wording wins whenever it sent any.
  static String? _messageForCode(String? code) => switch (code) {
    ApiErrorCodes.communityMembershipRequired => 'Join this community before posting in it.',
    ApiErrorCodes.usernameChangeCooldown => 'You changed your username recently — try again later.',
    ApiErrorCodes.payloadTooLarge => 'That upload is too large. Try fewer or smaller photos.',
    ApiErrorCodes.invalidImage => 'Choose a JPEG, PNG, GIF, or WebP image.',
    ApiErrorCodes.alreadyReposted => 'You have already reposted this.',
    ApiErrorCodes.friendRequestConflict => 'There is already a request between you two.',
    ApiErrorCodes.postNotVisible => 'That post is not visible to you.',
    ApiErrorCodes.accessDenied => 'You do not have access to that.',
    ApiErrorCodes.rateLimitExceeded => 'Slow down a moment, then try again.',
    ApiErrorCodes.resourceNotFound => 'That is no longer there.',
    _ => null,
  };

  /// Maps a data-layer [AppException] to the domain-facing [Failure] a
  /// repository returns from its `Either<Failure, T>`.
  ///
  /// The error `code` is consulted before the exception's Dart type: the
  /// backend answers a whole family of *user-correctable* rejections with a
  /// 4xx that would otherwise flatten into a [ServerFailure] ("Something
  /// went wrong on our end."), which reads as a backend outage for what is
  /// really "pick a different username". Those become [ValidationFailure]s,
  /// carrying the server's own message through unchanged.
  static Failure toFailure(Object error) {
    if (error is AppException) {
      final mapped = _failureForCode(error);
      if (mapped != null) return mapped;
    }
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

  static Failure? _failureForCode(AppException e) => switch (e.code) {
    ApiErrorCodes.validationFailed ||
    ApiErrorCodes.emailAlreadyUsed ||
    ApiErrorCodes.usernameAlreadyUsed ||
    ApiErrorCodes.usernameChangeCooldown ||
    ApiErrorCodes.otpInvalid ||
    ApiErrorCodes.otpTooManyAttempts ||
    ApiErrorCodes.resetTokenInvalid ||
    ApiErrorCodes.invalidImage ||
    ApiErrorCodes.payloadTooLarge ||
    ApiErrorCodes.alreadyReposted ||
    ApiErrorCodes.friendRequestConflict ||
    ApiErrorCodes.communityMembershipRequired ||
    ApiErrorCodes.rateLimitExceeded => ValidationFailure(e.message),
    ApiErrorCodes.accountNotVerified ||
    ApiErrorCodes.accountSuspended ||
    ApiErrorCodes.invalidCredentials ||
    ApiErrorCodes.tokenInvalid ||
    ApiErrorCodes.tokenExpired ||
    ApiErrorCodes.tokenRevoked => AuthFailure(e.message),
    _ => null,
  };
}
