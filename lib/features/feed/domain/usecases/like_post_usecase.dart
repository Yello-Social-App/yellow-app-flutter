import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/post_entity.dart';
import '../repositories/feed_repository.dart';

class PostIdParams extends Equatable {
  const PostIdParams(this.postId);
  final String postId;

  @override
  List<Object?> get props => [postId];
}

/// Toggles the current user's `LIKE` reaction. Takes the whole [PostEntity]
/// (not just its id) because the repository needs to know the *current*
/// `viewerReaction` to decide PUT-to-react vs. DELETE-to-unreact.
class LikePostUseCase implements UseCase<PostEntity, PostEntity> {
  LikePostUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, PostEntity>> call(PostEntity post) => _repository.toggleLike(post);
}

class RepostParams extends Equatable {
  const RepostParams({required this.postId, this.content});
  final String postId;
  final String? content;

  @override
  List<Object?> get props => [postId, content];
}

class RepostUseCase implements UseCase<PostEntity, RepostParams> {
  RepostUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, PostEntity>> call(RepostParams params) =>
      _repository.repost(params.postId, content: params.content);
}

/// Local-only bookmark toggle — see `FeedRepository.toggleSave` doc.
class ToggleSaveUseCase implements UseCase<bool, PostIdParams> {
  ToggleSaveUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, bool>> call(PostIdParams params) => _repository.toggleSave(params.postId);
}
