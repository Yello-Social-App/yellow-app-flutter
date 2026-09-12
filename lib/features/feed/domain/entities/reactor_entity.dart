import 'package:equatable/equatable.dart';

import 'post_entity.dart' show ReactionType;

/// Mirrors `ReactorResponse.friendStatus` — the viewer's relationship to a
/// reactor. The whole reason `GET /reactions/{targetType}/{targetId}`
/// returns a full user object per row instead of just an id: this is
/// enough to render an Add-friend / Friends / Cancel-request button on
/// every row without a further call per user. `null` means no token was
/// sent (anonymous viewer); [self] means that row is the viewer.
///
/// Distinct from `friends/domain/entities/friendship_entity.dart`'s
/// `FriendshipStatus`, which is a single friendship *record's*
/// pending/accepted/declined state — this is "my relationship to this
/// specific other user" from the viewer's side, hence the different name.
enum FriendRelationStatus {
  none,
  requestSent,
  requestReceived,
  friends,
  self;

  static FriendRelationStatus? fromWire(String? value) => switch (value) {
    'NONE' => FriendRelationStatus.none,
    'REQUEST_SENT' => FriendRelationStatus.requestSent,
    'REQUEST_RECEIVED' => FriendRelationStatus.requestReceived,
    'FRIENDS' => FriendRelationStatus.friends,
    'SELF' => FriendRelationStatus.self,
    _ => null,
  };
}

/// One row of `GET /reactions/{targetType}/{targetId}` (`reactors`) — distinct
/// from [ReactionBreakdown], which only carries per-type totals. Mirrors the
/// backend's `ReactorResponse`.
class ReactorEntity extends Equatable {
  const ReactorEntity({
    required this.userId,
    required this.username,
    this.fullName,
    this.avatarUrl,
    required this.reactionType,
    required this.reactedAt,
    this.friendStatus,
  });

  final String userId;
  final String username;
  final String? fullName;
  final String? avatarUrl;

  /// Null if the backend returns a reaction-type string this client doesn't
  /// know — see `ReactionType.fromWire`.
  final ReactionType? reactionType;
  final DateTime reactedAt;

  /// The viewer's relationship to this user — null when the viewer is
  /// anonymous (no token sent). See [FriendRelationStatus].
  final FriendRelationStatus? friendStatus;

  @override
  List<Object?> get props => [userId, reactionType, reactedAt, friendStatus];
}
