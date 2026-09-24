import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/core/usecase/usecase.dart';
import 'package:yello_social_app/features/feed/domain/entities/story_entity.dart';
import 'package:yello_social_app/features/feed/domain/usecases/story_usecases.dart';
import 'package:yello_social_app/features/feed/presentation/bloc/story_cubit.dart';

class _MockGetRail extends Mock implements GetStoryRailUseCase {}

class _MockGetUserStories extends Mock implements GetUserStoriesUseCase {}

class _MockGetStory extends Mock implements GetStoryUseCase {}

class _MockMarkViewed extends Mock implements MarkStoryViewedUseCase {}

class _MockDeleteStory extends Mock implements DeleteStoryUseCase {}

class _MockReplyToStory extends Mock implements ReplyToStoryUseCase {}

StoryEntity _story(
  String id, {
  String authorId = 'u1',
  bool seen = false,
  bool owner = false,
  DateTime? expiresAt,
}) {
  return StoryEntity(
    id: id,
    author: StoryAuthorEntity(id: authorId, username: authorId),
    type: StoryType.text,
    text: id,
    background: StoryBackground.cover0,
    createdAt: DateTime(2026, 9, 23, 10),
    expiresAt: expiresAt ?? DateTime(2100),
    isSeen: seen,
    isOwner: owner,
  );
}

StoryRingEntity _ring(String authorId, List<StoryEntity> stories, {bool isMine = false}) => StoryRingEntity(
      author: StoryAuthorEntity(id: authorId, username: authorId),
      stories: stories,
      hasUnseen: stories.any((s) => !s.isSeen),
      latestAt: DateTime(2026, 9, 23, 10),
      isMine: isMine,
    );

