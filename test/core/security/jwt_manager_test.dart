import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/core/security/jwt_manager.dart';

import '../../helpers/mock_data.dart';

void main() {
  late JwtManager jwtManager;

  setUp(() {
    jwtManager = JwtManagerImpl();
  });

  group('isExpired', () {
    test('returns false for a token expiring well in the future', () {
      final token = buildFakeJwt(expSecondsFromNow: 3600);
      expect(jwtManager.isExpired(token), isFalse);
    });

    test('returns true for a token that already expired', () {
      final token = buildFakeJwt(expSecondsFromNow: -60);
      expect(jwtManager.isExpired(token), isTrue);
    });

    test('treats a token inside the clock-skew leeway as expired', () {
      // Expires in 10s — inside JwtManagerImpl's 30s leeway.
      final token = buildFakeJwt(expSecondsFromNow: 10);
      expect(jwtManager.isExpired(token), isTrue);
    });

    test('fails closed (treated as expired) for garbage input', () {
      expect(jwtManager.isExpired('not-a-jwt'), isTrue);
    });
  });

  group('timeUntilExpiry', () {
    test('is positive and roughly matches the requested lifetime', () {
      final token = buildFakeJwt(expSecondsFromNow: 3600);
      final remaining = jwtManager.timeUntilExpiry(token);
      expect(remaining, isNotNull);
      expect(remaining!.inSeconds, greaterThan(3500));
      expect(remaining.inSeconds, lessThanOrEqualTo(3600));
    });

    test('is null for an undecodable token', () {
      expect(jwtManager.timeUntilExpiry('garbage'), isNull);
    });
  });
}
