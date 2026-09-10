import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/feed_repository.dart';

/// Deletes a comment you own, or one on a post you own —
/// `DELETE /api/v1/comments/{id}`.
class DeleteCommentUseCase implements UseCase<void, String> {
  DeleteCommentUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, void>> call(String commentId) => _repository.deleteComment(commentId);
}
