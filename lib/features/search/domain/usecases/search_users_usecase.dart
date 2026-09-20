import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_search_result_entity.dart' show kUserSearchMaxChars, kUserSearchMinChars;
import '../repositories/search_repository.dart';

class SearchUsersParams extends Equatable {
  const SearchUsersParams({required this.query, this.page = 0});
  final String query;
  final int page;

  @override
  List<Object?> get props => [query, page];
}

/// Searches active users by name or username — `GET /users/search`.
///
/// Trims and length-gates before hitting the network: the backend rejects a
/// query under [kUserSearchMinChars] with `400 VALIDATION_FAILED`, which as a
/// user-facing error reads like a broken screen rather than "keep typing".
class SearchUsersUseCase implements UseCase<UserSearchPage, SearchUsersParams> {
  SearchUsersUseCase(this._repository);

  final SearchRepository _repository;

  @override
  Future<Either<Failure, UserSearchPage>> call(SearchUsersParams params) {
    final query = params.query.trim();
    if (query.length < kUserSearchMinChars) {
      return Future.value(const Left(ValidationFailure('Type at least two characters to search.')));
    }
    return _repository.searchUsers(
      query.length > kUserSearchMaxChars ? query.substring(0, kUserSearchMaxChars) : query,
      page: params.page,
    );
  }
}
