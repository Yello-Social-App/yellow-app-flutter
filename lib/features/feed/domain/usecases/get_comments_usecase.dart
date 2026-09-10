import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/feed_repository.dart';

class GetCommentsParams extends Equatable {
  const GetCommentsParams({required this.postId, this.page = 0});
  final String postId;
  final int page;

  @override
  List<Object?> get props => [postId, page];
}

/// One page of a post's (top-level) comments — `GetPostDetailUseCase`
/// already fetches page 0 alongside the post itself; this is what
/// `PostDetailCubit.loadMoreComments` calls for page 1+, since re-running
/// `GetPostDetailUseCase` on every "load more" tap would needlessly
/// re-fetch the post itself too.
class GetCommentsUseCase implements UseCase<CommentsPage, GetCommentsParams> {
  GetCommentsUseCase(this._repository);
  final FeedRepository _repository;

  @override
  Future<Either<Failure, CommentsPage>> call(GetCommentsParams params) =>
      _repository.getComments(params.postId, page: params.page);
}
