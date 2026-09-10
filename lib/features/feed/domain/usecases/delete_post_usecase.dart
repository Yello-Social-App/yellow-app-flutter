import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/feed_repository.dart';

/// Deletes a post you own — `DELETE /api/v1/posts/{id}`.
class DeletePostUseCase implements UseCase<void, String> {
  DeletePostUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, void>> call(String postId) => _repository.deletePost(postId);
}
