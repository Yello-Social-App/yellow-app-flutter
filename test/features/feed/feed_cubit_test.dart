import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/core/usecase/usecase.dart';
import 'package:yello_social_app/features/feed/domain/repositories/feed_repository.dart';
import 'package:yello_social_app/features/feed/domain/usecases/get_feed_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/get_stories_usecase.dart';
import 'package:yello_social_app/features/feed/domain/entities/post_entity.dart';
import 'package:yello_social_app/features/feed/domain/usecases/delete_post_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/get_share_link_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/like_post_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/react_usecases.dart';
import 'package:yello_social_app/features/feed/domain/usecases/update_post_usecase.dart';
import 'package:yello_social_app/features/feed/presentation/bloc/feed_cubit.dart';
import 'package:yello_social_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:yello_social_app/features/profile/domain/usecases/profile_usecases.dart';

import '../../helpers/mock_data.dart';

class _MockGetFeed extends Mock implements GetFeedUseCase {}

class _MockGetStories extends Mock implements GetStoriesUseCase {}

class _MockLikePost extends Mock implements LikePostUseCase {}

class _MockReactToPost extends Mock implements ReactToPostUseCase {}

class _MockRepost extends Mock implements RepostUseCase {}

class _MockToggleSave extends Mock implements ToggleSaveUseCase {}

class _MockGetMe extends Mock implements GetMeUseCase {}

class _MockGetUserPosts extends Mock implements GetUserPostsUseCase {}

class _MockGetReactionSummary extends Mock implements GetReactionSummaryUseCase {}

class _MockUpdatePost extends Mock implements UpdatePostUseCase {}

class _MockDeletePost extends Mock implements DeletePostUseCase {}

class _MockGetShareLink extends Mock implements GetShareLinkUseCase {}

