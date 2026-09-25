import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/core/usecase/usecase.dart';
import 'package:yello_social_app/features/feed/domain/entities/post_entity.dart';
import 'package:yello_social_app/features/feed/domain/usecases/add_comment_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/delete_comment_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/delete_post_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/get_comments_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/get_post_detail_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/get_share_link_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/like_post_usecase.dart';
import 'package:yello_social_app/features/feed/domain/usecases/react_usecases.dart';
import 'package:yello_social_app/features/feed/domain/usecases/update_post_usecase.dart';
import 'package:yello_social_app/features/feed/presentation/bloc/post_detail_cubit.dart';
import 'package:yello_social_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:yello_social_app/features/profile/domain/usecases/profile_usecases.dart';
import 'package:yello_social_app/features/safety/domain/usecases/safety_usecases.dart';

import '../../helpers/mock_data.dart';

class _MockGetPostDetail extends Mock implements GetPostDetailUseCase {}

class _MockGetComments extends Mock implements GetCommentsUseCase {}

class _MockAddComment extends Mock implements AddCommentUseCase {}

class _MockLikePost extends Mock implements LikePostUseCase {}

class _MockReactToPost extends Mock implements ReactToPostUseCase {}

class _MockReactToComment extends Mock implements ReactToCommentUseCase {}

class _MockGetReactionSummary extends Mock implements GetReactionSummaryUseCase {}

class _MockUpdatePost extends Mock implements UpdatePostUseCase {}

class _MockDeletePost extends Mock implements DeletePostUseCase {}

class _MockDeleteComment extends Mock implements DeleteCommentUseCase {}

class _MockGetShareLink extends Mock implements GetShareLinkUseCase {}

class _MockGetMe extends Mock implements GetMeUseCase {}

class _MockRepost extends Mock implements RepostUseCase {}

class _MockGetUserPosts extends Mock implements GetUserPostsUseCase {}

class _MockHidePost extends Mock implements HidePostUseCase {}

class _MockMuteUser extends Mock implements MuteUserUseCase {}

