/// Formatting helpers matching the mockup's compact, uppercase-mono
/// presentation of counts and relative time (e.g. "4H", "1.2K", "YDAY").
abstract final class Formatters {
  static String compactCount(int value) {
    if (value < 1000) return '$value';
    if (value < 1000000) {
      final k = value / 1000;
      return '${_trim(k)}K';
    }
    final m = value / 1000000;
    return '${_trim(m)}M';
  }

  static String _trim(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  /// Relative timestamp in the mockup's short uppercase form: "2H", "YDAY",
  /// "MON", or a weekday-abbreviation fallback beyond a week.
  static String relativeShort(DateTime from, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final diff = n.difference(from);
    if (diff.inMinutes < 1) return 'NOW';
    if (diff.inMinutes < 60) return '${diff.inMinutes}M';
    if (diff.inHours < 24) return '${diff.inHours}H';
    if (diff.inDays == 1) return 'YDAY';
    if (diff.inDays < 7) {
      const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      return days[from.weekday - 1];
    }
    return '${from.month}/${from.day}';
  }

  static String initialsFrom(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase());
    return letters.join();
  }
}
