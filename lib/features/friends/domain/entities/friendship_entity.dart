import 'package:equatable/equatable.dart';

/// Mirrors the backend's `FriendshipResponse.status` — an opaque string on
/// the wire; normalized to an enum so presentation code never string-matches.
enum FriendshipStatus {
  pending,
  accepted,
  declined,
  unknown;

  static FriendshipStatus fromWire(String? value) => switch (value) {
        'PENDING' => FriendshipStatus.pending,
        'ACCEPTED' => FriendshipStatus.accepted,
        'DECLINED' => FriendshipStatus.declined,
        _ => FriendshipStatus.unknown,
      };
}

/// One relationship edge — shaped after `FriendshipResponse`. The same
/// shape serves both `GET /friends` (accepted) and `GET /friends/requests`
/// (pending, viewed from the recipient's side).
class FriendshipEntity extends Equatable {
  const FriendshipEntity({
    required this.id,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  final String id;
  final String userId;
  final String username;
  final String? avatarUrl;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  @override
  List<Object?> get props => [id, status, respondedAt];
}
