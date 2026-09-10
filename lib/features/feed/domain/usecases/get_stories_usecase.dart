import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/story_entity.dart';
import '../repositories/feed_repository.dart';

class GetStoriesUseCase implements UseCase<List<StoryEntity>, NoParams> {
  GetStoriesUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, List<StoryEntity>>> call(NoParams params) {
    return _repository.getStories();
  }
}
