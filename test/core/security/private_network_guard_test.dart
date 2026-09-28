import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/core/security/private_network_guard.dart';

void main() {
  test('a public host is routable', () {
    expect(PrivateNetworkGuard.isPubliclyRoutable('example.com'), isTrue);
    expect(PrivateNetworkGuard.isPubliclyRoutable('news.ycombinator.com'), isTrue);
    expect(PrivateNetworkGuard.isPubliclyRoutable('8.8.8.8'), isTrue);
  });

  test('loopback and intranet names are refused', () {
    expect(PrivateNetworkGuard.isPubliclyRoutable('localhost'), isFalse);
    expect(PrivateNetworkGuard.isPubliclyRoutable('printer.local'), isFalse);
    expect(PrivateNetworkGuard.isPubliclyRoutable('db.internal'), isFalse);
    expect(PrivateNetworkGuard.isPubliclyRoutable('router'), isFalse);
    expect(PrivateNetworkGuard.isPubliclyRoutable(''), isFalse);
  });

  test('private IPv4 ranges are refused', () {
    for (final host in ['10.0.0.1', '172.16.5.4', '172.31.255.255', '192.168.0.1', '127.0.0.1', '0.0.0.0']) {
      expect(PrivateNetworkGuard.isPubliclyRoutable(host), isFalse, reason: host);
    }
  });

  test('the cloud metadata address is refused', () {
    expect(PrivateNetworkGuard.isPubliclyRoutable('169.254.169.254'), isFalse);
  });

  test('a public-looking neighbour of a private range still passes', () {
    expect(PrivateNetworkGuard.isPubliclyRoutable('172.32.0.1'), isTrue);
    expect(PrivateNetworkGuard.isPubliclyRoutable('11.0.0.1'), isTrue);
  });

  test('IPv6 loopback, link-local and unique-local are refused', () {
    for (final host in ['::1', '[::1]', 'fe80::1', 'fc00::1', 'fd12:3456::1', '::']) {
      expect(PrivateNetworkGuard.isPubliclyRoutable(host), isFalse, reason: host);
    }
  });

  test('an IPv4-mapped private address is refused through its v6 spelling', () {
    expect(PrivateNetworkGuard.isPubliclyRoutable('::ffff:192.168.0.1'), isFalse);
    expect(PrivateNetworkGuard.isPubliclyRoutable('[::ffff:10.0.0.1]'), isFalse);
  });

  test('a public IPv6 address passes', () {
    expect(PrivateNetworkGuard.isPubliclyRoutable('2606:4700:4700::1111'), isTrue);
  });
}
