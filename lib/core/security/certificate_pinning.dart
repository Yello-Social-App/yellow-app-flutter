import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart' show HttpClientAdapter;
import 'package:dio/io.dart';

import '../constants/api_constants.dart';
import '../utils/logger.dart';

/// OWASP Mobile **M5 — Insecure Communication**: pins the server's leaf
/// certificate by SHA-256 fingerprint on top of normal TLS chain
/// validation, so a compromised or coerced CA in the device's trust store
/// (a mis-issued cert, a corporate MITM proxy, a malicious root pushed to a
/// managed device) isn't enough to intercept API traffic — the fingerprint
/// must also match one pinned in [ApiConstants.pinnedCertificates].
///
/// `IOHttpClientAdapter.validateCertificate` only runs *after* the platform
/// has already accepted the chain (see its dartdoc), so this is additive,
/// fail-closed pinning, not a replacement for normal certificate checks.
abstract final class CertificatePinning {
  /// Builds the adapter to assign to `Dio.httpClientAdapter`. When
  /// [ApiConstants.pinnedCertificates] has no entry for a given host, that
  /// host is left to ordinary TLS validation (this lets dev/staging run
  /// against backends whose certs aren't pinned yet, without weakening the
  /// production host once pins are added).
  static HttpClientAdapter buildAdapter() {
    return IOHttpClientAdapter(
      validateCertificate: (certificate, host, port) {
        final pins = ApiConstants.pinnedCertificates[host];
        if (pins == null || pins.isEmpty) return true;
        if (certificate == null) return false;

        final fingerprint =
            'sha256/${base64.encode(sha256.convert(certificate.der).bytes)}';
        final matched = pins.contains(fingerprint);
        if (!matched) {
          appLogger.e('Certificate pin mismatch for $host: got $fingerprint');
        }
        return matched;
      },
    );
  }
}
