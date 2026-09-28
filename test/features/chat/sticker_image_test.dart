import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/core/theme/app_colors.dart';
import 'package:yello_social_app/core/theme/app_theme.dart';
import 'package:yello_social_app/features/chat/domain/entities/sticker_entity.dart';
import 'package:yello_social_app/features/chat/presentation/widgets/sticker_image.dart';

/// `CachedNetworkImage` reaches for the temp directory through path_provider
/// the moment it builds, which has no implementation in a widget test. The
/// pictures never load here either way — every assertion below is about the
/// frame and the geometry, not the pixels — so a stub directory is enough to
/// keep the plugin channel quiet (`docs/GOTCHAS.md`).
void _stubPathProvider() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => '.dart_tool/test_cache',
  );
}

StickerEntity _sticker(StickerBackground background, {String url = 'https://r2.example/s1.webp'}) =>
    StickerEntity(id: 's1', background: background, image: StickerImage(url: url));

void main() {
  setUp(_stubPathProvider);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  Future<void> pump(WidgetTester tester, StickerEntity sticker, {double size = 124, double width = 320}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemeFlavor.classic),
          home: Scaffold(
            // `Align`, not a bare `SizedBox`: a tight width constraint would
            // be clamped back onto the sticker's own square, which is not how
            // a transcript column or a grid cell hands it its space.
            body: Center(
              child: SizedBox(
                width: width,
                child: Align(child: StickerImageView(sticker: sticker, size: size)),
              ),
            ),
          ),
        ),
      );

  testWidgets('a kept sticker wears the white frame; a cut-out does not', (tester) async {
    await pump(tester, _sticker(StickerBackground.kept));
    final framed = tester.widget<Container>(
      find.descendant(of: find.byType(StickerImageView), matching: find.byType(Container)).first,
    );
    // The frame goes in `foregroundDecoration`, or an edge-to-edge child paints
    // over it and it quietly vanishes (`docs/GOTCHAS.md`).
    final border = (framed.foregroundDecoration! as BoxDecoration).border! as Border;
    expect(border.top.color, Colors.white);
    expect((framed.decoration! as BoxDecoration).color, Colors.white);

    await pump(tester, _sticker(StickerBackground.removed));
    expect(find.descendant(of: find.byType(StickerImageView), matching: find.byType(Container)), findsNothing);
  });

  testWidgets('nothing in a sticker paints a blurred shadow', (tester) async {
    for (final background in StickerBackground.values) {
      await pump(tester, _sticker(background));
      // A blurred `BoxShadow` in a widget that rebuilds on Cubit state crashed
      // this project's renderer, and the transcript rebuilds on every poll —
      // the design's drop shadow is deliberately not here (`docs/GOTCHAS.md`).
      for (final container in tester.widgetList<Container>(
        find.descendant(of: find.byType(StickerImageView), matching: find.byType(Container)),
      )) {
        for (final decoration in [container.decoration, container.foregroundDecoration]) {
          final shadows = decoration is BoxDecoration ? decoration.boxShadow : null;
          expect(shadows ?? const <BoxShadow>[], isEmpty);
        }
      }
    }
  });

  testWidgets('it is square at the asked-for size, and fits a 320dp phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(tester, _sticker(StickerBackground.kept), size: 112);
    expect(tester.getSize(find.byType(StickerImageView)), const Size(112, 112));
    expect(tester.takeException(), isNull);

    // What a picker tile asks for at the narrowest cell the grid can produce.
    await pump(tester, _sticker(StickerBackground.removed), size: 56, width: 64);
    expect(tester.getSize(find.byType(StickerImageView)), const Size(56, 56));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a sticker with no URL still draws a placeholder rather than nothing', (tester) async {
    await pump(tester, _sticker(StickerBackground.removed, url: ''));
    expect(find.byIcon(CupertinoIcons.smiley), findsOneWidget);
    expect(tester.getSize(find.byType(StickerImageView)), const Size(124, 124));
  });
}
