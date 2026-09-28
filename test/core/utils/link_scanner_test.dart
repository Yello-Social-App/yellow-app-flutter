import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/core/utils/link_scanner.dart';

List<String> urlsIn(String text) => LinkScanner.scan(text).map((match) => match.url).toList();

void main() {
  test('finds a bare https link', () {
    expect(urlsIn('look at https://example.com/a'), ['https://example.com/a']);
  });

  test('a leading www. gets a scheme, and the visible text is left alone', () {
    final matches = LinkScanner.scan('see www.example.com now');
    expect(matches.single.url, 'https://www.example.com');
    expect('see www.example.com now'.substring(matches.single.start, matches.single.end), 'www.example.com');
  });

  test('gives sentence punctuation back', () {
    expect(urlsIn('read https://example.com/a.'), ['https://example.com/a']);
    expect(urlsIn('here: https://example.com/a, then'), ['https://example.com/a']);
    expect(urlsIn('(see https://example.com/a).'), ['https://example.com/a']);
  });

  test('keeps a bracket the link opened itself', () {
    expect(urlsIn('https://en.wikipedia.org/wiki/Dart_(language)'), ['https://en.wikipedia.org/wiki/Dart_(language)']);
  });

  test('a fragment belongs to the link, not to a hashtag', () {
    expect(urlsIn('https://example.com/docs#install'), ['https://example.com/docs#install']);
  });

  test('prose is not a link', () {
    expect(urlsIn('i went to the shop etc. and came back'), isEmpty);
    expect(urlsIn('the file is main.dart in lib'), isEmpty);
    expect(urlsIn('#yello is a hashtag'), isEmpty);
  });

  test('a scheme with no public host is refused', () {
    expect(urlsIn('http://localhost:8080/x'), isEmpty);
    expect(urlsIn('ftp://example.com/a'), isEmpty);
    // A single-label TLD cannot exist, so this is not a host.
    expect(urlsIn('https://example.c'), isEmpty);
  });

  test('finds several links and reports them in order', () {
    final text = 'first https://a.example/one then https://b.example/two';
    final matches = LinkScanner.scan(text);
    expect(matches.map((m) => m.url), ['https://a.example/one', 'https://b.example/two']);
    expect(matches.first.start, lessThan(matches.last.start));
  });

  test('a link inside quotes or markup stops at the delimiter', () {
    expect(urlsIn('"https://example.com/a" said so'), ['https://example.com/a']);
    expect(urlsIn('<https://example.com/a>'), ['https://example.com/a']);
  });
}
