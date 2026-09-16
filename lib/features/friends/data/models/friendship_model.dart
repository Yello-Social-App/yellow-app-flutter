import '../../domain/entities/friendship_entity.dart';

/// Parses the API's `FriendEntry`:
///
/// ```json
/// { "user": { "id": …, "username": …, "fullName": …, "avatarUrl": … },
///   "friendStatus": "FRIENDS", "since": "2026-09-14T03:02:48Z" }
/// ```
///
/// The previous version of this file read `id`, `status`, `createdAt` and
/// `respondedAt` — none of which this payload contains — so `json['id'] as
/// String` threw on the first `/friends` response. Every field is now read
/// defensively: a missing one degrades the row instead of taking down the
/// whole list.
class FriendshipModel extends FriendshipEntity {
  const FriendshipModel({
    required super.userId,
    required super.username,
    super.fullName,
    super.avatarUrl,
    required super.status,
    super.since,
  });

  factory FriendshipModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final since = json['since'] as String?;
    return FriendshipModel(
      userId: user['id'] as String? ?? '',
      username: user['username'] as String? ?? 'unknown',
      fullName: user['fullName'] as String?,
      avatarUrl: user['avatarUrl'] as String?,
      status: FriendshipStatus.fromWire(json['friendStatus'] as String?),
      since: since == null ? null : DateTime.tryParse(since),
    );
  }
}
