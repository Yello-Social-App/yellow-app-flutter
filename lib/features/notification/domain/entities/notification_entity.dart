import 'package:equatable/equatable.dart';

/// Wire vocabulary for `NotificationResponse.type` — kept as plain strings
/// (not a Dart enum) so a value the backend starts sending later degrades
/// gracefully in presentation (icon/verb fallback) instead of throwing on
/// parse. Mirrors `yello-notify`'s `NotificationType` exactly; see the
/// service's own reference doc for the authoritative list and its
/// deep-link `data` keys.
abstract final class NotificationTypes {
  static const postCreated = 'POST_CREATED';
  static const postCommented = 'POST_COMMENTED';
  static const commentReplied = 'COMMENT_REPLIED';
  static const postReposted = 'POST_REPOSTED';
  static const postReacted = 'POST_REACTED';
  static const commentReacted = 'COMMENT_REACTED';
  static const friendRequestReceived = 'FRIEND_REQUEST_RECEIVED';
  static const friendRequestAccepted = 'FRIEND_REQUEST_ACCEPTED';

  /// Chat activity is push-only: `yello-notify` never stores it as an inbox
  /// row (the conversation itself is the record), so these never reach
  /// Signals. They *are* mutable in preferences, which is why the list
  /// below carries them.
  static const chatMessage = 'CHAT_MESSAGE';

  /// A first reaction on one of the viewer's messages. Changing or removing
  /// a reaction, or reacting to your own message, sends nothing.
  static const chatReaction = 'CHAT_REACTION';

  /// A data-only push with no notification block: someone unsent a message
  /// and the alert shown for it must be taken down by the app. Never a row,
  /// never a preference — see `PushNotificationService`.
  static const chatMessageDeleted = 'CHAT_MESSAGE_DELETED';

  /// A moderator decided a report the viewer filed. Shown both as a push and
  /// as a Signals row; `data` carries `reportId` and `status`
  /// (`ACTION_TAKEN` / `NO_VIOLATION`) and deliberately says nothing about
  /// the post, its author, or who decided. Tapping it opens Privacy &
  /// safety, where `GET /v1/reports/me` has the outcome.
  static const reportResolved = 'REPORT_RESOLVED';

  /// A data-only push with no notification block and no inbox row: someone
  /// unfriended the viewer, declined their request, or cancelled a request
  /// they had sent. `data` carries only `userId` (the other party) and is
  /// the app's cue to re-read friend state for them. A *block* sends
  /// nothing, so blocking is never revealed this way.
  static const friendshipChanged = 'FRIENDSHIP_CHANGED';

  /// Post and friend activity shown in Signals. Notification recipients are
  /// determined by the notification service.
  static const signalTypes = {
    postCreated,
    postCommented,
    commentReplied,
    postReposted,
    postReacted,
    commentReacted,
    friendRequestReceived,
    friendRequestAccepted,
    reportResolved,
  };

  /// Every type a user can mute, in the order the preferences screen lists
  /// them. [chatMessageDeleted] and [friendshipChanged] are deliberately
  /// absent: both are silent, so there is nothing to mute. [reportResolved]
  /// is absent too — the notify service's preference vocabulary has not been
  /// confirmed to carry it, and a toggle the server drops would read as a
  /// broken switch. Add it here once `GET /notifications/v1/preferences`
  /// is seen returning it.
  static const all = [
    postCreated,
    postCommented,
    commentReplied,
    postReposted,
    postReacted,
    commentReacted,
    friendRequestReceived,
    friendRequestAccepted,
    chatMessage,
    chatReaction,
  ];
}

/// One row of `GET /notifications/v1`. `title`/`body` are frozen display
/// text rendered server-side (aggregation-aware, e.g. "alice and 2 others
/// commented on your post") — render them as given, never rebuild the
/// sentence client-side from `type`/`actorId`.
class NotificationEntity extends Equatable {
  const NotificationEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    this.actorId,
    required this.aggregateCount,
    required this.read,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String type;
  bool get isSignal => NotificationTypes.signalTypes.contains(type);
  final String title;
  final String body;

  /// Deep-link hints — always string-valued (the FCM data map allows
  /// nothing else) and includes `type` itself. Which other keys are present
  /// depends on [type]; read defensively rather than assuming a key exists.
  final Map<String, String> data;

  /// The most recent actor when this row is an aggregate of several events.
  /// Nullable per the response model, though every documented [type]
  /// populates it today.
  final String? actorId;

  /// How many actors collapsed into this one row. `1` unless aggregated.
  final int aggregateCount;

  final bool read;
  final DateTime? readAt;
  final DateTime createdAt;

  /// Last activity, and the inbox's sort key. **Not** bumped by marking the
  /// row read, so acknowledging never reshuffles the list under the user —
  /// aggregation *does* bump it, which can jump a row to the top between
  /// two page fetches (see `NotificationsCubit.loadMore`'s de-dupe).
  final DateTime updatedAt;

  /// Actionable with Accept/Decline — an incoming request the viewer hasn't
  /// responded to yet. `FRIEND_REQUEST_ACCEPTED` (someone accepted *your*
  /// outgoing request) is informational only and never shows these.
  bool get isFriendRequestReceived => type == NotificationTypes.friendRequestReceived;

  NotificationEntity copyWith({bool? read, DateTime? readAt}) => NotificationEntity(
    id: id,
    type: type,
    title: title,
    body: body,
    data: data,
    actorId: actorId,
    aggregateCount: aggregateCount,
    read: read ?? this.read,
    readAt: readAt ?? this.readAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  List<Object?> get props => [id, read, aggregateCount, updatedAt];
}

/// One page of `GET /notifications/v1` — keyset/cursor pagination, no
/// offset and no total count.
class NotificationsPage {
  const NotificationsPage({required this.items, this.nextCursor});

  final List<NotificationEntity> items;
  final String? nextCursor;

  /// `nextCursor == null` is the *only* stop condition — an empty [items]
  /// page is not, since aggregation/deletes can legitimately empty a page
  /// that isn't the last one.
  bool get hasMore => nextCursor != null;
}
