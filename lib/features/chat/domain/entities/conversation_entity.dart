import 'package:equatable/equatable.dart';

import 'participant_entity.dart';

enum ConversationType {
  direct,
  group;

  static ConversationType fromWire(String? value) =>
      value == 'GROUP' ? ConversationType.group : ConversationType.direct;

  String get wire => this == ConversationType.group ? 'GROUP' : 'DIRECT';
}

/// The trimmed message `yello-chat` embeds in a conversation summary — just
/// enough to render an inbox row without fetching history.
class LastMessageEntity extends Equatable {
  const LastMessageEntity({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, senderId, body, createdAt];
}

/// A conversation as `yello-chat` models it (`ConversationSummary` /
/// `ConversationDetail`).
///
/// The service returns no display identity — see [ParticipantEntity]'s doc.
/// The name and avatar this UI shows are therefore *derived*: for a DIRECT
/// conversation from the other participant's hydrated profile, for a GROUP
/// from [title]. [viewerId] is the signed-in user's id, needed to work out
/// which participant is "the other one"; it is set by the repository when it
/// maps the response, not by the server.
class ConversationEntity extends Equatable {
  const ConversationEntity({
    required this.id,
    required this.type,
    this.title,
    required this.createdBy,
    required this.createdAt,
    this.lastMessageAtOrNull,
    this.participants = const [],
    this.lastMessage,
    this.unreadCount = 0,
    this.viewerId,
    this.isOnline = false,
  });

  final String id;
  final ConversationType type;

  /// Group title. Always null for DIRECT conversations.
  final String? title;
  final String createdBy;
  final DateTime createdAt;

  /// Null until the first message is sent — prefer [lastMessageAt], which
  /// falls back to [createdAt] so sorting and rendering never special-case
  /// an empty conversation.
  final DateTime? lastMessageAtOrNull;

  final List<ParticipantEntity> participants;
  final LastMessageEntity? lastMessage;
  final int unreadCount;

  /// Signed-in user's id, used to resolve [peer]. Null if unknown, in which
  /// case DIRECT conversations fall back to the first participant.
  final String? viewerId;

  /// Presence is delivered by the `presence` WebSocket frame. Until that
  /// socket is wired this is always false — do not read it as "offline".
  final bool isOnline;

  DateTime get lastMessageAt => lastMessageAtOrNull ?? createdAt;

  /// The other side of a DIRECT conversation. Null for groups, and for a
  /// one-participant conversation (possible before the peer has joined).
  ParticipantEntity? get peer {
    if (type != ConversationType.direct || participants.isEmpty) return null;
    for (final p in participants) {
      if (p.userId != viewerId) return p;
    }
    return participants.first;
  }

  /// What the inbox row and chat header show.
  String get name {
    if (type == ConversationType.group) {
      final t = title?.trim();
      return (t != null && t.isNotEmpty) ? t : 'Group';
    }
    return peer?.displayName ?? 'Unknown';
  }

  String get firstName => name.split(' ').first;

  String? get avatarUrl => type == ConversationType.direct ? peer?.avatarUrl : null;

  /// Stable placeholder-avatar seed for participants with no photo. Keyed on
  /// the peer's id (not the conversation's) so the same person looks the same
  /// everywhere in the app.
  int get avatarSeed => (peer?.userId ?? id).hashCode.abs();

  String get lastMessagePreview => lastMessage?.body ?? '';

  ConversationEntity copyWith({
    List<ParticipantEntity>? participants,
    LastMessageEntity? lastMessage,
    DateTime? lastMessageAtOrNull,
    int? unreadCount,
    String? viewerId,
    bool? isOnline,
  }) {
    return ConversationEntity(
      id: id,
      type: type,
      title: title,
      createdBy: createdBy,
      createdAt: createdAt,
      lastMessageAtOrNull: lastMessageAtOrNull ?? this.lastMessageAtOrNull,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      viewerId: viewerId ?? this.viewerId,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  List<Object?> get props => [id, lastMessage, lastMessageAtOrNull, unreadCount, participants, isOnline];
}
