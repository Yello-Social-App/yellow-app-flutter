import 'package:dio/dio.dart';

/// Every response from the live backend is wrapped as
/// `{ success, data, timestamp }` (errors as `{ success, code, message,
/// fieldErrors, path, timestamp }` — see `ErrorHandler`). Data sources call
/// [ApiEnvelope.data] / [.list] right after the Dio call instead of each
/// re-deriving the same `res.data['data']` cast.
abstract final class ApiEnvelope {
  /// Unwraps a single-object payload: `{ data: {...} }` → the inner map.
  static Map<String, dynamic> data(Response<dynamic> response) {
    final body = response.data as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }

  /// Unwraps a plain array payload: `{ data: [...] }` → the inner list.
  static List<Map<String, dynamic>> list(Response<dynamic> response) {
    final body = response.data as Map<String, dynamic>;
    final items = body['data'] as List<dynamic>;
    return items.cast<Map<String, dynamic>>();
  }

  /// Unwraps a `PageResponse<T>` payload (`{ data: { content, page, size,
  /// totalElements, totalPages, last } }`) used by the classic
  /// page-number-paginated endpoints (friends, notifications, comments,
  /// a user's posts).
  static PageEnvelope page(Response<dynamic> response) {
    final page = data(response);
    return PageEnvelope(
      content: (page['content'] as List<dynamic>).cast<Map<String, dynamic>>(),
      hasMore: !(page['last'] as bool? ?? true),
      page: page['page'] as int? ?? 0,
      totalElements: page['totalElements'] as int? ?? 0,
    );
  }

  /// Unwraps a `CursorPageResponse<T>` payload (`{ data: { content,
  /// hasMore, nextCursor } }`), used by `/feed`.
  static CursorEnvelope cursorPage(Response<dynamic> response) {
    final page = data(response);
    return CursorEnvelope(
      content: (page['content'] as List<dynamic>).cast<Map<String, dynamic>>(),
      hasMore: page['hasMore'] as bool? ?? false,
      nextCursor: page['nextCursor'] as String?,
    );
  }
}

class PageEnvelope {
  const PageEnvelope({
    required this.content,
    required this.hasMore,
    required this.page,
    required this.totalElements,
  });

  final List<Map<String, dynamic>> content;
  final bool hasMore;
  final int page;
  final int totalElements;
}

class CursorEnvelope {
  const CursorEnvelope({required this.content, required this.hasMore, this.nextCursor});

  final List<Map<String, dynamic>> content;
  final bool hasMore;
  final String? nextCursor;
}
