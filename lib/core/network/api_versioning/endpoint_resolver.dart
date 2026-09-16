import 'api_version.dart';

/// Turns a bare resource path + [ApiVersion] into the full `/vN/...` path
/// Dio's `baseUrl` gets joined against. Centralizing this means bumping the
/// backend's default version, or moving one endpoint to a new version ahead
/// of the rest, is a one-line change here instead of a grep-and-edit across
/// every repository.
///
/// Note there is **no** `/api` prefix: the Laravel backend mounts every
/// route directly under the version segment, so the register endpoint is
/// `https://api.yello.cachewraith.com/v1/auth/register`. Prefixing `/api`
/// returns `404 RESOURCE_NOT_FOUND` for every call.
class EndpointResolver {
  String resolve(String path, [ApiVersion version = ApiVersion.latest]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return '/${version.segment}$normalized';
  }
}
