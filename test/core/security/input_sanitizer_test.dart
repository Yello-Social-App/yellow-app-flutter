import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/core/security/input_sanitizer.dart';

void main() {
  group('stripControlAndZeroWidth', () {
    test('keeps newlines and tabs', () {
      const input = 'line one\nline two\tindented';
      expect(InputSanitizer.stripControlAndZeroWidth(input), input);
    });

    test('drops zero-width and control characters', () {
      const input = 'hel​loworld';
      expect(InputSanitizer.stripControlAndZeroWidth(input), 'helloworld');
    });
  });

  group('sanitizeText', () {
    test('trims surrounding whitespace', () {
      expect(InputSanitizer.sanitizeText('  hello  '), 'hello');
    });

    test('caps length when maxLength is given', () {
      expect(InputSanitizer.sanitizeText('hello world', maxLength: 5), 'hello');
    });
  });

  group('sanitizeQueryFragment', () {
    test('strips characters with special query meaning', () {
      expect(InputSanitizer.sanitizeQueryFragment('a<script>"; DROP'), 'ascript DROP');
    });

    test('collapses internal whitespace', () {
      expect(InputSanitizer.sanitizeQueryFragment('a    b'), 'a b');
    });
  });
}
