import 'package:equatable/equatable.dart';

import '../../../feed/domain/entities/reactor_entity.dart' show FriendRelationStatus;

/// The shortest query the backend accepts (`q` has `minLength: 2` on
/// `GET /users/search`); a shorter one is a `400 VALIDATION_FAILED`, so callers
/// gate on this rather than firing a doomed request on the first keystroke.
const int kUserSearchMinChars = 2;

/// Longest query the backend accepts (`q` has `maxLength: 100`).
const int kUserSearchMaxChars = 100;

/// One row of `GET /users/search` — the backend's `UserSearchResult`.
///
/// Deliberately thinner than `PublicUserEntity`: search returns no bio,
/// cover, or counts, so this models exactly what the endpoint sends rather
/// than a half-empty profile. [friendStatus] is the reason the endpoint
/// returns an object per row at all — it is enough to render an
/// Add-friend / Requested / Friends control without a further call per user.
///
/// Reuses `FriendRelationStatus` from the feed feature's `ReactorEntity`
/// rather than declaring a third copy of the same `FriendStatus` wire enum
/// (see that enum's doc for how it differs from `FriendshipStatus`).
class UserSearchResultEntity extends Equatable {
  const UserSearchResultEntity({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.friendStatus,
  });

  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;

  /// The viewer's relationship to this user — null when the backend sent a
  /// value this client version doesn't know (the route is auth-only, so an
  /// anonymous-viewer null is not reachable here).
  final FriendRelationStatus? friendStatus;

  /// Name to show first: the display name when the account has one, else the
  /// handle.
  String get displayName => (fullName == null || fullName!.isEmpty) ? username : fullName!;

  /// Whether a friend request can still be sent to this row.
  bool get canSendRequest => friendStatus == FriendRelationStatus.none;

  UserSearchResultEntity copyWith({FriendRelationStatus? friendStatus}) {
    return UserSearchResultEntity(
      id: id,
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl,
      friendStatus: friendStatus ?? this.friendStatus,
    );
  }

  @override
  List<Object?> get props => [id, username, fullName, avatarUrl, friendStatus];
}
