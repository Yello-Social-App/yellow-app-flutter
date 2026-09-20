import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/user_search_result_entity.dart';

/// One offset-paged page of `GET /users/search`.
class UserSearchPage {
  const UserSearchPage({required this.users, required this.hasMore});
  final List<UserSearchResultEntity> users;
  final bool hasMore;
}

/// Domain-facing contract for people search.
///
/// Only users are searchable server-side today — there is no post, community
/// or project search endpoint — so this contract stays deliberately narrow
/// instead of pretending to be a universal search surface.
abstract interface class SearchRepository {
  Future<Either<Failure, UserSearchPage>> searchUsers(String query, {int page = 0});
}
