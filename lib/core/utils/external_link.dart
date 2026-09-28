import 'package:url_launcher/url_launcher.dart';

import 'logger.dart';

/// Hands a link to whatever app the OS has registered for it.
///
/// The one place in the app that calls `launchUrl`, so the scheme check
/// happens once. Everything this opens came out of another user's post,
/// comment or bio, and `launchUrl` will hand a `javascript:`, `intent:`,
/// `file:` or `tel:` URL straight to a platform handler — so the check is an
/// allowlist of `http`/`https` rather than a list of things to block
/// (OWASP A05/A06). [LinkScanner] already only produces those two, but the
/// showcase and chat link rows call this with a backend-supplied URL.
abstract final class ExternalLink {
  /// `false` when the link was refused or no app on the phone would take it —
  /// the caller decides whether that is worth a message on screen.
  static Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      appLogger.w('Refused to open a ${uri.scheme.isEmpty ? 'scheme-less' : uri.scheme} link.');
      return false;
    }
    try {
      // `externalApplication` rather than an in-app web view: this is someone
      // else's page, and it should be obvious that it isn't Yello any more.
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Host only. The path and query are the author's, and this logger is
      // live in release for warnings.
      appLogger.w('Could not open a link on ${uri.host}: $e');
      return false;
    }
  }
}
