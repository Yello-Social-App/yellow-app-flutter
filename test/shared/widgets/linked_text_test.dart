import 'package:dartz/dartz.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/di/injection.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/features/link_preview/domain/usecases/get_link_preview_usecase.dart';
import 'package:yello_social_app/features/link_preview/presentation/bloc/link_preview_cubit.dart';
import 'package:yello_social_app/features/link_preview/presentation/widgets/link_preview_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yello_social_app/shared/widgets/linked_text.dart';

/// `MethodChannelUrlLauncher` — the instance `url_launcher` falls back to when
/// no platform plugin is registered, which is the case under `flutter test` —
/// talks over this channel.
const MethodChannel _urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

/// No `theme:` — `AppColors.of` falls back to the light palette, which is
/// what the rest of the widget tests in this repo rely on too.
Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// The plain text of every span carrying a tap recognizer.
List<String> _linkSpans(WidgetTester tester) {
  final spans = <String>[];
  tester.widget<RichText>(find.byType(RichText).first).text.visitChildren((span) {
    if (span is TextSpan && span.recognizer != null) spans.add(span.text ?? '');
    return true;
  });
  return spans;
}

class _MockGetLinkPreview extends Mock implements GetLinkPreviewUseCase {}

void main() {
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    final getPreview = _MockGetLinkPreview();
    when(() => getPreview(any())).thenAnswer((_) async => const Left(ServerFailure()));
    sl.registerSingleton(LinkPreviewCubit(getLinkPreview: getPreview));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_urlLauncherChannel, (
      call,
    ) async {
      calls.add(call);
      // `canLaunch` and `launch` both answer bool.
      return true;
    });
  });

  tearDown(() async {
    await sl<LinkPreviewCubit>().close();
    await sl.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _urlLauncherChannel,
      null,
    );
  });

  testWidgets('only the link carries a recognizer', (tester) async {
    await tester.pumpWidget(
      _host(const LinkedText(text: 'read https://example.com/a first', style: TextStyle(fontSize: 14))),
    );

    expect(_linkSpans(tester), ['https://example.com/a']);
  });

  testWidgets('text with no link renders one plain span and no recognizers', (tester) async {
    await tester.pumpWidget(_host(const LinkedText(text: 'nothing to see here', style: TextStyle(fontSize: 14))));

    expect(_linkSpans(tester), isEmpty);
  });

  testWidgets('tapping a link asks the platform to open it', (tester) async {
    await tester.pumpWidget(
      _host(const LinkedText(text: 'go https://example.com/a now', style: TextStyle(fontSize: 14))),
    );

    // Tap the recognizer directly: hitting the exact glyph range of one span
    // by offset is brittle, and what matters is that the recognizer is wired
    // to the launcher.
    TextSpan? link;
    tester.widget<RichText>(find.byType(RichText).first).text.visitChildren((span) {
      if (span is TextSpan && span.recognizer != null) link = span;
      return true;
    });
    (link!.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();

    expect(calls, isNotEmpty);
    expect(calls.map((call) => call.arguments.toString()).join(), contains('https://example.com/a'));
  });

  testWidgets('a hashtag is highlighted but not tappable, and a URL fragment is not a hashtag', (tester) async {
    await tester.pumpWidget(
      _host(
        const LinkedText(
          text: 'see https://example.com/docs#install #yello',
          style: TextStyle(fontSize: 14),
          tagBackground: Color(0xFFFFCE2B),
        ),
      ),
    );

    // The fragment stayed inside the link; only the standalone tag is a tag.
    expect(_linkSpans(tester), ['https://example.com/docs#install']);

    final highlighted = <String>[];
    tester.widget<RichText>(find.byType(RichText).first).text.visitChildren((span) {
      if (span is TextSpan && span.style?.backgroundColor != null) highlighted.add(span.text ?? '');
      return true;
    });
    expect(highlighted, ['#yello']);
  });

  testWidgets('recognizers are rebuilt when the text changes and disposed with the widget', (tester) async {
    await tester.pumpWidget(_host(const LinkedText(text: 'https://a.example/1', style: TextStyle(fontSize: 14))));
    expect(_linkSpans(tester), ['https://a.example/1']);

    await tester.pumpWidget(_host(const LinkedText(text: 'https://b.example/2', style: TextStyle(fontSize: 14))));
    expect(_linkSpans(tester), ['https://b.example/2']);

    // Disposing a recognizer twice throws, so a clean teardown here is the
    // assertion: the State must not leave a stale recognizer behind.
    await tester.pumpWidget(_host(const SizedBox.shrink()));
    expect(tester.takeException(), isNull);
  });
  testWidgets('preview stays below its text inside a narrow intrinsic chat bubble', (tester) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 183,
          child: IntrinsicWidth(
            child: LinkedText(text: 'https://example.com/a', style: TextStyle(fontSize: 14)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LinkPreviewCard), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(LinkPreviewCard)).width, lessThanOrEqualTo(183));
    expect(
      tester.getTopLeft(find.byType(LinkPreviewCard)).dy,
      greaterThan(tester.getBottomLeft(find.byType(RichText).first).dy),
    );
  });
}
