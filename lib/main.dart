import 'bootstrap.dart';
import 'core/config/app_config.dart';

/// The only entrypoint this app ships — single-environment by design, no
/// dev/staging/prod split. Points at the only backend that actually exists
/// today: https://api.yello.cachewraith.com (Swagger UI: /docs, raw spec:
/// /docs/json). Repoint [AppConfig.defaultBaseUrl] if/when a dedicated
/// production host is stood up — the notification background isolates read
/// the same constant, so the URL lives there rather than here.
void main() {
  bootstrap(baseUrl: AppConfig.defaultBaseUrl);
}
