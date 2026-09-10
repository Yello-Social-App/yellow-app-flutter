import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/feed_repository.dart';

class GetSavedPostIdsUseCase implements UseCase<List<String>, NoParams> {
  GetSavedPostIdsUseCase(this._repository);
  final FeedRepository _repository;

  @override
  Future<Either<Failure, List<String>>> call(NoParams params) => _repository.getSavedPostIds();
}
