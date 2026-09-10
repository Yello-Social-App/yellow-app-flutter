import '../../core/utils/formatters.dart';

extension StringX on String {
  String get initials => Formatters.initialsFrom(this);

  String truncate(int maxLength, {String ellipsis = '…'}) {
    if (length <= maxLength) return this;
    return substring(0, maxLength).trimRight() + ellipsis;
  }

  String get withAtSign => startsWith('@') ? this : '@$this';
}
