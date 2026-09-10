import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/core/usecase/usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/delete_post_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/like_post_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/react_usecases.dart';
import 'package:yello_social_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:yello_social_app/features/profile/domain/usecases/profile_usecases.dart';
import 'package:yello_social_app/features/profile/presentation/bloc/shared_posts_cubit.dart';

import '../../helpers/mock_data.dart';

class _MockGetMe extends Mock implements GetMeUseCase {}

class _MockGetUserPosts extends Mock implements GetUserPostsUseCase {}

class _MockLikePost extends Mock implements LikePostUseCase {}

class _MockReactToPost extends Mock implements ReactToPostUseCase {}

class _MockToggleSave extends Mock implements ToggleSaveUseCase {}

class _MockRepost extends Mock implements RepostUseCase {}

class _MockDeletePost extends Mock implements DeletePostUseCase {}

void main() {
  late _MockGetMe getMe;
  late _MockGetUserPosts getUserPosts;
  late _MockLikePost likePost;
  late _MockReactToPost reactToPost;
  late _MockToggleSave toggleSave;
  late _MockRepost repost;
  late _MockDeletePost deletePost;

  setUpAll(() {
    registerFallbackValue(const GetUserPostsParams(userId: 'u1'));
    registerFallbackValue(buildPost());
    registerFallbackValue(const RepostParams(postId: ''));
  });

  setUp(() {
    getMe = _MockGetMe();
    getUserPosts = _MockGetUserPosts();
    likePost = _MockLikePost();
    reactToPost = _MockReactToPost();
    toggleSave = _MockToggleSave();
    repost = _MockRepost();
    deletePost = _MockDeletePost();
    when(() => getMe(const NoParams())).thenAnswer((_) async => Right(buildUser(id: 'u1')));
  });

  SharedPostsCubit buildCubit() => SharedPostsCubit(
    getMe: getMe,
    getUserPosts: getUserPosts,
    likePost: likePost,
    reactToPost: reactToPost,
    toggleSave: toggleSave,
    repost: repost,
    deletePost: deletePost,
  );

  final original = buildPost(id: 'original');

  blocTest<SharedPostsCubit, SharedPostsState>(
    'load() fetches the signed-in user\'s posts and keeps only the reposts',
    build: buildCubit,
    act: (cubit) {
      when(() => getUserPosts(const GetUserPostsParams(userId: 'u1'))).thenAnswer(
        (_) async => Right(
          UserPostsPage(
            posts: [
              buildPost(id: 'authored'), // not a repost — dropped
              buildPost(id: 'shared', originalPost: original),
            ],
            hasMore: false,
          ),
        ),
      );
      return cubit.load();
    },
    expect: () => [
      predicate<SharedPostsState>((s) => s.status == SharedPostsStatus.loading),
      predicate<SharedPostsState>(
        (s) => s.status == SharedPostsStatus.loaded && s.posts.length == 1 && s.posts.single.id == 'shared',
      ),
    ],
  );

  blocTest<SharedPostsCubit, SharedPostsState>(
    'load() emits an error when GetMeUseCase fails, without calling GetUserPostsUseCase',
    build: buildCubit,
    act: (cubit) {
      when(() => getMe(const NoParams())).thenAnswer((_) async => const Left(NetworkFailure()));
      return cubit.load();
    },
    expect: () => [
      predicate<SharedPostsState>((s) => s.status == SharedPostsStatus.loading),
      predicate<SharedPostsState>(
        (s) => s.status == SharedPostsStatus.error && s.errorMessage == const NetworkFailure().message,
      ),
    ],
    verify: (_) => verifyNever(() => getUserPosts(any())),
  );

  blocTest<SharedPostsCubit, SharedPostsState>(
    'toggleLike replaces just the affected post with the repository result',
    build: buildCubit,
    seed: () => SharedPostsState(
      status: SharedPostsStatus.loaded,
      posts: [buildPost(id: 'shared', originalPost: original, likeCount: 0)],
    ),
    act: (cubit) {
      when(() => likePost(any())).thenAnswer(
        (_) async => Right(buildPost(id: 'shared', originalPost: original, likeCount: 1, viewerReaction: 'LIKE')),
      );
      return cubit.toggleLike(buildPost(id: 'shared', originalPost: original, likeCount: 0));
    },
    expect: () => [predicate<SharedPostsState>((s) => s.posts.single.likedByMe && s.posts.single.likeCount == 1)],
  );

  group('toggleRepost', () {
    blocTest<SharedPostsCubit, SharedPostsState>(
      'reposting flips repostedByMe and increments the count on the tapped card',
      build: buildCubit,
      seed: () => SharedPostsState(
        status: SharedPostsStatus.loaded,
        posts: [buildPost(id: 'shared', originalPost: original)],
      ),
      act: (cubit) {
        when(() => repost(any())).thenAnswer((_) async => Right(buildPost(id: 'r1', originalPost: original)));
        return cubit.toggleRepost(buildPost(id: 'shared', originalPost: original));
      },
      expect: () => [
        predicate<SharedPostsState>((s) => s.posts.single.repostedByMe && s.posts.single.repostCount == 1),
      ],
    );

    blocTest<SharedPostsCubit, SharedPostsState>(
      'tapping again on an already-reposted card cancels it: deletes the repost and flips '
      'repostedByMe back off',
      build: buildCubit,
      seed: () => SharedPostsState(
        status: SharedPostsStatus.loaded,
        posts: [buildPost(id: 'shared', originalPost: original)],
      ),
      act: (cubit) async {
        when(() => repost(any())).thenAnswer((_) async => Right(buildPost(id: 'r1', originalPost: original)));
        when(() => deletePost(any())).thenAnswer((_) async => const Right(null));
        await cubit.toggleRepost(buildPost(id: 'shared', originalPost: original));
        await cubit.toggleRepost(cubit.state.posts.single);
      },
      verify: (cubit) {
        expect(cubit.state.posts.single.repostedByMe, isFalse);
        expect(cubit.state.posts.single.repostCount, 0);
        verify(() => deletePost('r1')).called(1);
      },
    );
  });
}
