import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/comment_entity.dart';
import '../entities/post_entity.dart';
import '../repositories/feed_repository.dart';
import 'like_post_usecase.dart';

class PostDetail {
  const PostDetail(this.post, this.comments, this.hasMoreComments);
  final PostEntity post;
  final List<CommentEntity> comments;
  final bool hasMoreComments;
}

/// Fetches a single post plus its first page of comments in one call, for
/// the deep-linkable post-detail overlay (`/post/:postId`).
class GetPostDetailUseCase implements UseCase<PostDetail, PostIdParams> {
  GetPostDetailUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, PostDetail>> call(PostIdParams params) async {
    Failure? failure;
    PostEntity? post;
    CommentsPage comments = const CommentsPage(comments: [], hasMore: false);

    (await _repository.getPost(params.postId)).fold((l) => failure = l, (r) => post = r);
    if (failure != null) return Left(failure!);

    (await _repository.getComments(params.postId)).fold((l) => failure = l, (r) => comments = r);
    if (failure != null) return Left(failure!);

    return Right(PostDetail(post!, comments.comments, comments.hasMore));
  }
}
