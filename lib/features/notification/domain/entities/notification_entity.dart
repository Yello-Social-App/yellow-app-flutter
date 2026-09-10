import 'package:equatable/equatable.dart';

/// Shaped after the backend's `NotificationResponse`. `type` is an opaque
/// string on the wire (no enum documented in the spec) — presentation maps
/// known values to an icon/verb and falls back gracefully for anything new
/// the backend starts sending later.
class NotificationEntity extends Equatable {
  const NotificationEntity({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorUsername,
    this.actorAvatarUrl,
    this.targetId,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String actorId;
  final String actorUsername;
  final String? actorAvatarUrl;
  final String? targetId;
  final bool read;
  final DateTime createdAt;

  /// Wire `type` values meaning "this is an incoming friend request" — one
  /// source of truth shared by the accept/decline row in
  /// `notifications_page.dart` and `NotificationsCubit`'s already-accepted
  /// precheck, so the two can't quietly drift apart.
  static const _friendRequestTypes = {'FOLLOW', 'FRIEND_REQUEST'};
  bool get isFriendRequestType => _friendRequestTypes.contains(type.toUpperCase());

  NotificationEntity copyWith({bool? read}) => NotificationEntity(
        id: id,
        type: type,
        actorId: actorId,
        actorUsername: actorUsername,
        actorAvatarUrl: actorAvatarUrl,
        targetId: targetId,
        read: read ?? this.read,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [id, read];
}
