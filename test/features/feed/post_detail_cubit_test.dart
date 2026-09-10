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
import 'package:yello_social_app/features/profile/domain/usecases/profile_usecases.dart';

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

  setUpAll(() {
    registerFallbackValue(const PostIdParams('p1'));
    registerFallbackValue(buildPost());
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
    when(() => getMe(const NoParams())).thenAnswer((_) async => Right(buildUser()));
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
    seed: () => PostDetailState(status: PostDetailStatus.loaded, post: buildPost(id: 'p1', likeCount: 0)),
    act: (cubit) {
      when(
        () => likePost(any()),
      ).thenAnswer((_) async => Right(buildPost(id: 'p1', likeCount: 1, viewerReaction: 'LIKE')));
      return cubit.toggleLike();
    },
    expect: () => [
      predicate<PostDetailState>((s) => s.post?.likedByMe == true && s.post?.likeCount == 1),
    ],
  );

  blocTest<PostDetailCubit, PostDetailState>(
    'toggleLike ignores a second tap while the first is still in flight — '
    'regression for the double-count bug (post detail showing one more '
    'like than the feed for the very same post, because one real tap on '
    'the like button produced two "add LIKE" requests)',
    build: buildCubit,
    seed: () => PostDetailState(status: PostDetailStatus.loaded, post: buildPost(id: 'p1', likeCount: 0)),
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
}
