import 'package:equatable/equatable.dart';

import '../../../../core/utils/presigned_url.dart';
import 'message_entity.dart';
import 'participant_entity.dart';

enum ConversationType {
  direct,
  group;

  static ConversationType fromWire(String? value) =>
      value == 'GROUP' ? ConversationType.group : ConversationType.direct;

  String get wire => this == ConversationType.group ? 'GROUP' : 'DIRECT';
}

/// What an inbox row says about a message whose text is empty. The summary
/// `yello-chat` embeds in a conversation (`lastMessage`) carries only
/// `{id, senderId, body, createdAt}`, so a server-supplied row can only tell
/// text from "no text" — [attachment] is the honest default for the latter.
/// When this client applies a full [MessageEntity] itself
/// (`MessagesCubit.applyIncomingMessage`) it knows better and says so.
enum LastMessageKind { text, attachment, voice, invite, deleted }

/// The trimmed message `yello-chat` embeds in a conversation summary — just
/// enough to render an inbox row without fetching history.
class LastMessageEntity extends Equatable {
  const LastMessageEntity({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.kind = LastMessageKind.text,
  });

  /// Built from the full message this client just sent or received, so the
  /// preview can name what an empty body actually is.
  factory LastMessageEntity.fromMessage(MessageEntity message) => LastMessageEntity(
        id: message.id,
        senderId: message.senderId,
        body: message.body,
        createdAt: message.createdAt,
        kind: message.isDeleted
            ? LastMessageKind.deleted
            : message.isInviteCard
                ? LastMessageKind.invite
                : message.hasText
                    ? LastMessageKind.text
                    : message.attachments.any((a) => a.isVoice)
                        ? LastMessageKind.voice
                        : LastMessageKind.attachment,
      );

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final LastMessageKind kind;

  /// The inbox row's one-line preview.
  String get preview {
    if (kind == LastMessageKind.deleted) return 'Message deleted';
    if (kind == LastMessageKind.invite) return 'Sent a group invite';
    if (body.isNotEmpty) return body;
    // Same words the push notification uses for one, so the row and the
    // alert that announced it do not describe the same message differently.
    if (kind == LastMessageKind.voice) return 'Sent a voice message';
    return 'Sent an attachment';
  }

  LastMessageEntity copyWith({LastMessageKind? kind}) => LastMessageEntity(
        id: id,
        senderId: senderId,
        body: kind == LastMessageKind.deleted ? '' : body,
        createdAt: createdAt,
        kind: kind ?? this.kind,
      );

  @override
  List<Object?> get props => [id, senderId, body, createdAt, kind];
}

/// What changed in a group, as the `conversation.updated` frame reports it —
/// enough to render "Alice added Bob and Chea" as a line in the transcript.
/// These are live only: the server does not store them in message history.
enum ConversationChangeKind {
  renamed,
  photoChanged,
  membersAdded,
  memberRemoved,
  memberLeft,
  roleChanged,
  unknown;

  static ConversationChangeKind fromWire(String? value) => switch (value) {
        'RENAMED' => ConversationChangeKind.renamed,
        'PHOTO_CHANGED' => ConversationChangeKind.photoChanged,
        'MEMBERS_ADDED' => ConversationChangeKind.membersAdded,
        'MEMBER_REMOVED' => ConversationChangeKind.memberRemoved,
        'MEMBER_LEFT' => ConversationChangeKind.memberLeft,
        'ROLE_CHANGED' => ConversationChangeKind.roleChanged,
        _ => ConversationChangeKind.unknown,
      };
}

class ConversationChange extends Equatable {
  const ConversationChange({required this.kind, required this.actorId, this.userIds = const []});

  final ConversationChangeKind kind;
  final String actorId;

  /// Who was added / removed / left / re-roled. Empty for a rename or a
  /// photo change. For a role change, read the new role off `participants`.
  final List<String> userIds;

  @override
  List<Object?> get props => [kind, actorId, userIds];
}

