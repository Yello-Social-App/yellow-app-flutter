import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/features/chat/data/datasources/chat_frame_decoder.dart';
import 'package:yello_social_app/features/chat/domain/entities/sticker_entity.dart';
import 'package:yello_social_app/features/chat/domain/repositories/sticker_repository.dart';
import 'package:yello_social_app/features/chat/domain/usecases/sticker_usecases.dart';
import 'package:yello_social_app/features/chat/presentation/bloc/stickers_cubit.dart';

class _StickerRepository extends Mock implements StickerRepository {}

StickerEntity _sticker(String id, {String name = '', String? packId, bool mine = true}) => StickerEntity(
  id: id,
  packId: packId,
  name: name,
  background: StickerBackground.kept,
  image: StickerImage(url: 'https://r2.example/$id.webp'),
  isMine: mine,
);

void main() {
  late _StickerRepository repository;
  late StreamController<StickerLibraryEvent> events;
  late StickersCubit cubit;

  StickersCubit build() => StickersCubit(
    getMine: GetMyStickersUseCase(repository),
    getRecent: GetRecentStickersUseCase(repository),
    getPacks: GetStickerPacksUseCase(repository),
    renameSticker: RenameStickerUseCase(repository),
    deleteSticker: DeleteStickerUseCase(repository),
    repository: repository,
  );

  void stubLoad({
    List<StickerEntity> recent = const [],
    List<StickerEntity> mine = const [],
    String? cursor,
    List<StickerPackEntity> packs = const [],
  }) {
    when(() => repository.getRecentStickers(size: any(named: 'size'))).thenAnswer((_) async => Right(recent));
    when(
      () => repository.getMyStickers(cursor: any(named: 'cursor')),
    ).thenAnswer((_) async => Right(StickerLibraryPage(items: mine, nextCursor: cursor)));
    when(repository.getStickerPacks).thenAnswer((_) async => Right(packs));
  }

  setUp(() {
    repository = _StickerRepository();
    events = StreamController<StickerLibraryEvent>.broadcast();
    when(repository.watchLibrary).thenAnswer((_) => events.stream);
    cubit = build();
  });

  tearDown(() async {
    await cubit.close();
    await events.close();
  });

  test('load fills all three lists', () async {
    stubLoad(
      recent: [_sticker('r1')],
      mine: [_sticker('s1', name: 'Mochi')],
      cursor: 'c2',
      packs: [
        StickerPackEntity(id: 'pack_buddy', name: 'Yello Buddy', stickers: [_sticker('p1', packId: 'pack_buddy')]),
      ],
    );

    await cubit.load();

    expect(cubit.state.status, StickerLibraryStatus.loaded);
    expect(cubit.state.recent.single.id, 'r1');
    expect(cubit.state.mine.single.id, 's1');
    expect(cubit.state.packs.single.stickers.single.id, 'p1');
    expect(cubit.state.hasMoreMine, isTrue);
    expect(cubit.state.isEmpty, isFalse);
  });

  test('only My stickers failing fails the load; the other two keep what they had', () async {
    stubLoad(recent: [_sticker('r1')], packs: const []);
    when(
      () => repository.getMyStickers(cursor: any(named: 'cursor')),
    ).thenAnswer((_) async => const Left(ServerFailure('nope')));

    await cubit.load();

    expect(cubit.state.status, StickerLibraryStatus.error);
    expect(cubit.state.errorMessage, 'nope');
  });

  test('a failed Recent on a reload does not blank the tab', () async {
    stubLoad(recent: [_sticker('r1')], mine: [_sticker('s1')]);
    await cubit.load();

    when(
      () => repository.getRecentStickers(size: any(named: 'size')),
    ).thenAnswer((_) async => const Left(NetworkFailure()));
    await cubit.load();

    expect(cubit.state.status, StickerLibraryStatus.loaded);
    expect(cubit.state.recent.single.id, 'r1');
  });

  test('loadMoreMine appends the next page and stops at the last one', () async {
    stubLoad(mine: [_sticker('s1')], cursor: 'c2');
    await cubit.load();

    when(
      () => repository.getMyStickers(cursor: 'c2'),
    ).thenAnswer((_) async => Right(StickerLibraryPage(items: [_sticker('s2')])));
    await cubit.loadMoreMine();

    expect(cubit.state.mine.map((s) => s.id), ['s1', 's2']);
    expect(cubit.state.hasMoreMine, isFalse);

    // Nothing left to ask for: a second call is a no-op rather than a refetch
    // of the same page.
    await cubit.loadMoreMine();
    verify(() => repository.getMyStickers(cursor: 'c2')).called(1);
  });

  test('search runs over the library and the packs, and ignores unnamed stickers', () async {
    stubLoad(
      mine: [_sticker('s1', name: 'Mochi proud'), _sticker('s2')],
      packs: [
        StickerPackEntity(
          id: 'pack_buddy',
          name: 'Yello Buddy',
          stickers: [_sticker('p1', packId: 'pack_buddy', name: 'Thank you', mine: false)],
        ),
      ],
    );
    await cubit.load();

    expect(cubit.state.search('mochi').map((s) => s.id), ['s1']);
    expect(cubit.state.search('THANK').map((s) => s.id), ['p1']);
    expect(cubit.state.search('   '), isEmpty);
    expect(cubit.state.search('nothing here'), isEmpty);
  });

  test('applySaved puts a new sticker first and replaces one it already holds', () async {
    stubLoad(mine: [_sticker('s1')]);
    await cubit.load();

    cubit.applySaved(_sticker('s2', name: 'new'));
    expect(cubit.state.mine.map((s) => s.id), ['s2', 's1']);

    cubit.applySaved(_sticker('s1', name: 'renamed'));
    expect(cubit.state.mine.map((s) => s.id), ['s1', 's2']);
    expect(cubit.state.mine.length, 2);
  });

  test('markSent hoists a sticker to the front of Recent without duplicating it', () async {
    stubLoad(recent: [_sticker('r1'), _sticker('r2')]);
    await cubit.load();

    cubit.markSent(_sticker('r2'));
    expect(cubit.state.recent.map((s) => s.id), ['r2', 'r1']);

    cubit.markSent(_sticker('r3'));
    expect(cubit.state.recent.map((s) => s.id), ['r3', 'r2', 'r1']);
  });

  test('rename swaps the sticker in place, in My stickers and in Recent', () async {
    final sticker = _sticker('s1', name: 'old');
    stubLoad(mine: [sticker], recent: [sticker]);
    await cubit.load();

    when(
      () => repository.renameSticker(stickerId: 's1', name: 'new'),
    ).thenAnswer((_) async => Right(_sticker('s1', name: 'new')));

    await cubit.rename(sticker, 'new');

    expect(cubit.state.mine.single.name, 'new');
    expect(cubit.state.recent.single.name, 'new');
    expect(cubit.state.busyStickerIds, isEmpty);
  });

  test('a pack sticker is never renamed or deleted — the call is not even made', () async {
    final packSticker = _sticker('p1', packId: 'pack_buddy', mine: false);
    await cubit.rename(packSticker, 'nope');
    await cubit.remove(packSticker);
    verifyNever(() => repository.renameSticker(stickerId: any(named: 'stickerId'), name: any(named: 'name')));
    verifyNever(() => repository.deleteSticker(any()));
  });

  test('delete drops it from My stickers and from Recent, since a send would 404', () async {
    final sticker = _sticker('s1');
    stubLoad(mine: [sticker, _sticker('s2')], recent: [sticker]);
    await cubit.load();

    when(() => repository.deleteSticker('s1')).thenAnswer((_) async => const Right(unit));
    await cubit.remove(sticker);

    expect(cubit.state.mine.map((s) => s.id), ['s2']);
    expect(cubit.state.recent, isEmpty);
  });

  test('a failed rename surfaces the message and leaves the sticker alone', () async {
    final sticker = _sticker('s1', name: 'old');
    stubLoad(mine: [sticker]);
    await cubit.load();

    when(
      () => repository.renameSticker(stickerId: 's1', name: 'new'),
    ).thenAnswer((_) async => const Left(ValidationFailure('too long')));

    await cubit.rename(sticker, 'new');

    expect(cubit.state.actionError, 'too long');
    expect(cubit.state.mine.single.name, 'old');
    expect(cubit.state.busyStickerIds, isEmpty);
  });

  group('live library events', () {
    test('added, updated and removed are applied — and the socket lease is balanced', () async {
      stubLoad(mine: [_sticker('s1', name: 'old')]);
      await cubit.load();

      cubit.watchLibrary();
      cubit.watchLibrary();
      verify(repository.watchLibrary).called(1);

      events.add(StickerAdded(_sticker('s2')));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.mine.map((s) => s.id), ['s2', 's1']);

      events.add(StickerUpdated(_sticker('s1', name: 'new')));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.mine.last.name, 'new');

      events.add(const StickerRemoved('s2'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.mine.map((s) => s.id), ['s1']);

      // Two holders, so the first release keeps the subscription alive.
      cubit.releaseLibrary();
      events.add(StickerAdded(_sticker('s3')));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.mine.map((s) => s.id), ['s3', 's1']);

      cubit.releaseLibrary();
      events.add(StickerAdded(_sticker('s4')));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.mine.map((s) => s.id), ['s3', 's1']);
    });

    test("an echo of this device's own save does not double the sticker up", () async {
      stubLoad();
      await cubit.load();
      cubit.watchLibrary();

      cubit.applySaved(_sticker('s1'));
      events.add(StickerAdded(_sticker('s1')));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.mine.length, 1);
    });

    test('a rename of a sticker on a page not loaded yet is not pulled into the grid', () async {
      stubLoad(mine: [_sticker('s1')], cursor: 'c2');
      await cubit.load();
      cubit.watchLibrary();

      events.add(StickerUpdated(_sticker('unloaded', name: 'somewhere on page 2')));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.mine.map((s) => s.id), ['s1']);
    });
  });

  test('isFull only once the whole library has been paged in', () async {
    final full = [for (var i = 0; i < stickerLibraryMax; i++) _sticker('s$i')];
    stubLoad(mine: full, cursor: 'c2');
    await cubit.load();
    // Still a cursor, so 200 held is not yet 200 owned.
    expect(cubit.state.isFull, isFalse);

    stubLoad(mine: full);
    await cubit.load();
    expect(cubit.state.isFull, isTrue);
  });

  group('ChatFrameDecoder.stickerEvent', () {
    test('decodes the three sticker frames', () {
      final added = ChatFrameDecoder.stickerEvent({
        'event': 'sticker.added',
        'data': {
          'sticker': {
            'id': 's1',
            'background': 'KEPT',
            'image': {'url': 'https://r2.example/s1.webp'},
          },
        },
      });
      expect(added, isA<StickerAdded>());
      expect((added! as StickerAdded).sticker.id, 's1');

      final updated = ChatFrameDecoder.stickerEvent({
        'event': 'sticker.updated',
        'data': {
          'sticker': {
            'id': 's1',
            'name': 'renamed',
            'background': 'KEPT',
            'image': {'url': 'https://r2.example/s1.webp'},
          },
        },
      });
      expect((updated! as StickerUpdated).sticker.name, 'renamed');

      final removed = ChatFrameDecoder.stickerEvent({
        'event': 'sticker.removed',
        'data': {'stickerId': 's1'},
      });
      expect((removed! as StickerRemoved).stickerId, 's1');
    });

    test('a sticker frame is not a ChatEvent, and a chat frame is not a sticker event', () {
      final frame = {
        'event': 'sticker.removed',
        'data': {'stickerId': 's1'},
      };
      expect(ChatFrameDecoder.decodeFrame(frame), isNull);
      expect(
        ChatFrameDecoder.stickerEvent({
          'event': 'message.deleted',
          'data': {'conversationId': 'c1', 'messageId': 'm1'},
        }),
        isNull,
      );
    });

    test('a malformed or unknown sticker frame decodes to null rather than throwing', () {
      expect(ChatFrameDecoder.stickerEvent({'event': 'sticker.added', 'data': 'not an object'}), isNull);
      expect(ChatFrameDecoder.stickerEvent({'event': 'sticker.added', 'data': <String, dynamic>{}}), isNull);
      expect(ChatFrameDecoder.stickerEvent({'event': 'sticker.removed', 'data': <String, dynamic>{}}), isNull);
      expect(
        ChatFrameDecoder.stickerEvent({'event': 'sticker.reordered', 'data': <String, dynamic>{}}),
        isNull,
      );
    });
  });
}
