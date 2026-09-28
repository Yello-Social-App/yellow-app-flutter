import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/features/link_preview/domain/entities/link_preview_entity.dart';
import 'package:yello_social_app/features/link_preview/domain/usecases/get_link_preview_usecase.dart';
import 'package:yello_social_app/features/link_preview/presentation/bloc/link_preview_cubit.dart';

class _MockGetLinkPreview extends Mock implements GetLinkPreviewUseCase {}

const String _url = 'https://studio.example/atrium';

LinkPreviewEntity _preview({String url = _url, String? title = 'Atrium'}) =>
    LinkPreviewEntity(url: url, title: title, imageUrl: 'https://cdn.example/a.png');

void main() {
  late _MockGetLinkPreview getLinkPreview;
  late LinkPreviewCubit cubit;

  setUp(() {
    getLinkPreview = _MockGetLinkPreview();
    cubit = LinkPreviewCubit(getLinkPreview: getLinkPreview);
  });

  tearDown(() => cubit.close());

  test('a fetched card is readable by URL', () async {
    when(() => getLinkPreview(_url)).thenAnswer((_) async => Right(_preview()));

    await cubit.request(_url);

    expect(cubit.state.statusOf(_url), LinkPreviewStatus.ready);
    expect(cubit.state.previewOf(_url)!.title, 'Atrium');
    expect(cubit.state.pending, isEmpty);
  });

  test('a URL nobody has asked about yet reads as loading, so a card shows a skeleton', () {
    expect(cubit.state.statusOf(_url), LinkPreviewStatus.loading);
  });

  test('the same URL is fetched once however many cards ask', () async {
    when(() => getLinkPreview(_url)).thenAnswer((_) async => Right(_preview()));

    await Future.wait([cubit.request(_url), cubit.request(_url), cubit.request(_url)]);
    await cubit.request(_url);

    verify(() => getLinkPreview(_url)).called(1);
  });

  test('a failure is remembered, so it is not retried on every scroll', () async {
    when(() => getLinkPreview(_url)).thenAnswer((_) async => const Left(ServerFailure()));

    await cubit.request(_url);
    await cubit.request(_url);

    expect(cubit.state.statusOf(_url), LinkPreviewStatus.unavailable);
    verify(() => getLinkPreview(_url)).called(1);
  });

  test('a page that advertised nothing counts as unavailable, not as a card', () async {
    when(() => getLinkPreview(_url)).thenAnswer(
      (_) async => const Right(LinkPreviewEntity(url: _url)),
    );

    await cubit.request(_url);

    expect(cubit.state.statusOf(_url), LinkPreviewStatus.unavailable);
    expect(cubit.state.previewOf(_url), isNull);
  });

  test('two different links are kept apart', () async {
    const other = 'https://other.example/b';
    when(() => getLinkPreview(_url)).thenAnswer((_) async => Right(_preview()));
    when(() => getLinkPreview(other)).thenAnswer((_) async => Right(_preview(url: other, title: 'Other')));

    await cubit.request(_url);
    await cubit.request(other);

    expect(cubit.state.previewOf(_url)!.title, 'Atrium');
    expect(cubit.state.previewOf(other)!.title, 'Other');
  });

  test('the cache is bounded — the oldest card is evicted', () async {
    for (var i = 0; i < 130; i++) {
      final url = 'https://example.com/$i';
      when(() => getLinkPreview(url)).thenAnswer((_) async => Right(_preview(url: url, title: 'Page $i')));
      await cubit.request(url);
    }

    expect(cubit.state.previews.length, lessThanOrEqualTo(120));
    expect(cubit.state.statusOf('https://example.com/0'), LinkPreviewStatus.loading);
    expect(cubit.state.statusOf('https://example.com/129'), LinkPreviewStatus.ready);
  });
}