/// A conversation as `yello-chat` models it (`ConversationSummary` /
/// `ConversationDetail`).
///
/// The service returns no display identity — see [ParticipantEntity]'s doc.
/// The name and avatar this UI shows are therefore *derived*: for a DIRECT
/// conversation from the other participant's hydrated profile, for a GROUP
/// from [title] and [photoUrl]. [viewerId] is the signed-in user's id, needed
/// to work out which participant is "the other one" (and which is "me", for
/// roles); it is set by the repository when it maps the response, not by
/// the server.
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
    this.photoUrl,
    this.photoUrlExpiresAt,
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

  /// Signed-in user's id, used to resolve [peer] and [me]. Null if unknown,
  /// in which case DIRECT conversations fall back to the first participant.
  final String? viewerId;

  /// Presence is delivered by the `presence` WebSocket frame. Until that
  /// socket is wired this is always false — do not read it as "offline".
  final bool isOnline;

  /// Group photo — a presigned link that expires at [photoUrlExpiresAt] and
  /// is re-signed on every read, so it is not part of [props] (see
  /// `AttachmentEntity` for the reasoning). Always null for a DM.
  final String? photoUrl;
  final DateTime? photoUrlExpiresAt;

  DateTime get lastMessageAt => lastMessageAtOrNull ?? createdAt;

  bool get isGroup => type == ConversationType.group;

  /// Whether a group photo is set. This — not the URL itself — is what
  /// [props] compares, since the URL is re-signed on every read.
  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  /// The other side of a DIRECT conversation. Null for groups, and for a
  /// one-participant conversation (possible before the peer has joined).
  ParticipantEntity? get peer {
    if (type != ConversationType.direct || participants.isEmpty) return null;
    for (final p in participants) {
      if (p.userId != viewerId) return p;
    }
    return participants.first;
  }

  /// The viewer's own participant row — null when the viewer is unknown or
  /// no longer a member.
  ParticipantEntity? get me {
    if (viewerId == null) return null;
    for (final p in participants) {
      if (p.userId == viewerId) return p;
    }
    return null;
  }

  /// The viewer's role, defaulting to a plain member so an unresolved
  /// identity never *grants* anything — the server enforces the real rule.
  ParticipantRole get myRole => me?.role ?? ParticipantRole.member;

  /// What the inbox row and chat header show.
  String get name {
    if (type == ConversationType.group) {
      final t = title?.trim();
      return (t != null && t.isNotEmpty) ? t : 'Group';
    }
    return peer?.displayName ?? 'Unknown';
  }

  String get firstName => name.split(' ').first;

  String? get avatarUrl => type == ConversationType.direct ? peer?.avatarUrl : photoUrl;

  /// Pass beside [avatarUrl] to `AppAvatar(cacheKey:)`. A group photo is a
  /// presigned link re-signed on every inbox refresh; keyed by URL it would
  /// be re-downloaded every tick. Null for a DM — a yello-api avatar URL is
  /// stable and keys itself.
  String? get avatarCacheKey => isGroup && hasPhoto ? presignedObjectKey(photoUrl!) : null;

  /// Stable placeholder-avatar seed for participants with no photo. Keyed on
  /// the peer's id (not the conversation's) so the same person looks the same
  /// everywhere in the app.
  int get avatarSeed => (peer?.userId ?? id).hashCode.abs();

  String get lastMessagePreview => lastMessage?.preview ?? '';

  /// Sentinel so `title: null` / `photoUrl: null` can mean "cleared" (a
  /// removed group photo) rather than "leave it alone".
  static const Object _unset = Object();

  ConversationEntity copyWith({
    Object? title = _unset,
    List<ParticipantEntity>? participants,
    LastMessageEntity? lastMessage,
    DateTime? lastMessageAtOrNull,
    int? unreadCount,
    String? viewerId,
    bool? isOnline,
    Object? photoUrl = _unset,
    Object? photoUrlExpiresAt = _unset,
  }) {
    return ConversationEntity(
      id: id,
      type: type,
      title: identical(title, _unset) ? this.title : title as String?,
      createdBy: createdBy,
      createdAt: createdAt,
      lastMessageAtOrNull: lastMessageAtOrNull ?? this.lastMessageAtOrNull,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      viewerId: viewerId ?? this.viewerId,
      isOnline: isOnline ?? this.isOnline,
      photoUrl: identical(photoUrl, _unset) ? this.photoUrl : photoUrl as String?,
      photoUrlExpiresAt: identical(photoUrlExpiresAt, _unset) ? this.photoUrlExpiresAt : photoUrlExpiresAt as DateTime?,
    );
  }

  /// Folds a freshly fetched detail (title, photo, members) into this row
  /// without losing what only the inbox summary knows (last message, unread
  /// count). The detail endpoint and every group route answer without those
  /// two fields, so replacing the row wholesale would blank the preview.
  ConversationEntity mergeDetail(ConversationEntity detail) => copyWith(
        title: detail.title,
        participants: detail.participants,
        photoUrl: detail.photoUrl,
        photoUrlExpiresAt: detail.photoUrlExpiresAt,
        viewerId: detail.viewerId ?? viewerId,
      );

  @override
  List<Object?> get props =>
      [id, title, lastMessage, lastMessageAtOrNull, unreadCount, participants, isOnline, hasPhoto];
}
