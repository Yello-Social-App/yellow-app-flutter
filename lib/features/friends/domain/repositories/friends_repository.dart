import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/friendship_entity.dart';

class FriendsPage {
  const FriendsPage({required this.friendships, required this.hasMore});
  final List<FriendshipEntity> friendships;
  final bool hasMore;
}

/// Domain-facing contract for the Circle tab, backed by
/// `dev.yello-api.cachewraith.com`'s `/friends` resource.
abstract interface class FriendsRepository {
  Future<Either<Failure, FriendsPage>> getFriends({int page = 0});
  Future<Either<Failure, FriendsPage>> getRequests({int page = 0});
  Future<Either<Failure, void>> sendRequest(String userId);
  Future<Either<Failure, FriendshipEntity>> acceptRequest(String requestId);
  Future<Either<Failure, void>> declineRequest(String requestId);
  Future<Either<Failure, void>> unfriend(String userId);
}
