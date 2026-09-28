import '../../../../core/security/private_network_guard.dart';
import '../../domain/entities/link_preview_entity.dart';

/// Reads the Open Graph card out of a page's HTML.
///
/// Regex rather than a DOM parser, and deliberately: the whole job is a
/// handful of `<meta>` tags in the first 64 KB of a document that is never
/// rendered, and the `html` package would be a new dependency parsing
/// hostile markup for four strings. Nothing here is reinserted into a
/// document, so the usual "don't parse HTML with a regex" hazard — building
/// a tree — isn't in play.
///
/// Every string is entity-decoded, whitespace-collapsed and length-capped,
/// because all of it is someone else's page and it ends up in a widget.
class LinkPreviewModel {
  const LinkPreviewModel({required this.url, this.title, this.description, this.imageUrl, this.siteName});

  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  static const int _maxTitle = 140;
  static const int _maxDescription = 220;

  static final RegExp _metaTag = RegExp(r'<meta\b[^>]*>', caseSensitive: false, dotAll: true);
  // Raw, and triple-quoted so both quote styles can appear literally: an
  // attribute is `name="value"`, `name='value'` or bare `name=value`.
  static final RegExp _attribute = RegExp(
    r'''([a-zA-Z][\w:.-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))''',
  );
  static final RegExp _titleTag = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true);
  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _numericEntity = RegExp(r'&#(x?)([0-9a-fA-F]+);');

  /// [url] is the link as the reader will open it; [baseUrl] is the last hop
  /// of the redirect chain, which is what a relative `og:image` is relative
  /// to.
  factory LinkPreviewModel.fromHtml(String html, {required String url, required String baseUrl}) {
    final tags = _metaTags(html);
    final title = _clean(_firstOf(tags, const ['og:title', 'twitter:title']), _maxTitle) ?? _documentTitle(html);

    return LinkPreviewModel(
      url: url,
      title: title,
      description: _clean(
        _firstOf(tags, const ['og:description', 'twitter:description', 'description']),
        _maxDescription,
      ),
      imageUrl: _resolveImage(
        _firstOf(tags, const ['og:image:secure_url', 'og:image', 'og:image:url', 'twitter:image', 'twitter:image:src']),
        baseUrl,
      ),
      siteName: _clean(tags['og:site_name'], 60),
    );
  }

  /// A link that *is* a picture — the response came back as `image/*`, so the
  /// link is its own thumbnail and there is no markup to read.
  factory LinkPreviewModel.forImage(String url) => LinkPreviewModel(url: url, imageUrl: url);

  LinkPreviewEntity toEntity() => LinkPreviewEntity(
    url: url,
    title: title,
    description: description,
    imageUrl: imageUrl,
    siteName: siteName,
  );

  /// `property` (Open Graph) or `name` (Twitter, plain `description`) →
  /// `content`, first occurrence winning: a page that repeats `og:image`
  /// means the first one.
  static Map<String, String> _metaTags(String html) {
    final tags = <String, String>{};
    for (final tag in _metaTag.allMatches(html)) {
      final attributes = <String, String>{};
      for (final attribute in _attribute.allMatches(tag.group(0)!)) {
        final value = attribute.group(2) ?? attribute.group(3) ?? attribute.group(4) ?? '';
        attributes[attribute.group(1)!.toLowerCase()] = value;
      }
      final key = (attributes['property'] ?? attributes['name'])?.toLowerCase();
      final content = attributes['content'];
      if (key == null || key.isEmpty || content == null || content.isEmpty) continue;
      tags.putIfAbsent(key, () => content);
    }
    return tags;
  }

  static String? _documentTitle(String html) {
    final match = _titleTag.firstMatch(html);
    return match == null ? null : _clean(match.group(1), _maxTitle);
  }

  static String? _firstOf(Map<String, String> tags, List<String> keys) {
    for (final key in keys) {
      final value = tags[key];
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  static String? _clean(String? raw, int maxLength) {
    if (raw == null) return null;
    final collapsed = _decodeEntities(raw).replaceAll(_whitespace, ' ').trim();
    if (collapsed.isEmpty) return null;
    return collapsed.length <= maxLength ? collapsed : '${collapsed.substring(0, maxLength).trimRight()}…';
  }

  /// The handful that actually show up in `og:` content, plus numeric escapes.
  /// `&amp;` matters most: it is in every query string a CMS emits.
  static String _decodeEntities(String raw) {
    final decoded = raw
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAllMapped(_numericEntity, (match) {
          final code = int.tryParse(match.group(2)!, radix: match.group(1)!.isEmpty ? 10 : 16);
          // Anything outside the Unicode range, or a control character, is
          // left as written rather than turned into a replacement glyph.
          if (code == null || code < 0x20 || code > 0x10FFFF) return match.group(0)!;
          return String.fromCharCode(code);
        });
    // Last, so `&amp;#39;` cannot decode twice into a quote.
    return decoded.replaceAll('&amp;', '&');
  }

  /// Absolute, `http(s)`, publicly routable — or nothing. This URL goes
  /// straight into an image widget on the reader's phone, so it gets the same
  /// check the page fetch got (see [PrivateNetworkGuard]).
  static String? _resolveImage(String? raw, String baseUrl) {
    final reference = _decodeEntities(raw ?? '').trim();
    if (reference.isEmpty) return null;
    final Uri resolved;
    try {
      final base = Uri.tryParse(baseUrl);
      resolved = base == null ? Uri.parse(reference) : base.resolve(reference);
    } catch (_) {
      return null;
    }
    if (resolved.scheme != 'http' && resolved.scheme != 'https') return null;
    if (!PrivateNetworkGuard.isPubliclyRoutable(resolved.host)) return null;
    return resolved.toString();
  }
}
