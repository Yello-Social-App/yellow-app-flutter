import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/di/injection.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/features/link_preview/domain/entities/link_preview_entity.dart';
import 'package:yello_social_app/features/link_preview/domain/usecases/get_link_preview_usecase.dart';
import 'package:yello_social_app/features/link_preview/presentation/bloc/link_preview_cubit.dart';
import 'package:yello_social_app/features/link_preview/presentation/widgets/link_preview_card.dart';
import 'package:yello_social_app/shared/widgets/shimmer_loading.dart';

class _MockGetLinkPreview extends Mock implements GetLinkPreviewUseCase {}

const String _url = 'https://studio.example/atrium';

/// No `og:image`, so nothing pulls in `CachedNetworkImage` — which needs a
/// `path_provider` stub in a widget test (see `docs/GOTCHAS.md`).
const LinkPreviewEntity _textOnlyCard = LinkPreviewEntity(
  url: _url,
  title: 'Pillars of the Atrium',
  siteName: 'Studio Notes',
);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  late _MockGetLinkPreview getLinkPreview;

  setUp(() {
    getLinkPreview = _MockGetLinkPreview();
    sl.registerLazySingleton(() => LinkPreviewCubit(getLinkPreview: getLinkPreview));
  });

  tearDown(() => sl.reset());

  testWidgets('text with no link draws nothing at all — not an empty gap', (tester) async {
    await tester.pumpWidget(_host(const LinkPreviewList(text: 'a post with no links in it')));

    expect(find.byType(LinkPreviewCard), findsNothing);
    expect(tester.getSize(find.byType(LinkPreviewList)), Size.zero);
    verifyNever(() => getLinkPreview(any()));
  });

  testWidgets('a skeleton shows while the page is being read, then the card replaces it', (tester) async {
    final completer = Completer<Either<Failure, LinkPreviewEntity>>();
    when(() => getLinkPreview(_url)).thenAnswer((_) => completer.future);

    await tester.pumpWidget(_host(const LinkPreviewList(text: 'see $_url')));
    await tester.pump();

    expect(find.byType(ShimmerBox), findsWidgets);

    completer.complete(const Right(_textOnlyCard));
    await tester.pump();

    expect(find.text('Pillars of the Atrium'), findsOneWidget);
    expect(find.text('STUDIO NOTES'), findsOneWidget);
    expect(find.byType(ShimmerBox), findsNothing);
  });

  testWidgets('a link that cannot be read retains a thumbnail placeholder and host', (tester) async {
    when(() => getLinkPreview(_url)).thenAnswer((_) async => const Left(ServerFailure()));

    await tester.pumpWidget(_host(const LinkPreviewList(text: 'see $_url')));
    await tester.pump();

    expect(find.byType(ShimmerBox), findsNothing);
    expect(find.text('No preview image'), findsOneWidget);
    expect(find.text('STUDIO.EXAMPLE'), findsOneWidget);
  });

  testWidgets('every distinct link gets a card, including links beyond the former cap', (tester) async {
    for (var i = 0; i < 5; i++) {
      final url = 'https://example.com/$i';
      when(() => getLinkPreview(url)).thenAnswer((_) async => Right(LinkPreviewEntity(url: url, title: 'Page $i')));
    }

    await tester.pumpWidget(
      _host(
        const SingleChildScrollView(
          child: LinkPreviewList(
            text:
                'https://example.com/0 https://example.com/0 https://example.com/1 '
                'https://example.com/2 https://example.com/3 https://example.com/4',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LinkPreviewCard), findsNWidgets(5));
    verify(() => getLinkPreview('https://example.com/0')).called(1);
    verify(() => getLinkPreview('https://example.com/4')).called(1);
  });
}
