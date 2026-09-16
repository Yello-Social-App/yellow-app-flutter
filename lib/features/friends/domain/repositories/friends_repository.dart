import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/friendship_entity.dart';

class FriendsPage {
  const FriendsPage({required this.friendships, required this.hasMore});
  final List<FriendshipEntity> friendships;
  final bool hasMore;
}

/// Domain-facing contract for the Circle tab, backed by
/// `api.yello.cachewraith.com`'s `/friends` resource.
///
/// Every method that names a user takes the **other user's id**. The API has
/// no friendship-row id — see [FriendshipEntity.id].
abstract interface class FriendsRepository {
  Future<Either<Failure, FriendsPage>> getFriends({int page = 0});

  /// Pending requests you received. Pass `sent: true` for the outgoing list.
  Future<Either<Failure, FriendsPage>> getRequests({int page = 0, bool sent = false});

  /// Users you have blocked.
  Future<Either<Failure, FriendsPage>> getBlocked({int page = 0});

  Future<Either<Failure, void>> sendRequest(String userId);

  /// Withdraws a request you sent.
  Future<Either<Failure, void>> cancelRequest(String userId);

  Future<Either<Failure, FriendshipEntity>> acceptRequest(String userId);
  Future<Either<Failure, void>> declineRequest(String userId);
  Future<Either<Failure, void>> unfriend(String userId);

  Future<Either<Failure, FriendshipEntity>> blockUser(String userId);
  Future<Either<Failure, FriendshipEntity>> unblockUser(String userId);
}
