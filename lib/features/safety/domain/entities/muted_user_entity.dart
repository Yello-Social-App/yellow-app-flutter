import 'package:equatable/equatable.dart';

/// One row of `GET /v1/users/me/muted`. The wire shape nests the person
/// under `user` alongside a sibling `since`; this flattens it, because
/// every reader wants both halves together and nothing else hangs off
/// `user`.
///
/// Muting is one-way and invisible: it takes someone's posts out of *your*
/// feed and is never reflected in their `friendStatus` or anywhere else
/// they can read. It does not stop them messaging you or seeing your posts
/// — that is what blocking is for.
class MutedUserEntity extends Equatable {
  const MutedUserEntity({
    required this.userId,
    required this.username,
    required this.since,
    this.fullName,
    this.avatarUrl,
  });

  final String userId;
  final String username;
  final String? fullName;
  final String? avatarUrl;

  /// When you muted them. The list comes back most-recent-first.
  final DateTime since;

  /// Full name when there is one, otherwise the handle — the same fallback
  /// the rest of the app uses for a person's display name.
  String get displayName => (fullName ?? '').isNotEmpty ? fullName! : username;

  @override
  List<Object?> get props => [userId, username, fullName, avatarUrl, since];
}
