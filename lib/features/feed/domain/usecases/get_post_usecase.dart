import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/post_entity.dart';
import '../repositories/feed_repository.dart';
import 'like_post_usecase.dart';

/// Fetches one post without its comments — used where only the post itself
/// is needed (e.g. hydrating the Profile "Saved" tab from bookmarked ids).
class GetPostUseCase implements UseCase<PostEntity, PostIdParams> {
  GetPostUseCase(this._repository);
  final FeedRepository _repository;

  @override
  Future<Either<Failure, PostEntity>> call(PostIdParams params) => _repository.getPost(params.postId);
}
