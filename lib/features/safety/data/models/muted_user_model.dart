import '../../domain/entities/muted_user_entity.dart';

/// Parses one row of `GET /v1/users/me/muted`:
///
/// ```json
/// { "user": { "id": "3a9e…", "username": "rithy",
///             "fullName": "Rithy Chea", "avatarUrl": null },
///   "since": "2026-09-10T08:00:00Z" }
/// ```
///
/// Same nested-`user` shape as `FriendshipModel`, and read just as
/// defensively: a row missing a field degrades rather than throwing and
/// taking the whole list with it.
class MutedUserModel extends MutedUserEntity {
  const MutedUserModel({
    required super.userId,
    required super.username,
    required super.since,
    super.fullName,
    super.avatarUrl,
  });

  factory MutedUserModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return MutedUserModel(
      userId: user['id'] as String? ?? '',
      username: user['username'] as String? ?? 'unknown',
      fullName: user['fullName'] as String?,
      avatarUrl: user['avatarUrl'] as String?,
      since: DateTime.tryParse(json['since'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
