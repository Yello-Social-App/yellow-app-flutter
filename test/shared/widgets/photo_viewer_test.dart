import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/shared/widgets/photo_viewer_page.dart';

/// `cached_network_image` reaches for the temp directory through
/// path_provider the moment it builds, which has no implementation in a
/// widget test. The photos never load here either way — every assertion
/// below is about the viewer's chrome and gestures, not its pixels — so a
/// stub directory is enough to keep the plugin channel quiet.
void _stubPathProvider() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => '.dart_tool/test_cache',
  );
}

void main() {
  setUp(_stubPathProvider);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  Future<void> pumpViewer(WidgetTester tester, List<String> urls) async {
    await tester.pumpWidget(
      MaterialApp(home: PhotoViewerPage(imageUrls: urls, initialIndex: 0)),
    );
    await tester.pump();
  }

  testWidgets('counts the photos and follows the pager', (tester) async {
    await pumpViewer(tester, const ['https://a/1.jpg', 'https://a/2.jpg', 'https://a/3.jpg']);

    expect(find.text('1/3'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('a single photo gets no counter', (tester) async {
    await pumpViewer(tester, const ['https://a/1.jpg']);

    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('double tap zooms in, which locks the pager', (tester) async {
    await pumpViewer(tester, const ['https://a/1.jpg', 'https://a/2.jpg']);

    PageView pager() => tester.widget<PageView>(find.byType(PageView));
    expect(pager().physics, isA<PageScrollPhysics>());

    final centre = tester.getCenter(find.byType(PageView));
    await tester.tapAt(centre);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(centre);
    // The zoom animation needs one frame to start its ticker and a second
    // to run out — a lone `pump(300ms)` only ever gets it to frame zero.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // A zoomed photo owns its horizontal drags — the pager must not steal
    // them to page to the next photo.
    expect(pager().physics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('no photos lands on the unavailable state, not an empty screen', (tester) async {
    await pumpViewer(tester, const []);

    expect(find.text('This photo is no longer available'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });
}
