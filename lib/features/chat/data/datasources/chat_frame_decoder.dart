import 'dart:convert';

import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/group_invite_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/sticker_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/sticker_repository.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/sticker_model.dart';

/// One person's presence, as the `presence` frame reports it. A record
/// rather than an entity: nothing past [PresenceTracker] needs a user's
/// presence *as a value* — the tracker folds these into the set of online
/// ids, and that set is what crosses the repository boundary.
typedef PresenceUpdate = ({String userId, bool isOnline});

/// Turns one `yello-chat` socket frame — `{ "event": string, "data": object }`
/// — into the [ChatEvent] the cubit understands.
///
/// This is the whole server → client vocabulary from the service's frame
/// reference, kept apart from the transport (`ChatSocket`) so it stays a
/// pure, unit-testable function of one frame.
///
/// An unrecognised or malformed frame decodes to `null`, which the caller
/// drops. That is the documented contract ("unknown frames can be ignored
/// safely"), and it means a new event type the server starts sending never
/// takes a live conversation down.
abstract final class ChatFrameDecoder {
  /// [viewerId] is threaded into the message mappers for `fromMe` /
  /// `reactedByMe` / `forMe`, exactly as on the HTTP path.
  static ChatEvent? decode(String raw, {String? viewerId}) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map<String, dynamic>) return null;
    return decodeFrame(json, viewerId: viewerId);
  }

  static ChatEvent? decodeFrame(Map<String, dynamic> frame, {String? viewerId}) {
    final event = frame['event'];
    final data = frame['data'];
    if (event is! String || data is! Map<String, dynamic>) return null;

    try {
      return switch (event) {
        'message.new' || 'message.sent' => _message(data, viewerId: viewerId, wrap: MessageArrived.new),
        'message.updated' => _message(data, viewerId: viewerId, wrap: MessageUpdated.new),
        'message.deleted' => MessageDeleted(
            conversationId: data['conversationId'] as String,
            messageId: data['messageId'] as String,
            deletedAt: _date(data['deletedAt']) ?? DateTime.now(),
          ),
        'message.reactions' => MessageReactionsChanged(
            conversationId: data['conversationId'] as String,
            messageId: data['messageId'] as String,
            reactions: ReactionMapper.fromMessageReactions(data, viewerId: viewerId),
          ),
        'message.read' => MessagesRead(
            userId: data['userId'] as String,
            messageId: data['messageId'] as String,
          ),
        // The relayed typing frame's exact field names are not in the
        // published reference; `userId` plus an `isTyping`/`typing` flag
        // (absent meaning "started") covers the likely shapes. A frame
        // the server sends that this does not read shows up in the device
        // log through the error path in `ChatRepositoryImpl.watchEvents`.
        'typing' => TypingChanged(
            userId: data['userId'] as String? ?? data['senderId'] as String? ?? '',
            isTyping: data['isTyping'] as bool? ?? data['typing'] as bool? ?? true,
          ),
        'conversation.updated' => _conversationUpdated(data, viewerId: viewerId),
        'conversation.removed' => ConversationRemoved(
            conversationId: data['conversationId'] as String,
            reason: data['reason'] as String? ?? 'REMOVED',
          ),
        'group.invite.updated' => GroupInviteUpdated(
            inviteId: data['inviteId'] as String,
            conversationId: data['conversationId'] as String? ?? '',
            status: GroupInviteStatus.fromWire(data['status'] as String?),
          ),
        // `presence` is deliberately absent: it names people, not a
        // conversation, so it belongs to no single screen.
        // [PresenceTracker] reads it with [presence] below and keeps the
        // app's one set of online ids.
        _ => null,
      };
    } on TypeError {
      // A required field missing or of the wrong type — treat the frame as
      // unknown rather than crash the listener.
      return null;
    }
  }

  /// `message.new` / `message.sent` / `message.updated` all carry
  /// `{ message }`; `message.sent` also echoes `ref`, which is irrelevant
  /// here — the HTTP response already confirmed the optimistic bubble.
  static ChatEvent? _message(
    Map<String, dynamic> data, {
    required String? viewerId,
    required ChatEvent Function(MessageEntity) wrap,
  }) {
    final raw = data['message'];
    if (raw is! Map<String, dynamic>) return null;
    return wrap(MessageMapper.fromJson(raw, viewerId: viewerId));
  }

  static ChatEvent? _conversationUpdated(Map<String, dynamic> data, {required String? viewerId}) {
    final raw = data['conversation'];
    if (raw is! Map<String, dynamic>) return null;
    // The frame puts `participants` beside `conversation`, not inside it;
    // fold them in so the entity is whole.
    final merged = {...raw, if (data['participants'] is List) 'participants': data['participants']};
    final change = data['change'];
    return ConversationUpdated(
      conversation: ConversationMapper.fromJson(merged, viewerId: viewerId),
      change: change is Map<String, dynamic>
          ? ConversationMapper.changeFromJson(change)
          : const ConversationChange(kind: ConversationChangeKind.unknown, actorId: ''),
    );
  }

  /// `sticker.added` / `sticker.updated` / `sticker.removed`.
  ///
  /// Deliberately outside [decodeFrame], for the same reason `presence` is:
  /// these name the *owner's library*, not a conversation, so they belong to
  /// no single chat screen and are not [ChatEvent]s. They also reach **every**
  /// one of the caller's sockets, the device that made the request included —
  /// an HTTP request cannot say which socket is the caller's — so a listener
  /// must be idempotent per [StickerEntity.id] rather than assume a frame is
  /// news.
  ///
  /// `null` for a frame that is not a sticker event, or whose payload is not
  /// the documented shape.
  static StickerLibraryEvent? stickerEvent(Map<String, dynamic> frame) {
    final event = frame['event'];
    if (event is! String || !event.startsWith('sticker.')) return null;
    final data = frame['data'];
    if (data is! Map<String, dynamic>) return null;

    try {
      return switch (event) {
        'sticker.added' => _stickerEvent(data, StickerAdded.new),
        'sticker.updated' => _stickerEvent(data, StickerUpdated.new),
        'sticker.removed' => StickerRemoved(data['stickerId'] as String),
        _ => null,
      };
    } on TypeError {
      return null;
    }
  }

  /// `sticker.added` and `sticker.updated` both carry `{ sticker }`.
  static StickerLibraryEvent? _stickerEvent(
    Map<String, dynamic> data,
    StickerLibraryEvent Function(StickerEntity) wrap,
  ) {
    final sticker = StickerMapper.fromJsonOrNull(data['sticker']);
    return sticker == null ? null : wrap(sticker);
  }

  /// `presence` — who is online, as far as `yello-chat` will say.
  ///
  /// This is the one frame in the vocabulary whose payload is written down
  /// nowhere this repo can reach: the service's own OpenAPI summary lists
  /// `presence` as a server → client event and then says the socket protocol
  /// "is not expressible in OpenAPI", and the frame reference it points at is
  /// not in this repository. `Participant` carries no presence field either,
  /// so there is no HTTP shape to read it off instead. It is therefore read
  /// tolerantly, exactly as `typing` is, across the shapes a frame like this
  /// takes in practice:
  ///
  /// ```
  /// { userId, isOnline }                  one person changed
  /// { userId, online }                      ditto
  /// { userId, status: "ONLINE" }            ditto
  /// { users: [ { userId, isOnline }, … ] }  a batch, or the snapshot after auth
  /// { online: [ userId, … ] }               a bare snapshot of who is up
  /// ```
  ///
  /// `null` for a frame none of them fits, which [PresenceTracker] logs
  /// verbatim — one logcat line is then the whole fix. Naming a user with no
  /// state at all reads as *online*, on the same reasoning as `typing`'s
  /// absent flag: a frame is sent because something happened.
  static List<PresenceUpdate>? presence(Map<String, dynamic> frame) {
    if (frame['event'] != 'presence') return null;
    final data = frame['data'];
    final updates = <PresenceUpdate>[];

    // Id lists — a roster of who is up rather than one person changing.
    if (data is Map) {
      _addPresenceIds(data['online'], isOnline: true, into: updates);
      _addPresenceIds(data['offline'], isOnline: false, into: updates);
    }

    for (final entry in _presenceEntries(data)) {
      final userId = _firstString(entry, const ['userId', 'senderId', 'user', 'id']);
      if (userId == null) continue;
      updates.add((userId: userId, isOnline: _isOnlineFlag(entry)));
    }
    return updates.isEmpty ? null : updates;
  }

  /// `{ online: [ id, … ] }`. A `bool` under the same key is a state flag,
  /// not a roster, and is left to [_isOnlineFlag].
  static void _addPresenceIds(Object? raw, {required bool isOnline, required List<PresenceUpdate> into}) {
    if (raw is! List) return;
    for (final id in raw) {
      if (id is String && id.isNotEmpty) into.add((userId: id, isOnline: isOnline));
    }
  }

  /// The `{ userId, … }` objects in a frame: `data` itself, a bare list, or a
  /// list under whichever key a batch happens to use.
  static Iterable<Map<String, dynamic>> _presenceEntries(Object? data) {
    if (data is List) return data.whereType<Map<String, dynamic>>();
    if (data is! Map<String, dynamic>) return const [];
    for (final key in const ['users', 'presence', 'updates', 'participants']) {
      final nested = data[key];
      if (nested is List) return nested.whereType<Map<String, dynamic>>();
    }
    return [data];
  }

  /// A boolean flag, else a status word, else "this frame exists because
  /// they came online".
  static bool _isOnlineFlag(Map<String, dynamic> entry) {
    for (final key in const ['isOnline', 'online', 'isActive']) {
      final value = entry[key];
      if (value is bool) return value;
    }
    final status = _firstString(entry, const ['status', 'state', 'presence'])?.toUpperCase();
    return switch (status) {
      'OFFLINE' || 'AWAY' || 'INACTIVE' || 'GONE' => false,
      _ => true,
    };
  }

  static String? _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  static DateTime? _date(dynamic raw) => raw is String ? DateTime.tryParse(raw) : null;
}