void main() {
  late _MockGetFeed getFeed;
  late _MockGetStories getStories;
  late _MockLikePost likePost;
  late _MockReactToPost reactToPost;
  late _MockRepost repost;
  late _MockToggleSave toggleSave;
  late _MockGetMe getMe;
  late _MockGetUserPosts getUserPosts;
  late _MockGetReactionSummary getReactionSummary;
  late _MockUpdatePost updatePost;
  late _MockDeletePost deletePost;
  late _MockGetShareLink getShareLink;

  setUpAll(() {
    registerFallbackValue(buildPost());
    registerFallbackValue(const GetFeedParams());
    registerFallbackValue(ReactToPostParams(post: buildPost(), type: ReactionType.like));
    registerFallbackValue(const UpdatePostParams(postId: ''));
    registerFallbackValue(const GetReactionSummaryParams(targetType: 'POST', targetId: ''));
    registerFallbackValue(const RepostParams(postId: ''));
    registerFallbackValue(const GetUserPostsParams(userId: ''));
  });

  setUp(() {
    getFeed = _MockGetFeed();
    getStories = _MockGetStories();
    likePost = _MockLikePost();
    reactToPost = _MockReactToPost();
    repost = _MockRepost();
    toggleSave = _MockToggleSave();
    getMe = _MockGetMe();
    getUserPosts = _MockGetUserPosts();
    getReactionSummary = _MockGetReactionSummary();
    updatePost = _MockUpdatePost();
    deletePost = _MockDeletePost();
    getShareLink = _MockGetShareLink();
    when(() => getStories(const NoParams())).thenAnswer((_) async => const Right([]));
    when(() => getMe(const NoParams())).thenAnswer((_) async => Right(buildUser()));
    // Default: the signed-in user has no posts/reposts of their own — most
    // tests don't care about repost-recovery, so this keeps `refresh()`'s
    // `_seedMyRepostIds` call a harmless no-op unless a test overrides it.
    when(() => getUserPosts(any())).thenAnswer((_) async => const Right(UserPostsPage(posts: [], hasMore: false)));
  });

  FeedCubit buildCubit() => FeedCubit(
    getFeed: getFeed,
    getStories: getStories,
    likePost: likePost,
    reactToPost: reactToPost,
    repost: repost,
    toggleSave: toggleSave,
    getMe: getMe,
    getUserPosts: getUserPosts,
    getReactionSummary: getReactionSummary,
    updatePost: updatePost,
    deletePost: deletePost,
    getShareLink: getShareLink,
  );

  blocTest<FeedCubit, FeedState>(
    'refresh() emits [loading, loaded] with the fetched page on success',
    build: () {
      when(
        () => getFeed(any()),
      ).thenAnswer((_) async => Right(FeedPage(posts: [buildPost()], hasMore: false, nextCursor: null)));
      return buildCubit();
    },
    act: (cubit) => cubit.refresh(),
    expect: () => [
      predicate<FeedState>((s) => s.status == FeedStatus.loading),
      predicate<FeedState>((s) => s.status == FeedStatus.loaded && s.posts.length == 1 && s.hasMore == false),
    ],
  );

  blocTest<FeedCubit, FeedState>(
    'refresh() emits [loading, error] when the feed fails to load',
    build: () {
      when(() => getFeed(any())).thenAnswer((_) async => const Left(NetworkFailure()));
      return buildCubit();
    },
    act: (cubit) => cubit.refresh(),
    expect: () => [
      predicate<FeedState>((s) => s.status == FeedStatus.loading),
      predicate<FeedState>((s) => s.status == FeedStatus.error && s.errorMessage == const NetworkFailure().message),
    ],
  );

  blocTest<FeedCubit, FeedState>(
    'refresh() populates `me` from GetMeUseCase, for the header/composer avatars',
    build: () {
      when(
        () => getFeed(any()),
      ).thenAnswer((_) async => Right(FeedPage(posts: [buildPost()], hasMore: false, nextCursor: null)));
      when(
        () => getMe(const NoParams()),
      ).thenAnswer((_) async => Right(buildUser(id: 'me-1', fullName: 'Kofi Boateng')));
      return buildCubit();
    },
    act: (cubit) => cubit.refresh(),
    expect: () => [
      predicate<FeedState>((s) => s.status == FeedStatus.loading),
      predicate<FeedState>(
        (s) => s.status == FeedStatus.loaded && s.me?.id == 'me-1' && s.me?.fullName == 'Kofi Boateng',
      ),
    ],
  );

  blocTest<FeedCubit, FeedState>(
    'refresh() still loads posts when GetMeUseCase fails — best-effort, does not block the feed',
    build: () {
      when(
        () => getFeed(any()),
      ).thenAnswer((_) async => Right(FeedPage(posts: [buildPost()], hasMore: false, nextCursor: null)));
      when(() => getMe(const NoParams())).thenAnswer((_) async => const Left(NetworkFailure()));
      return buildCubit();
    },
    act: (cubit) => cubit.refresh(),
    expect: () => [
      predicate<FeedState>((s) => s.status == FeedStatus.loading),
      predicate<FeedState>((s) => s.status == FeedStatus.loaded && s.posts.length == 1 && s.me == null),
    ],
  );

  blocTest<FeedCubit, FeedState>(
    'toggleLike replaces just the affected post with the repository result',
    build: buildCubit,
    seed: () => FeedState(
      status: FeedStatus.loaded,
      posts: [
        buildPost(id: 'p1', likeCount: 0),
        buildPost(id: 'p2', likeCount: 5),
      ],
    ),
    act: (cubit) {
      when(
        () => likePost(any()),
      ).thenAnswer((_) async => Right(buildPost(id: 'p1', likeCount: 1, viewerReaction: 'LIKE')));
      return cubit.toggleLike(buildPost(id: 'p1', likeCount: 0));
    },
    expect: () => [
      predicate<FeedState>((s) {
        final p1 = s.posts.firstWhere((p) => p.id == 'p1');
        final p2 = s.posts.firstWhere((p) => p.id == 'p2');
        return p1.likedByMe && p1.likeCount == 1 && p2.likeCount == 5;
      }),
    ],
  );

  blocTest<FeedCubit, FeedState>(
    'toggleLike leaves state unchanged when the repository call fails',
    build: buildCubit,
    seed: () => FeedState(
      status: FeedStatus.loaded,
      posts: [buildPost(id: 'p1', likeCount: 0)],
    ),
    act: (cubit) {
      when(() => likePost(any())).thenAnswer((_) async => const Left(ServerFailure()));
      return cubit.toggleLike(buildPost(id: 'p1', likeCount: 0));
    },
    expect: () => <FeedState>[],
  );

  blocTest<FeedCubit, FeedState>(
    'react replaces just the affected post with the repository result',
    build: buildCubit,
    seed: () => FeedState(
      status: FeedStatus.loaded,
      posts: [
        buildPost(id: 'p1', likeCount: 0),
        buildPost(id: 'p2', likeCount: 5),
      ],
    ),
    act: (cubit) {
      when(
        () => reactToPost(any()),
      ).thenAnswer((_) async => Right(buildPost(id: 'p1', likeCount: 0, viewerReaction: 'LOVE')));
      return cubit.react(buildPost(id: 'p1', likeCount: 0), ReactionType.love);
    },
    expect: () => [
      predicate<FeedState>((s) {
        final p1 = s.posts.firstWhere((p) => p.id == 'p1');
        final p2 = s.posts.firstWhere((p) => p.id == 'p2');
        return p1.viewerReactionType == ReactionType.love && p2.likeCount == 5;
      }),
    ],
  );

  blocTest<FeedCubit, FeedState>(
    'toggleLike ignores a second tap on the same post while the first is still '
    'in flight, instead of sending a second "add LIKE" request (regression for '
    "the double-count bug: two real requests for one tap can leave the "
    'backend with 2 reactions even though the tapped post only shows 1 '
    'locally until the next fetch)',
    build: buildCubit,
    seed: () => FeedState(
      status: FeedStatus.loaded,
      posts: [buildPost(id: 'p1', likeCount: 0)],
    ),
    act: (cubit) async {
      final pending = Completer<Either<Failure, PostEntity>>();
      when(() => likePost(any())).thenAnswer((_) => pending.future);
      final first = cubit.toggleLike(buildPost(id: 'p1', likeCount: 0));
      final second = cubit.toggleLike(buildPost(id: 'p1', likeCount: 0));
      pending.complete(Right(buildPost(id: 'p1', likeCount: 1, viewerReaction: 'LIKE')));
      await Future.wait([first, second]);
    },
    verify: (_) => verify(() => likePost(any())).called(1),
  );

  blocTest<FeedCubit, FeedState>(
    'react on a post is also ignored while a toggleLike for that same post is '
    'still pending — both mutate the one underlying reaction, so they share '
    'the in-flight guard',
    build: buildCubit,
    seed: () => FeedState(
      status: FeedStatus.loaded,
      posts: [buildPost(id: 'p1', likeCount: 0)],
    ),
    act: (cubit) async {
      final pending = Completer<Either<Failure, PostEntity>>();
      when(() => likePost(any())).thenAnswer((_) => pending.future);
      final first = cubit.toggleLike(buildPost(id: 'p1', likeCount: 0));
      await cubit.react(buildPost(id: 'p1', likeCount: 0), ReactionType.love);
      pending.complete(Right(buildPost(id: 'p1', likeCount: 1, viewerReaction: 'LIKE')));
      await first;
    },
    verify: (_) => verifyNever(() => reactToPost(any())),
  );

  blocTest<FeedCubit, FeedState>(
    'updatePost replaces the edited post in place on success',
    build: buildCubit,
    seed: () => FeedState(
      status: FeedStatus.loaded,
      posts: [
        buildPost(id: 'p1', content: 'old'),
        buildPost(id: 'p2', content: 'untouched'),
      ],
    ),
    act: (cubit) {
      when(() => updatePost(any())).thenAnswer((_) async => Right(buildPost(id: 'p1', content: 'new')));
      return cubit.updatePost('p1', content: 'new');
    },
    expect: () => [
      predicate<FeedState>((s) {
        final p1 = s.posts.firstWhere((p) => p.id == 'p1');
        final p2 = s.posts.firstWhere((p) => p.id == 'p2');
        return p1.content == 'new' && p2.content == 'untouched';
      }),
    ],
  );

  blocTest<FeedCubit, FeedState>(
    'updatePost leaves state unchanged when the repository call fails',
    build: buildCubit,
    seed: () => FeedState(
      status: FeedStatus.loaded,
      posts: [buildPost(id: 'p1', content: 'old')],
    ),
    act: (cubit) {
      when(() => updatePost(any())).thenAnswer((_) async => const Left(ServerFailure()));
      return cubit.updatePost('p1', content: 'new');
    },
    expect: () => <FeedState>[],
  );

  blocTest<FeedCubit, FeedState>(
    'deletePost removes the post from the feed on success',
    build: buildCubit,
    seed: () => FeedState(
      status: FeedStatus.loaded,
      posts: [
        buildPost(id: 'p1'),
        buildPost(id: 'p2'),
      ],
    ),
    act: (cubit) {
      when(() => deletePost(any())).thenAnswer((_) async => const Right(null));
      return cubit.deletePost('p1');
    },
    expect: () => [predicate<FeedState>((s) => s.posts.length == 1 && s.posts.single.id == 'p2')],
  );

  blocTest<FeedCubit, FeedState>(
    'deletePost leaves the feed unchanged when the repository call fails',
    build: buildCubit,
    seed: () => FeedState(
      status: FeedStatus.loaded,
      posts: [buildPost(id: 'p1')],
    ),
    act: (cubit) {
      when(() => deletePost(any())).thenAnswer((_) async => const Left(ServerFailure()));
      return cubit.deletePost('p1');
    },
    expect: () => <FeedState>[],
  );

  group('toggleRepost', () {
    blocTest<FeedCubit, FeedState>(
      'reposting flips repostedByMe, increments the count, and prepends the new repost to the feed',
      build: buildCubit,
      seed: () => FeedState(
        status: FeedStatus.loaded,
        posts: [buildPost(id: 'p1')],
      ),
      act: (cubit) async {
        when(() => repost(any())).thenAnswer(
          (_) async => Right(
            buildPost(
              id: 'r1',
              originalPost: buildPost(id: 'p1'),
            ),
          ),
        );
        await cubit.toggleRepost(buildPost(id: 'p1'));
      },
      verify: (cubit) {
        final original = cubit.state.posts.firstWhere((p) => p.id == 'p1');
        expect(cubit.state.posts.length, 2);
        expect(cubit.state.posts.first.id, 'r1');
        expect(original.repostedByMe, isTrue);
        expect(original.repostCount, 1);
      },
    );

    blocTest<FeedCubit, FeedState>(
      'tapping again on an already-reposted post cancels it: deletes the repost, removes it '
      'from the feed, and flips repostedByMe back off — the toggle this replaced the old '
      'always-create "repostPost" with (regression: repeatedly tapping used to pile up unbounded '
      'reposts with no way back)',
      build: buildCubit,
      seed: () => FeedState(
        status: FeedStatus.loaded,
        posts: [buildPost(id: 'p1')],
      ),
      act: (cubit) async {
        when(() => repost(any())).thenAnswer(
          (_) async => Right(
            buildPost(
              id: 'r1',
              originalPost: buildPost(id: 'p1'),
            ),
          ),
        );
        when(() => deletePost(any())).thenAnswer((_) async => const Right(null));
        await cubit.toggleRepost(buildPost(id: 'p1'));
        final reposted = cubit.state.posts.firstWhere((p) => p.id == 'p1');
        await cubit.toggleRepost(reposted);
      },
      verify: (cubit) {
        expect(cubit.state.posts.length, 1);
        expect(cubit.state.posts.single.id, 'p1');
        expect(cubit.state.posts.single.repostedByMe, isFalse);
        expect(cubit.state.posts.single.repostCount, 0);
        verify(() => deletePost('r1')).called(1);
      },
    );

    blocTest<FeedCubit, FeedState>(
      'a second tap on the same post while a repost is still in flight is ignored, same '
      'in-flight guard as toggleLike',
      build: buildCubit,
      seed: () => FeedState(
        status: FeedStatus.loaded,
        posts: [buildPost(id: 'p1')],
      ),
      act: (cubit) async {
        final pending = Completer<Either<Failure, PostEntity>>();
        when(() => repost(any())).thenAnswer((_) => pending.future);
        final first = cubit.toggleRepost(buildPost(id: 'p1'));
        final second = cubit.toggleRepost(buildPost(id: 'p1'));
        pending.complete(
          Right(
            buildPost(
              id: 'r1',
              originalPost: buildPost(id: 'p1'),
            ),
          ),
        );
        await Future.wait([first, second]);
      },
      verify: (_) => verify(() => repost(any())).called(1),
    );
  });

  group('repost state survives an app restart (regression)', () {
    blocTest<FeedCubit, FeedState>(
      'refresh() marks a post as repostedByMe when the viewer already has a repost of it '
      'from an earlier session — recovered from GetUserPostsUseCase instead of left at the '
      'default `false` every fresh cubit starts at. Regression for: closing and reopening '
      'the app reset the repost pill, letting the same post be reposted a second time.',
      build: () {
        when(
          () => getFeed(any()),
        ).thenAnswer((_) async => Right(FeedPage(posts: [buildPost(id: 'p1')], hasMore: false, nextCursor: null)));
        when(() => getMe(const NoParams())).thenAnswer((_) async => Right(buildUser(id: 'u1')));
        when(() => getUserPosts(any())).thenAnswer(
          (_) async => Right(
            UserPostsPage(
              posts: [
                buildPost(
                  id: 'r1',
                  originalPost: buildPost(id: 'p1'),
                ),
              ],
              hasMore: false,
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.refresh(),
      verify: (cubit) {
        final p1 = cubit.state.posts.firstWhere((p) => p.id == 'p1');
        expect(p1.repostedByMe, isTrue);
      },
    );

    blocTest<FeedCubit, FeedState>(
      'toggleRepost on a post recovered as already-reposted cancels the existing repost '
      '(DELETE) instead of creating a duplicate one',
      build: () {
        when(
          () => getFeed(any()),
        ).thenAnswer((_) async => Right(FeedPage(posts: [buildPost(id: 'p1')], hasMore: false, nextCursor: null)));
        when(() => getMe(const NoParams())).thenAnswer((_) async => Right(buildUser(id: 'u1')));
        when(() => getUserPosts(any())).thenAnswer(
          (_) async => Right(
            UserPostsPage(
              posts: [
                buildPost(
                  id: 'r1',
                  originalPost: buildPost(id: 'p1'),
                ),
              ],
              hasMore: false,
            ),
          ),
        );
        when(() => deletePost(any())).thenAnswer((_) async => const Right(null));
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.refresh();
        final p1 = cubit.state.posts.firstWhere((p) => p.id == 'p1');
        await cubit.toggleRepost(p1);
      },
      verify: (_) {
        verify(() => deletePost('r1')).called(1);
        verifyNever(() => repost(any()));
      },
    );
  });
}
