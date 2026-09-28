import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/security/private_network_guard.dart';
import '../models/link_preview_model.dart';

abstract interface class LinkPreviewRemoteDataSource {
  /// Reads enough of [url] to find its Open Graph tags. Throws an
  /// [AppException] for anything that isn't a readable public web page.
  Future<LinkPreviewModel> fetch(String url);
}

/// Fetches a page a user linked to, far enough to read its `<head>`.
///
/// **Deliberately not on [ApiClient]'s Dio**, for the same reason the update
/// channel isn't (`settings/data/datasources/app_update_remote_datasource.dart`):
/// `AuthInterceptor` attaches the session's bearer token to every request it
/// sees, and these requests go to whatever host an author typed into a post.
/// A bare [Dio] with no interceptors is the point, not an oversight.
///
/// Three more constraints come from the same place — the URL is untrusted
/// input and the fetch runs on the reader's phone:
///
/// - **every hop is checked** against [PrivateNetworkGuard], including each
///   redirect target, which is why redirects are followed by hand instead of
///   by Dio;
/// - **the read is capped** at [_maxBytes]; the tags are in the `<head>`, and
///   nothing here should pull a 40 MB page down a reader's mobile data;
/// - **no cookies, no credentials, no auth header** ever leave with it.
class LinkPreviewRemoteDataSourceImpl implements LinkPreviewRemoteDataSource {
  LinkPreviewRemoteDataSourceImpl([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              // Short: a card nobody is waiting for must not hold a slot on
              // the connection for long.
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 8),
              responseType: ResponseType.stream,
              followRedirects: false,
              validateStatus: (status) => status != null && status < 600,
              headers: {
                // Honest, and shaped like the crawler UA sites already
                // special-case for Open Graph.
                'User-Agent': 'Mozilla/5.0 (compatible; YelloLinkPreview/1.0)',
                'Accept': 'text/html,application/xhtml+xml',
                'Accept-Encoding': 'identity',
              },
            ),
          );

  final Dio _dio;

  static const int _maxBytes = 64 * 1024;
  static const int _maxRedirects = 3;

  @override
  Future<LinkPreviewModel> fetch(String url) async {
    var target = _checked(url);

    for (var hop = 0; hop <= _maxRedirects; hop++) {
      final Response<ResponseBody> response;
      try {
        response = await _dio.getUri<ResponseBody>(target);
      } on DioException catch (e) {
        throw _asException(e);
      }

      final status = response.statusCode ?? 0;
      final body = response.data;

      if (status >= 300 && status < 400) {
        final location = response.headers.value('location');
        await body?.stream.drain<void>();
        if (location == null || location.trim().isEmpty) {
          throw const ServerException('That link redirected to nowhere.');
        }
        target = _checked(target.resolve(location.trim()).toString());
        continue;
      }

      if (status != 200) {
        await body?.stream.drain<void>();
        throw ServerException('That link answered $status.', statusCode: status);
      }

      final contentType = (response.headers.value('content-type') ?? '').toLowerCase();
      // A link straight to a picture is its own preview — no markup to read.
      if (contentType.startsWith('image/')) {
        await body?.stream.drain<void>();
        return LinkPreviewModel.forImage(url);
      }
      if (!contentType.contains('html') && !contentType.contains('xml')) {
        await body?.stream.drain<void>();
        throw const ServerException('That link is not a web page.');
      }
      if (body == null) throw const ServerException('That link sent an empty page.');

      return LinkPreviewModel.fromHtml(
        await _readCapped(body),
        url: url,
        // The last hop, so a relative `og:image` resolves against the page
        // that actually served the tags.
        baseUrl: target.toString(),
      );
    }

    throw const ServerException('That link redirected too many times.');
  }

  /// Reads at most [_maxBytes] and hangs up. Breaking out of the loop cancels
  /// the subscription, which is what closes the socket.
  Future<String> _readCapped(ResponseBody body) async {
    final bytes = <int>[];
    try {
      await for (final chunk in body.stream) {
        bytes.addAll(chunk);
        if (bytes.length >= _maxBytes) break;
      }
    } on DioException catch (e) {
      throw _asException(e);
    }
    // `allowMalformed`: the cap can land in the middle of a multi-byte
    // character, and a broken glyph in a title is not worth losing the card
    // over. Pages that aren't UTF-8 come out with mangled accents — nothing
    // in the head is load-bearing enough to justify a charset decoder.
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Parses and vets a hop. Anything that is not a public `http(s)` address
  /// stops here rather than being dialled.
  static Uri _checked(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const ServerException('That link cannot be previewed.');
    }
    if (!PrivateNetworkGuard.isPubliclyRoutable(uri.host)) {
      throw const ServerException('That link points inside a private network.');
    }
    return uri;
  }

  static AppException _asException(DioException e) => switch (e.type) {
    DioExceptionType.connectionError => const NetworkException('Could not reach that link.'),
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout => const TimeoutException('That link took too long to answer.'),
    _ => ServerException(e.message ?? 'That link could not be read.', statusCode: e.response?.statusCode),
  };
}