void main() {
  late _MockGetPostDetail getPostDetail;
  late _MockGetComments getComments;
  late _MockAddComment addComment;
  late _MockLikePost likePost;
  late _MockReactToPost reactToPost;
  late _MockReactToComment reactToComment;
  late _MockGetReactionSummary getReactionSummary;
  late _MockUpdatePost updatePost;
  late _MockDeletePost deletePost;
  late _MockDeleteComment deleteComment;
  late _MockGetShareLink getShareLink;
  late _MockGetMe getMe;
  late _MockRepost repost;
  late _MockGetUserPosts getUserPosts;
  late _MockHidePost hidePost;
  late _MockMuteUser muteUser;

  setUpAll(() {
    registerFallbackValue(const PostIdParams('p1'));
    registerFallbackValue(buildPost());
    registerFallbackValue(const RepostParams(postId: 'p1'));
    registerFallbackValue(const GetUserPostsParams(userId: 'u1'));
    registerFallbackValue(const HidePostParams('p1'));
    registerFallbackValue(const MuteParams('u1'));
  });

  setUp(() {
    getPostDetail = _MockGetPostDetail();
    getComments = _MockGetComments();
    addComment = _MockAddComment();
    likePost = _MockLikePost();
    reactToPost = _MockReactToPost();
    reactToComment = _MockReactToComment();
    getReactionSummary = _MockGetReactionSummary();
    updatePost = _MockUpdatePost();
    deletePost = _MockDeletePost();
    deleteComment = _MockDeleteComment();
    getShareLink = _MockGetShareLink();
    getMe = _MockGetMe();
    repost = _MockRepost();
    getUserPosts = _MockGetUserPosts();
    hidePost = _MockHidePost();
    muteUser = _MockMuteUser();
    when(() => getMe(const NoParams())).thenAnswer((_) async => Right(buildUser()));
    // Empty by default — `load()`'s repost-recovery scan (`_seedMyRepostId`)
    // stops on the first "no more pages" response, same as an account with
    // no reposts at all. Tests that care about an existing repost override
    // this.
    when(() => getUserPosts(any())).thenAnswer((_) async => const Right(UserPostsPage(posts: [], hasMore: false)));
  });

  PostDetailCubit buildCubit() => PostDetailCubit(
    postId: 'p1',
    getPostDetail: getPostDetail,
    getComments: getComments,
    addComment: addComment,
    likePost: likePost,
    reactToPost: reactToPost,
    reactToComment: reactToComment,
    getReactionSummary: getReactionSummary,
    updatePost: updatePost,
    deletePost: deletePost,
    deleteComment: deleteComment,
    getShareLink: getShareLink,
    getMe: getMe,
    repost: repost,
    getUserPosts: getUserPosts,
    hidePost: hidePost,
    muteUser: muteUser,
  );

  blocTest<PostDetailCubit, PostDetailState>(
    'load() fetches the post + first comments page and marks it loaded',
    build: buildCubit,
    act: (cubit) {
      when(() => getPostDetail(any())).thenAnswer(
        (_) async => Right(PostDetail(buildPost(id: 'p1', likeCount: 1, viewerReaction: 'LIKE'), const [], false)),
      );
      return cubit.load();
    },
    expect: () => [
      predicate<PostDetailState>((s) => s.status == PostDetailStatus.loading),
      predicate<PostDetailState>(
        (s) => s.status == PostDetailStatus.loaded && s.post?.id == 'p1' && s.post?.likeCount == 1,
      ),
      predicate<PostDetailState>((s) => s.currentUserId == 'u1'),
    ],
  );

  blocTest<PostDetailCubit, PostDetailState>(
    'toggleLike replaces state.post with the repository result',
    build: buildCubit,
    seed: () => PostDetailState(
      status: PostDetailStatus.loaded,
      post: buildPost(id: 'p1', likeCount: 0),
    ),
    act: (cubit) {
      when(
        () => likePost(any()),
      ).thenAnswer((_) async => Right(buildPost(id: 'p1', likeCount: 1, viewerReaction: 'LIKE')));
      return cubit.toggleLike();
    },
    expect: () => [predicate<PostDetailState>((s) => s.post?.likedByMe == true && s.post?.likeCount == 1)],
  );

  blocTest<PostDetailCubit, PostDetailState>(
    'toggleLike on a post the viewer reacted to with a non-LIKE type predicts '
    'a removal, not a switch to LIKE — see `FeedRepositoryImpl.toggleLike`',
    build: buildCubit,
    seed: () => PostDetailState(
      status: PostDetailStatus.loaded,
      post: buildPost(id: 'p1').copyWith(reactionCounts: const {'WOW': 1}, viewerReaction: 'WOW'),
    ),
    act: (cubit) {
      // Failing on purpose: the optimistic emit is what's under test, and a
      // rollback to the 😮 it started from proves it wasn't a switch to LIKE.
      when(() => likePost(any())).thenAnswer((_) async => const Left(ServerFailure()));
      return cubit.toggleLike();
    },
    expect: () => [
      predicate<PostDetailState>((s) => s.post?.viewerReactionType == null && s.post?.reactionTotal == 0),
      predicate<PostDetailState>(
        (s) => s.post?.viewerReactionType == ReactionType.wow && s.post?.reactionTotal == 1,
      ),
    ],
  );

  blocTest<PostDetailCubit, PostDetailState>(
    'toggleLike ignores a second tap while the first is still in flight — '
    'regression for the double-count bug (post detail showing one more '
    'like than the feed for the very same post, because one real tap on '
    'the like button produced two "add LIKE" requests)',
    build: buildCubit,
    seed: () => PostDetailState(
      status: PostDetailStatus.loaded,
      post: buildPost(id: 'p1', likeCount: 0),
    ),
    act: (cubit) async {
      final pending = Completer<Either<Failure, PostEntity>>();
      when(() => likePost(any())).thenAnswer((_) => pending.future);
      final first = cubit.toggleLike();
      final second = cubit.toggleLike();
      pending.complete(Right(buildPost(id: 'p1', likeCount: 1, viewerReaction: 'LIKE')));
      await Future.wait([first, second]);
    },
    verify: (_) => verify(() => likePost(any())).called(1),
  );

  blocTest<PostDetailCubit, PostDetailState>(
    'toggleRepost creates a repost and flips repostedByMe/repostCount',
    build: buildCubit,
    seed: () => PostDetailState(
      status: PostDetailStatus.loaded,
      post: buildPost(id: 'p1', repostCount: 2),
    ),
    act: (cubit) {
      when(() => repost(any())).thenAnswer(
        (_) async => Right(
          buildPost(
            id: 'r1',
            originalPost: buildPost(id: 'p1'),
          ),
        ),
      );
      return cubit.toggleRepost();
    },
    expect: () => [predicate<PostDetailState>((s) => s.post?.repostedByMe == true && s.post?.repostCount == 3)],
  );

  blocTest<PostDetailCubit, PostDetailState>(
    'toggleRepost cancels an existing repost via the id recovered by load()',
    build: buildCubit,
    act: (cubit) async {
      when(
        () => getPostDetail(any()),
      ).thenAnswer((_) async => Right(PostDetail(buildPost(id: 'p1', repostCount: 3), const [], false)));
      // Simulates a repost made in an earlier session — recovered by
      // `_seedMyRepostId` scanning the viewer's own posts.
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
      await cubit.load();
      when(() => deletePost('r1')).thenAnswer((_) async => const Right(null));
      await cubit.toggleRepost();
    },
    expect: () => [
      predicate<PostDetailState>((s) => s.status == PostDetailStatus.loading),
      predicate<PostDetailState>((s) => s.status == PostDetailStatus.loaded && s.post?.repostedByMe == false),
      predicate<PostDetailState>((s) => s.currentUserId == 'u1'),
      // load() recovers the earlier-session repost.
      predicate<PostDetailState>((s) => s.post?.repostedByMe == true),
      // toggleRepost() cancels it.
      predicate<PostDetailState>((s) => s.post?.repostedByMe == false && s.post?.repostCount == 2),
    ],
    verify: (_) => verify(() => deletePost('r1')).called(1),
  );

  blocTest<PostDetailCubit, PostDetailState>(
    'toggleRepost ignores a second tap while the first is still in flight',
    build: buildCubit,
    seed: () => PostDetailState(
      status: PostDetailStatus.loaded,
      post: buildPost(id: 'p1', repostCount: 0),
    ),
    act: (cubit) async {
      final pending = Completer<Either<Failure, PostEntity>>();
      when(() => repost(any())).thenAnswer((_) => pending.future);
      final first = cubit.toggleRepost();
      final second = cubit.toggleRepost();
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
}