void main() {
  late _MockGetRail getRail;
  late _MockGetUserStories getUserStories;
  late _MockGetStory getStory;
  late _MockMarkViewed markViewed;
  late _MockDeleteStory deleteStory;
  late _MockReplyToStory replyToStory;

  setUpAll(() {
    registerFallbackValue(const ReplyToStoryParams(storyId: '', text: '', clientId: ''));
  });

  setUp(() {
    getRail = _MockGetRail();
    getUserStories = _MockGetUserStories();
    getStory = _MockGetStory();
    markViewed = _MockMarkViewed();
    deleteStory = _MockDeleteStory();
    replyToStory = _MockReplyToStory();
    when(() => markViewed(any())).thenAnswer((_) async => const Right(null));
  });

  StoryCubit buildCubit() => StoryCubit(
        getRail: getRail,
        getUserStories: getUserStories,
        getStory: getStory,
        markViewed: markViewed,
        deleteStory: deleteStory,
        replyToStory: replyToStory,
      );

  /// The rail two friends deep, with your own ring first.
  StoryRailEntity railFixture() => StoryRailEntity(
        mine: _ring('me', [_story('m1', authorId: 'me', seen: true, owner: true)], isMine: true),
        rings: [
          _ring('u1', [_story('a'), _story('b')]),
          _ring('u2', [_story('c')]),
        ],
      );

  test('opens the ring belonging to the tapped author, not a rail index', () async {
    when(() => getRail(const NoParams())).thenAnswer((_) async => Right(railFixture()));

    final cubit = buildCubit();
    await cubit.start('u2');

    expect(cubit.state.status, StoryStatus.playing);
    expect(cubit.state.currentRing!.author.id, 'u2');
    expect(cubit.state.currentStory!.id, 'c');
    await cubit.close();
  });

  test('falls back to the first ring when that author has dropped out of the rail', () async {
    when(() => getRail(const NoParams())).thenAnswer((_) async => Right(railFixture()));

    final cubit = buildCubit();
    await cubit.start('someone-whose-story-just-expired');

    expect(cubit.state.currentRing!.author.id, 'me');
    await cubit.close();
  });

  test('an empty rail finishes immediately rather than showing a blank frame', () async {
    when(() => getRail(const NoParams())).thenAnswer((_) async => const Right(StoryRailEntity.empty));

    final cubit = buildCubit();
    await cubit.start('u1');

    expect(cubit.state.status, StoryStatus.finished);
    await cubit.close();
  });

  test('next() walks the ring, then crosses into the following one, then finishes', () async {
    when(() => getRail(const NoParams())).thenAnswer((_) async => Right(railFixture()));

    final cubit = buildCubit();
    await cubit.start('u1');
    expect(cubit.state.currentStory!.id, 'a');

    cubit.next();
    expect(cubit.state.currentStory!.id, 'b');

    cubit.next();
    expect(cubit.state.currentRing!.author.id, 'u2');
    expect(cubit.state.currentStory!.id, 'c');

    cubit.next();
    expect(cubit.state.status, StoryStatus.finished);
    await cubit.close();
  });

  test('previous() on the very first slide restarts it instead of popping', () async {
    when(() => getRail(const NoParams())).thenAnswer((_) async => Right(railFixture()));

    final cubit = buildCubit();
    await cubit.start('me');

    cubit.previous();
    expect(cubit.state.status, StoryStatus.playing);
    expect(cubit.state.currentStory!.id, 'm1');
    await cubit.close();
  });

  test('marks each slide viewed once, and never marks your own', () async {
    when(() => getRail(const NoParams())).thenAnswer((_) async => Right(railFixture()));

    final cubit = buildCubit();
    await cubit.start('u1');

    cubit.next();
    cubit.previous();
    cubit.next();

    // Two distinct slides, three visits — `POST /view` is idempotent but
    // has a 120/min budget, so repeats are dropped client-side.
    verify(() => markViewed('a')).called(1);
    verify(() => markViewed('b')).called(1);
    verifyNever(() => markViewed('m1'));
    await cubit.close();
  });

  test('a seen slide flips locally, so the rail greys out without a refetch', () async {
    when(() => getRail(const NoParams())).thenAnswer((_) async => Right(railFixture()));

    final cubit = buildCubit();
    await cubit.start('u1');

    expect(cubit.state.currentStory!.isSeen, isTrue);
    expect(cubit.state.currentRing!.hasUnseen, isTrue, reason: 'slide "b" is still unseen');
    await cubit.close();
  });

  test('deleting your own last slide ends the viewer', () async {
    when(() => getRail(const NoParams())).thenAnswer(
      (_) async => Right(
        StoryRailEntity(mine: _ring('me', [_story('m1', authorId: 'me', seen: true, owner: true)], isMine: true)),
      ),
    );
    when(() => deleteStory('m1')).thenAnswer((_) async => const Right(null));

    final cubit = buildCubit();
    await cubit.start('me');
    final error = await cubit.deleteCurrent();

    expect(error, isNull);
    expect(cubit.state.status, StoryStatus.finished);
    await cubit.close();
  });

  test('a failed delete resumes playback and hands the message back', () async {
    when(() => getRail(const NoParams())).thenAnswer(
      (_) async => Right(
        StoryRailEntity(mine: _ring('me', [_story('m1', authorId: 'me', seen: true, owner: true)], isMine: true)),
      ),
    );
    when(() => deleteStory('m1')).thenAnswer((_) async => const Left(ServerFailure('Nope.')));

    final cubit = buildCubit();
    await cubit.start('me');
    final error = await cubit.deleteCurrent();

    expect(error, 'Nope.');
    expect(cubit.state.status, StoryStatus.playing);
    expect(cubit.state.paused, isFalse);
    await cubit.close();
  });

  test('deleting one slide of a multi-slide ring keeps playing the rest', () async {
    when(() => getRail(const NoParams())).thenAnswer(
      (_) async => Right(
        StoryRailEntity(
          mine: _ring(
            'me',
            [
              _story('m1', authorId: 'me', seen: true, owner: true),
              _story('m2', authorId: 'me', seen: true, owner: true),
            ],
            isMine: true,
          ),
        ),
      ),
    );
    when(() => deleteStory('m1')).thenAnswer((_) async => const Right(null));

    final cubit = buildCubit();
    await cubit.start('me');
    await cubit.deleteCurrent();

    expect(cubit.state.status, StoryStatus.playing);
    expect(cubit.state.currentRing!.stories.map((s) => s.id), ['m2']);
    await cubit.close();
  });

  test('a reply sends a fresh idempotency key and reports failures verbatim', () async {
    when(() => getRail(const NoParams())).thenAnswer((_) async => Right(railFixture()));
    when(() => replyToStory(any())).thenAnswer(
      (invocation) async {
        final params = invocation.positionalArguments.first as ReplyToStoryParams;
        return Right(
          StoryReplyReceipt(storyId: params.storyId, recipientId: 'u1', clientId: params.clientId),
        );
      },
    );

    final cubit = buildCubit();
    await cubit.start('u1');

    expect(await cubit.sendReply('  see you there!  '), isNull);
    final sent = verify(() => replyToStory(captureAny())).captured.cast<ReplyToStoryParams>();
    expect(sent.single.text, 'see you there!', reason: 'the server trims, but so do we');
    expect(sent.single.clientId, matches(RegExp(r'^c-[a-z0-9]+-[a-z0-9]{24}$')));
    expect(cubit.state.replying, isFalse);
    await cubit.close();
  });

  test('an empty reply is never sent', () async {
    when(() => getRail(const NoParams())).thenAnswer((_) async => Right(railFixture()));

    final cubit = buildCubit();
    await cubit.start('u1');

    expect(await cubit.sendReply('   '), isNull);
    verifyNever(() => replyToStory(any()));
    await cubit.close();
  });

  test('pause holds the slide and resume releases it', () async {
    when(() => getRail(const NoParams())).thenAnswer((_) async => Right(railFixture()));

    final cubit = buildCubit();
    await cubit.start('u1');

    cubit.pause();
    expect(cubit.state.paused, isTrue);
    cubit.resume();
    expect(cubit.state.paused, isFalse);
    await cubit.close();
  });

  test('a rail failure surfaces as an error, not an empty viewer', () async {
    when(() => getRail(const NoParams())).thenAnswer((_) async => const Left(NetworkFailure()));

    final cubit = buildCubit();
    await cubit.start('u1');

    expect(cubit.state.status, StoryStatus.error);
    expect(cubit.state.errorMessage, isNotEmpty);
    await cubit.close();
  });

  test('startForUser names the ring from the stories themselves, not the id it was given', () async {
    when(() => getUserStories('u9')).thenAnswer(
      (_) async => Right([
        StoryEntity(
          id: 'x',
          author: const StoryAuthorEntity(id: 'u9', username: 'dara', fullName: 'Dara Sok'),
          type: StoryType.text,
          text: 'hello',
          createdAt: DateTime(2026, 9, 23, 10),
          expiresAt: DateTime(2100),
        ),
      ]),
    );

    final cubit = buildCubit();
    await cubit.startForUser('u9');

    expect(cubit.state.currentRing!.author.displayName, 'Dara Sok');
    expect(cubit.state.rings.length, 1, reason: 'it plays that ring alone, not the whole rail');
    await cubit.close();
  });
}
