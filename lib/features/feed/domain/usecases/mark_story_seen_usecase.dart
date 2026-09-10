import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/feed_repository.dart';

/// Device-local — see `FeedRepository.markStorySeen` doc.
class MarkStorySeenUseCase implements UseCase<void, String> {
  MarkStorySeenUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, void>> call(String userId) => _repository.markStorySeen(userId);
}
