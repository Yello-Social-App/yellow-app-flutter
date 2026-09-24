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

  /// 400 — you tried to report your own post.
  static const String cannotReportOwnPost = 'CANNOT_REPORT_OWN_POST';

  /// 400 — you tried to mute yourself.
  static const String cannotMuteSelf = 'CANNOT_MUTE_SELF';

  /// 400 — you tried to reply to your own story. The viewer hides the reply
  /// box on your own stories, so this is a race (someone else's story you
  /// were reading turned out to be yours) rather than a reachable button.
  static const String cannotReplyToOwnStory = 'CANNOT_REPLY_TO_OWN_STORY';

  /// 409 — you already have an `UNDER_REVIEW` report on this post. Not an
  /// error the user can act on: the report they wanted already exists, so
  /// `ReportPostCubit` reads this code and reports success ("already
  /// reported") rather than showing a failure.
  static const String reportAlreadyExists = 'REPORT_ALREADY_EXISTS';

  /// 409 — moderators only (`PATCH /admin/reports/{id}` on a report that was
  /// already decided). This app never calls that route; the code is listed
  /// for completeness of the vocabulary.
  static const String reportAlreadyResolved = 'REPORT_ALREADY_RESOLVED';
}

/// `yello-chat`'s own error vocabulary (`ErrorBody.code`). A different
/// service with a different envelope — `{code, message, details}` and no
/// `success` flag — but [ErrorHandler] reads `code` and `message` off the
/// body the same way, so only the mapping to a [Failure] needs to know.
/// `INTERNAL_ERROR` is shared with yello-api and lives in [ApiErrorCodes].
abstract final class ChatErrorCodes {
  /// 400 (bad input — `details.issues[]` lists the paths) or 413 (a file
  /// over `CHAT_ATTACHMENT_MAX_BYTES`).
  static const String validationError = 'VALIDATION_ERROR';
  static const String unauthorized = 'UNAUTHORIZED';

  /// A block between the two users, or the viewer lacks the right (not the
  /// sender, not a group admin, not the owner).
  static const String forbidden = 'FORBIDDEN';

  /// Unknown id — or the viewer is not a member; ids cannot be probed.
  static const String notFound = 'NOT_FOUND';

  /// Already a member; invite already answered or no longer valid.
  static const String conflict = 'CONFLICT';
  static const String rateLimited = 'RATE_LIMITED';

  /// Attachments / group photos are not configured on this deployment.
  static const String unavailable = 'UNAVAILABLE';
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
    ApiErrorCodes.cannotReportOwnPost => 'You cannot report your own post.',
    ApiErrorCodes.cannotMuteSelf => 'You cannot mute yourself.',
    ApiErrorCodes.cannotReplyToOwnStory => 'You cannot reply to your own story.',
    ApiErrorCodes.reportAlreadyExists => 'You have already reported this post.',
    ApiErrorCodes.reportAlreadyResolved => 'That report has already been decided.',
    ApiErrorCodes.postNotVisible => 'That post is not visible to you.',
    ApiErrorCodes.accessDenied => 'You do not have access to that.',
    ApiErrorCodes.rateLimitExceeded => 'Slow down a moment, then try again.',
    ApiErrorCodes.resourceNotFound => 'That is no longer there.',
    ChatErrorCodes.forbidden => 'You cannot do that here.',
    ChatErrorCodes.notFound => 'That is no longer there.',
    ChatErrorCodes.conflict => 'That has already been done.',
    ChatErrorCodes.rateLimited => 'Slow down a moment, then try again.',
    ChatErrorCodes.unavailable => 'File sharing is not available right now.',
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
    ApiErrorCodes.rateLimitExceeded ||
    ApiErrorCodes.cannotReportOwnPost ||
    ApiErrorCodes.cannotMuteSelf ||
    ApiErrorCodes.reportAlreadyExists ||
    ApiErrorCodes.reportAlreadyResolved ||
    // yello-chat's 4xx family: every one of these carries a message a user
    // can act on ("Only the sender can change this message", "The group is
    // full"), which a ServerFailure would flatten into "Something went
    // wrong on our end."
    ChatErrorCodes.validationError ||
    ChatErrorCodes.forbidden ||
    ChatErrorCodes.notFound ||
    ChatErrorCodes.conflict ||
    ChatErrorCodes.rateLimited ||
    ChatErrorCodes.unavailable => ValidationFailure(e.message, code: e.code),
    ApiErrorCodes.accountNotVerified ||
    ApiErrorCodes.accountSuspended ||
    ApiErrorCodes.invalidCredentials ||
    ApiErrorCodes.tokenInvalid ||
    ApiErrorCodes.tokenExpired ||
    ApiErrorCodes.tokenRevoked ||
    ChatErrorCodes.unauthorized => AuthFailure(e.message),
    _ => null,
  };
}
