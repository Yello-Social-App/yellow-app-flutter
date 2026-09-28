import 'dart:io';

/// Keeps a link that came out of someone's post from making the *reader's*
/// phone talk to the reader's own network.
///
/// Link previews (`features/link_preview`) fetch a URL an author typed, and
/// that fetch runs on the reader's device, inside their home or office
/// Wi-Fi. Left open, a post containing `http://192.168.0.1/reboot` — or a
/// page that redirects there, or an `og:image` pointing at it — reaches an
/// address the author could never reach themselves. It is OWASP A01's SSRF
/// shape with the arrow turned around: the confused deputy is the phone.
///
/// So every host is checked before it is fetched, on every redirect hop, and
/// again for the image URL a page hands back. The check is a rejection list
/// of addresses that cannot be a public web server rather than an allowlist
/// of the whole internet.
abstract final class PrivateNetworkGuard {
  /// Names that never belong to a public host, and suffixes reserved for
  /// intranet use.
  static const List<String> _privateSuffixes = ['.localhost', '.local', '.internal', '.home.arpa', '.lan'];

  static bool isPubliclyRoutable(String host) {
    final name = host.trim().toLowerCase();
    if (name.isEmpty) return false;

    final address = InternetAddress.tryParse(_unwrapIpv6(name));
    if (address != null) return _isPublicAddress(address);

    if (name == 'localhost') return false;
    if (_privateSuffixes.any(name.endsWith)) return false;
    // A single-label host (`router`, `nas`) resolves through the local
    // resolver, so it is an intranet name by definition.
    return name.contains('.');
  }

  /// `Uri.host` keeps the brackets on a literal IPv6 authority.
  static String _unwrapIpv6(String host) =>
      host.startsWith('[') && host.endsWith(']') ? host.substring(1, host.length - 1) : host;

  static bool _isPublicAddress(InternetAddress address) {
    if (address.isLoopback || address.isLinkLocal || address.isMulticast) return false;
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) return _isPublicV4(bytes);

    // An IPv4-mapped address (`::ffff:192.168.0.1`) is a v4 destination
    // wearing a v6 hat — check the four bytes it actually dials.
    if (bytes.length == 16 && _isIpv4Mapped(bytes)) return _isPublicV4(bytes.sublist(12));

    // fc00::/7 unique-local, and the unspecified address.
    if (bytes.isNotEmpty && (bytes[0] & 0xFE) == 0xFC) return false;
    return bytes.any((byte) => byte != 0);
  }

  static bool _isIpv4Mapped(List<int> bytes) {
    for (var i = 0; i < 10; i++) {
      if (bytes[i] != 0) return false;
    }
    return bytes[10] == 0xFF && bytes[11] == 0xFF;
  }

  static bool _isPublicV4(List<int> b) {
    final first = b[0];
    final second = b[1];
    if (first == 0 || first == 10 || first == 127) return false;
    if (first == 169 && second == 254) return false; // link-local, incl. cloud metadata
    if (first == 172 && second >= 16 && second <= 31) return false;
    if (first == 192 && second == 168) return false;
    if (first == 100 && second >= 64 && second <= 127) return false; // carrier NAT
    if (first == 198 && (second == 18 || second == 19)) return false; // benchmarking
    if (first >= 224) return false; // multicast + reserved
    return true;
  }
}
