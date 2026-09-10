import 'bootstrap.dart';

/// The only entrypoint this app ships — single-environment by design, no
/// dev/staging/prod split. Points at the only backend that actually exists
/// today: https://dev.yello-api.cachewraith.com (swagger:
/// /swagger-ui/index.html). Repoint [baseUrl] here if/when a dedicated
/// production host is stood up.
void main() {
  bootstrap(baseUrl: 'https://dev.yello-api.cachewraith.com');
}
