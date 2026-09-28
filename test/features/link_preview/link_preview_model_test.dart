import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/features/link_preview/data/models/link_preview_model.dart';

const String _page = '''
<html><head>
  <title>Fallback title</title>
  <meta property="og:title" content="Pillars of the Atrium">
  <meta property="og:description" content="A walk through the light study &amp; its drawings.">
  <meta property="og:image" content="/media/atrium.jpg?w=1200&amp;h=630">
  <meta property="og:site_name" content="Studio Notes">
</head><body>ignored</body></html>
''';

void main() {
  test('reads the Open Graph card and resolves a relative image', () {
    final model = LinkPreviewModel.fromHtml(
      _page,
      url: 'https://studio.example/atrium',
      baseUrl: 'https://studio.example/atrium',
    );

    expect(model.title, 'Pillars of the Atrium');
    expect(model.siteName, 'Studio Notes');
    // `&amp;` decoded in both the prose and the query string.
    expect(model.description, 'A walk through the light study & its drawings.');
    expect(model.imageUrl, 'https://studio.example/media/atrium.jpg?w=1200&h=630');
  });

  test('og:title wins over the document title, and the document title is the fallback', () {
    expect(
      LinkPreviewModel.fromHtml(_page, url: 'https://a.example/x', baseUrl: 'https://a.example/x').title,
      'Pillars of the Atrium',
    );
    expect(
      LinkPreviewModel.fromHtml(
        '<html><head><title>  Just   a  title </title></head></html>',
        url: 'https://a.example/x',
        baseUrl: 'https://a.example/x',
      ).title,
      'Just a title',
    );
  });

  test('single-quoted and bare attributes are read too', () {
    final model = LinkPreviewModel.fromHtml(
      "<meta content='Quoted' property='og:title'><meta property=og:site_name content=Bare>",
      url: 'https://a.example/x',
      baseUrl: 'https://a.example/x',
    );
    expect(model.title, 'Quoted');
    expect(model.siteName, 'Bare');
  });

  test('a twitter card stands in when there are no og tags', () {
    final model = LinkPreviewModel.fromHtml(
      '<meta name="twitter:title" content="From Twitter"><meta name="twitter:image" content="https://cdn.example/a.png">',
      url: 'https://a.example/x',
      baseUrl: 'https://a.example/x',
    );
    expect(model.title, 'From Twitter');
    expect(model.imageUrl, 'https://cdn.example/a.png');
  });

  test('an image on a private host is dropped, not loaded', () {
    for (final image in ['http://192.168.0.5/a.png', 'http://localhost/a.png', 'javascript:alert(1)']) {
      final model = LinkPreviewModel.fromHtml(
        '<meta property="og:image" content="$image">',
        url: 'https://a.example/x',
        baseUrl: 'https://a.example/x',
      );
      expect(model.imageUrl, isNull, reason: image);
    }
  });

  test('a page advertising nothing has no content to draw', () {
    final model = LinkPreviewModel.fromHtml(
      '<html><body>no head at all</body></html>',
      url: 'https://a.example/x',
      baseUrl: 'https://a.example/x',
    );
    expect(model.toEntity().hasContent, isFalse);
  });

  test('an over-long title is capped', () {
    final model = LinkPreviewModel.fromHtml(
      '<meta property="og:title" content="${'x' * 400}">',
      url: 'https://a.example/x',
      baseUrl: 'https://a.example/x',
    );
    expect(model.title!.length, lessThan(160));
  });

  test('a direct image link is its own preview', () {
    final entity = LinkPreviewModel.forImage('https://cdn.example/a.png').toEntity();
    expect(entity.imageUrl, 'https://cdn.example/a.png');
    expect(entity.hasContent, isTrue);
    expect(entity.host, 'cdn.example');
  });

  test('the host label drops a leading www.', () {
    expect(LinkPreviewModel.forImage('https://www.example.com/a.png').toEntity().label, 'example.com');
  });
}
