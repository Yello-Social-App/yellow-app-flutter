import 'package:equatable/equatable.dart';

/// The viewer's relationship to another user — the backend's `friendStatus`
/// on `FriendEntry`.
///
/// This replaced an earlier `pending / accepted / declined` enum that no
/// endpoint ever returned: the live API describes the edge from the
/// *viewer's* point of view instead of as a row with a lifecycle. A block in
/// either direction reads as [none] — the API never reveals a block.
enum FriendshipStatus {
  self,
  friends,
  requestSent,
  requestReceived,
  none;

  static FriendshipStatus fromWire(String? value) => switch (value) {
        'SELF' => FriendshipStatus.self,
        'FRIENDS' => FriendshipStatus.friends,
        'REQUEST_SENT' => FriendshipStatus.requestSent,
        'REQUEST_RECEIVED' => FriendshipStatus.requestReceived,
        _ => FriendshipStatus.none,
      };
}

/// One relationship edge — shaped after the API's `FriendEntry`
/// (`{ user, friendStatus, since? }`). The same shape serves `GET /friends`,
/// `GET /friends/requests`, `GET /friends/blocked` and every friendship
/// mutation, which all return a `FriendEntry`.
class FriendshipEntity extends Equatable {
  const FriendshipEntity({
    required this.userId,
    required this.username,
    this.fullName,
    this.avatarUrl,
    required this.status,
    this.since,
  });

  final String userId;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final FriendshipStatus status;

  /// When the friendship was accepted, or the request sent. Present on list
  /// rows, absent on some mutation responses.
  final DateTime? since;

  /// Deliberately the same value as [userId].
  ///
  /// There is no friendship-row id in this API: every friendship route is
  /// addressed by the *other user's* id (`POST /friends/requests/{user}/
  /// accept`). This getter exists because the Circle page and
  /// `PublicProfileCubit` key rows and busy-state on `.id`, and both are
  /// therefore already passing exactly the right value.
  String get id => userId;

  String get displayName {
    final full = fullName?.trim();
    return (full != null && full.isNotEmpty) ? full : username;
  }

  @override
  List<Object?> get props => [userId, status, since];
}
