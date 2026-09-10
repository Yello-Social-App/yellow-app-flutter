import 'api_version.dart';

/// Turns a bare resource path + [ApiVersion] into the full `/api/vN/...`
/// path Dio's `baseUrl` gets joined against. Centralizing this means bumping
/// the backend's default version, or moving one endpoint to a new version
/// ahead of the rest, is a one-line change here instead of a grep-and-edit
/// across every repository.
class EndpointResolver {
  /// Path segment every versioned route sits under, before the version
  /// segment (`/api/v2/...`).
  static const String _apiRoot = '/api';

  String resolve(String path, [ApiVersion version = ApiVersion.latest]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$_apiRoot/${version.segment}$normalized';
  }
}
