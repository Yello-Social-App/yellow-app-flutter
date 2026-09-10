import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/feed_repository.dart';

class GetFeedParams extends Equatable {
  const GetFeedParams({this.cursor});
  final String? cursor;

  @override
  List<Object?> get props => [cursor];
}

class GetFeedUseCase implements UseCase<FeedPage, GetFeedParams> {
  GetFeedUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, FeedPage>> call(GetFeedParams params) {
    return _repository.getFeed(cursor: params.cursor);
  }
}
