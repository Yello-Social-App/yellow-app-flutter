/// Network-layer constants. Endpoint *paths* live in
/// `core/network/api_versioning/versioned_endpoints.dart` — this file holds
/// only cross-cutting HTTP concerns.
abstract final class ApiConstants {
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);

  static const int maxRetries = 2;
  static const Duration retryBaseDelay = Duration(milliseconds: 500);

  // No `headerApiVersion`: API version is carried by the URL path segment
  // (see `EndpointResolver`), and the server's CORS allow-list accepts only
  // Accept, Authorization, Content-Type and X-Requested-With.
  static const String headerAuthorization = 'Authorization';
  static const String headerRequestId = 'X-Request-Id';
  static const String headerContentType = 'Content-Type';
  static const String contentTypeJson = 'application/json';

  /// Certificate pin fingerprints (SHA-256, base64), keyed by host.
  /// PLACEHOLDER — replace with the real backend's leaf/intermediate pins
  /// before shipping prod (see `core/security/certificate_pinning.dart`).
  static const Map<String, List<String>> pinnedCertificates = {
    // 'api.yello.cachewraith.com': [
    //   'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
    // ],
  };
}
