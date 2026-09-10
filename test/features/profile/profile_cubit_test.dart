import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/features/feed/domain/usecases/delete_post_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/get_post_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/get_saved_post_ids_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/like_post_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/react_usecases.dart';
import 'package:yello_social_app/features/friends/domain/usecases/friends_usecases.dart';
import 'package:yello_social_app/features/profile/domain/usecases/profile_usecases.dart';
import 'package:yello_social_app/features/profile/presentation/bloc/profile_cubit.dart';

import '../../helpers/mock_data.dart';

class _MockGetMe extends Mock implements GetMeUseCase {}

class _MockUpdateProfile extends Mock implements UpdateProfileUseCase {}

class _MockUpdateAvatar extends Mock implements UpdateAvatarUseCase {}

class _MockGetUserPosts extends Mock implements GetUserPostsUseCase {}

class _MockGetSavedPostIds extends Mock implements GetSavedPostIdsUseCase {}

class _MockGetPost extends Mock implements GetPostUseCase {}

class _MockGetFriends extends Mock implements GetFriendsUseCase {}

class _MockLikePost extends Mock implements LikePostUseCase {}

class _MockReactToPost extends Mock implements ReactToPostUseCase {}

class _MockRepost extends Mock implements RepostUseCase {}

class _MockDeletePost extends Mock implements DeletePostUseCase {}

class _MockToggleSave extends Mock implements ToggleSaveUseCase {}

void main() {
  late _MockGetMe getMe;
  late _MockUpdateProfile updateProfile;
  late _MockUpdateAvatar updateAvatar;
  late _MockGetUserPosts getUserPosts;
  late _MockGetSavedPostIds getSavedPostIds;
  late _MockGetPost getPost;
  late _MockGetFriends getFriends;
  late _MockLikePost likePost;
  late _MockReactToPost reactToPost;
  late _MockRepost repost;
  late _MockDeletePost deletePost;
  late _MockToggleSave toggleSave;

  setUpAll(() {
    registerFallbackValue(const UpdateProfileParams());
    registerFallbackValue(const RepostParams(postId: ''));
  });

  setUp(() {
    getMe = _MockGetMe();
    updateProfile = _MockUpdateProfile();
    updateAvatar = _MockUpdateAvatar();
    getUserPosts = _MockGetUserPosts();
    getSavedPostIds = _MockGetSavedPostIds();
    getPost = _MockGetPost();
    getFriends = _MockGetFriends();
    likePost = _MockLikePost();
    reactToPost = _MockReactToPost();
    repost = _MockRepost();
    deletePost = _MockDeletePost();
    toggleSave = _MockToggleSave();
  });

  ProfileCubit buildCubit() => ProfileCubit(
    getMe: getMe,
    updateProfile: updateProfile,
    updateAvatar: updateAvatar,
    getUserPosts: getUserPosts,
    getSavedPostIds: getSavedPostIds,
    getPost: getPost,
    getFriends: getFriends,
    likePost: likePost,
    reactToPost: reactToPost,
    repost: repost,
    deletePost: deletePost,
    toggleSave: toggleSave,
  );

  group('updateProfile', () {
    blocTest<ProfileCubit, ProfileState>(
      'returns true and stores the updated user on success',
      build: buildCubit,
      setUp: () {
        when(() => updateProfile(any())).thenAnswer((_) async => Right(buildUser(id: 'u1', fullName: 'New Name')));
      },
      act: (cubit) => cubit.updateProfile(fullName: 'New Name'),
      verify: (cubit) {
        expect(cubit.state.user?.fullName, 'New Name');
        expect(cubit.state.errorMessage, isNull);
      },
    );

    blocTest<ProfileCubit, ProfileState>(
      'returns false and records the failure message on failure',
      build: buildCubit,
      setUp: () {
        when(
          () => updateProfile(any()),
        ).thenAnswer((_) async => const Left(ValidationFailure('Username already taken.')));
      },
      act: (cubit) => cubit.updateProfile(username: 'taken'),
      verify: (cubit) {
        expect(cubit.state.errorMessage, 'Username already taken.');
      },
    );

    test('the returned bool matches success/failure so callers can branch on it', () async {
      final cubit = buildCubit();
      when(() => updateProfile(any())).thenAnswer((_) async => Right(buildUser(id: 'u1')));
      expect(await cubit.updateProfile(fullName: 'A'), isTrue);

      when(() => updateProfile(any())).thenAnswer((_) async => const Left(ServerFailure()));
      expect(await cubit.updateProfile(fullName: 'B'), isFalse);
    });
  });

  group('toggleRepost', () {
    blocTest<ProfileCubit, ProfileState>(
      'reposting flips repostedByMe, increments the count, and prepends the new repost into myPosts',
      build: buildCubit,
      seed: () => ProfileState(
        status: ProfileStatus.loaded,
        myPosts: [buildPost(id: 'p1')],
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
        final original = cubit.state.myPosts.firstWhere((p) => p.id == 'p1');
        expect(cubit.state.myPosts.length, 2);
        expect(cubit.state.myPosts.first.id, 'r1');
        expect(original.repostedByMe, isTrue);
        expect(original.repostCount, 1);
      },
    );

    blocTest<ProfileCubit, ProfileState>(
      'tapping again on an already-reposted post cancels it: deletes the repost, drops it from '
      'myPosts, and flips repostedByMe back off — the toggle this replaced the old always-create '
      '"repostPost" with',
      build: buildCubit,
      seed: () => ProfileState(
        status: ProfileStatus.loaded,
        myPosts: [buildPost(id: 'p1')],
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
        await cubit.toggleRepost(cubit.state.myPosts.firstWhere((p) => p.id == 'p1'));
      },
      verify: (cubit) {
        expect(cubit.state.myPosts.length, 1);
        expect(cubit.state.myPosts.single.id, 'p1');
        expect(cubit.state.myPosts.single.repostedByMe, isFalse);
        expect(cubit.state.myPosts.single.repostCount, 0);
        verify(() => deletePost('r1')).called(1);
      },
    );
  });
}
