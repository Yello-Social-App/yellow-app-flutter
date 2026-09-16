import 'bootstrap.dart';

/// The only entrypoint this app ships — single-environment by design, no
/// dev/staging/prod split. Points at the only backend that actually exists
/// today: https://api.yello.cachewraith.com (Swagger UI: /docs, raw spec:
/// /docs/json). Repoint [baseUrl] here if/when a dedicated production host
/// is stood up.
void main() {
  bootstrap(baseUrl: 'https://api.yello.cachewraith.com');
}
