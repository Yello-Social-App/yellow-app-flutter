import 'package:equatable/equatable.dart';

/// A participant's role in a conversation — `OWNER` on the wire for the
/// creator of a GROUP, `MEMBER` for everyone else (and for both sides of a
/// DIRECT conversation).
enum ParticipantRole {
  owner,
  member;

  static ParticipantRole fromWire(String? value) =>
      value == 'OWNER' ? ParticipantRole.owner : ParticipantRole.member;
}

/// One member of a conversation, as `yello-chat` returns it.
///
/// The chat service is identity-light: it knows `userId` and nothing else —
/// no username, no avatar. [username], [fullName] and [avatarUrl] are *not*
/// part of that payload; they are filled in afterwards by `UserDirectory`,
/// which resolves them from yello-api's `GET /v1/users/{id}`. They stay null
/// when that lookup has not run or failed, so every consumer must tolerate
/// an unhydrated participant.
class ParticipantEntity extends Equatable {
  const ParticipantEntity({
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.lastReadMessageId,
    this.lastReadAt,
    this.username,
    this.fullName,
    this.avatarUrl,
  });

  final String userId;
  final ParticipantRole role;
  final DateTime joinedAt;

  /// Last message this participant has read. Never moves backwards
  /// server-side, so it is safe to use for "seen" ticks.
  final String? lastReadMessageId;
  final DateTime? lastReadAt;

  // --- hydrated from yello-api, not from yello-chat ---
  final String? username;
  final String? fullName;
  final String? avatarUrl;

  /// Best available human label, degrading gracefully while unhydrated.
  String get displayName {
    final full = fullName?.trim();
    if (full != null && full.isNotEmpty) return full;
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return handle;
    return 'Unknown';
  }

  ParticipantEntity withProfile({String? username, String? fullName, String? avatarUrl}) {
    return ParticipantEntity(
      userId: userId,
      role: role,
      joinedAt: joinedAt,
      lastReadMessageId: lastReadMessageId,
      lastReadAt: lastReadAt,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  List<Object?> get props => [userId, role, lastReadMessageId, username, fullName, avatarUrl];
}
