/// One `http(s)` link found inside a run of user-typed text — see
/// [LinkScanner.scan].
class LinkMatch {
  const LinkMatch({required this.start, required this.end, required this.url});

  /// Half-open range into the scanned string: `text.substring(start, end)` is
  /// exactly what the author typed, and what stays on screen. Only [url] is
  /// normalised — rewriting the visible text would mean a link that reads
  /// differently from the one it opens.
  final int start;
  final int end;

  /// The same link with a scheme in front of it: a bare `www.example.com` is
  /// only launchable once it reads `https://www.example.com`.
  final String url;
}

/// Finds the links in a piece of user-typed text (a post body, a comment, a
/// bio) so they can be drawn and tapped as links.
///
/// Deliberately conservative — a false positive is worse than a miss here,
/// because it paints part of someone's sentence as tappable. So:
///
/// - only `http://`, `https://` and a leading `www.` start a match; a bare
///   `example.com` in prose does not, or every "etc." would light up;
/// - the host must carry a dot and a two-character-or-longer last label, which
///   also keeps `http://localhost:8080` and bare-IP URLs out;
/// - trailing punctuation is given back to the sentence, including a closing
///   bracket that has no opener inside the link, so `(see https://a.co/x).`
///   opens `https://a.co/x`.
abstract final class LinkScanner {
  /// `<`, `>` and quotes end a match so a link pasted inside markup or a
  /// quotation doesn't swallow what follows it.
  static final RegExp _pattern = RegExp(r'''(?:https?://|www\.)[^\s<>"'`]+''', caseSensitive: false);

  /// Characters that end a sentence far more often than they end a URL.
  static const String _sentenceTail = '.,;:!?\u2026\u2014\u2013*_~';

  static const Map<String, String> _brackets = {')': '(', ']': '[', '}': '{', '\u00bb': '\u00ab'};

  static List<LinkMatch> scan(String text) {
    if (text.length < 5) return const [];
    final matches = <LinkMatch>[];
    for (final match in _pattern.allMatches(text)) {
      final end = _trimTail(text, match.start, match.end);
      if (end <= match.start) continue;
      final url = _normalise(text.substring(match.start, end));
      if (url == null) continue;
      matches.add(LinkMatch(start: match.start, end: end, url: url));
    }
    return matches;
  }

  /// Walks back from [end] while the last character belongs to the sentence
  /// rather than to the link. Loops rather than trimming once, so a link that
  /// ends `...).` gives back both characters.
  static int _trimTail(String text, int start, int end) {
    var cursor = end;
    while (cursor > start) {
      final ch = text[cursor - 1];
      if (_sentenceTail.contains(ch)) {
        cursor--;
        continue;
      }
      final opener = _brackets[ch];
      // A closing bracket stays only when the link opened one itself — Wikipedia
      // and doc URLs really do contain `(`…`)`.
      if (opener != null && !_opensItsOwn(text.substring(start, cursor), opener, ch)) {
        cursor--;
        continue;
      }
      break;
    }
    return cursor;
  }

  static bool _opensItsOwn(String candidate, String open, String close) {
    var depth = 0;
    for (var i = 0; i < candidate.length; i++) {
      if (candidate[i] == open) {
        depth++;
      } else if (candidate[i] == close) {
        depth--;
      }
    }
    return depth >= 0;
  }

  /// `null` for anything that parsed but isn't a public `http(s)` address.
  static String? _normalise(String raw) {
    final withScheme = raw.length > 4 && raw.substring(0, 4).toLowerCase() == 'www.' ? 'https://$raw' : raw;
    final uri = Uri.tryParse(withScheme);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    final labels = uri.host.split('.');
    if (labels.length < 2 || labels.last.length < 2) return null;
    if (labels.any((label) => label.isEmpty)) return null;
    return withScheme;
  }
}
