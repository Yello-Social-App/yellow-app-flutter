import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/feed_repository.dart';

/// A post's canonical public URL — `GET /api/v1/posts/{id}/share-link`.
class GetShareLinkUseCase implements UseCase<String, String> {
  GetShareLinkUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, String>> call(String postId) => _repository.getShareLink(postId);
}
