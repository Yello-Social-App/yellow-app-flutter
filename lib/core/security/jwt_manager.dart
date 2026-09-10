import 'package:jwt_decoder/jwt_decoder.dart';

/// OWASP Mobile **M10 — Insufficient Cryptography** / **M6 — Insecure
/// Authorization**: this class never verifies a JWT's *signature* (that
/// trust boundary belongs to the backend, which issued and signs it) — it
/// only reads the already-trusted token's claims to make local decisions
/// (is it expired, when does it expire) so [AuthInterceptor] never sends a
/// token it already knows is dead, and [SessionManager] can proactively
/// sign the user out at expiry instead of waiting on a 401 round-trip.
abstract interface class JwtManager {
  bool isExpired(String token);
  DateTime? expiryOf(String token);
  Map<String, dynamic>? claimsOf(String token);
  Duration? timeUntilExpiry(String token);
}

class JwtManagerImpl implements JwtManager {
  /// Treat a token as expired slightly before its real `exp` so a request
  /// built "now" doesn't land on the server a few hundred ms later, already
  /// expired.
  static const _clockSkewLeeway = Duration(seconds: 30);

  @override
  bool isExpired(String token) {
    try {
      return JwtDecoder.isExpired(token) ||
          (timeUntilExpiry(token)?.compareTo(_clockSkewLeeway) ?? 1) <= 0;
    } catch (_) {
      // An undecodable token is treated as expired — fail closed.
      return true;
    }
  }

  @override
  DateTime? expiryOf(String token) {
    try {
      return JwtDecoder.getExpirationDate(token);
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, dynamic>? claimsOf(String token) {
    try {
      return JwtDecoder.decode(token);
    } catch (_) {
      return null;
    }
  }

  @override
  Duration? timeUntilExpiry(String token) {
    final expiry = expiryOf(token);
    if (expiry == null) return null;
    return expiry.difference(DateTime.now());
  }
}
