/// OWASP Mobile **M4 — Insufficient Input/Output Validation**: user-authored
/// text (post captions, comments, chat messages, bios, search queries) is
/// rendered as plain `Text` throughout this app, which Flutter never
/// interprets as markup — so classic HTML/script injection isn't reachable
/// here the way it is on a WebView-rendered client. This class instead
/// guards the two real risks for a Flutter target: control-character/
/// zero-width smuggling, and shipping oversized or malformed values to the
/// backend.
abstract final class InputSanitizer {
  /// Strips characters with no legitimate place in user-visible text:
  /// C0/C1 control codes (except newline/tab) and zero-width formatting
  /// characters sometimes used to hide content or defeat length limits.
  static String stripControlAndZeroWidth(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final isControl = rune < 0x20 && rune != 0x0A && rune != 0x09;
      final isZeroWidth = rune == 0x200B || rune == 0x200C || rune == 0x200D || rune == 0xFEFF;
      if (isControl || isZeroWidth) continue;
      buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }

  /// Full pass applied to any free-text field before it leaves the device:
  /// trims, strips unsafe characters, and caps length.
  static String sanitizeText(String input, {int? maxLength}) {
    var out = stripControlAndZeroWidth(input).trim();
    if (maxLength != null && out.length > maxLength) {
      out = out.substring(0, maxLength);
    }
    return out;
  }

  /// Defense-in-depth for values interpolated into a search query or filter
  /// string sent to the backend — collapses whitespace and drops characters
  /// with special meaning in common query-string / SQL-LIKE contexts. This
  /// does NOT replace parameterized queries or backend-side validation;
  /// it only stops a malformed client value from reaching the wire.
  static String sanitizeQueryFragment(String input) {
    final cleaned = sanitizeText(input);
    return cleaned.replaceAll(RegExp(r'''[<>;'"`\\]'''), '').replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool isWithinLength(String input, int maxLength) => input.length <= maxLength;
}
