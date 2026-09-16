import 'package:equatable/equatable.dart';

/// `GET`/`PUT /notifications/v1/preferences` — push opt-outs only. Muting a
/// type never touches the inbox itself: a muted row still lands via
/// `GET /notifications/v1` and still counts toward `unread-count`, only the
/// push notification for it is suppressed. Word any UI copy accordingly
/// ("Don't notify me about reactions", not "Hide reactions").
class NotificationPreferencesEntity extends Equatable {
  const NotificationPreferencesEntity({required this.pushEnabled, required this.mutedTypes});

  final bool pushEnabled;
  final List<String> mutedTypes;

  /// What a user who has never saved preferences gets back — there is no
  /// 404 for "not configured yet", the server already returns this shape.
  static const defaults = NotificationPreferencesEntity(pushEnabled: true, mutedTypes: []);

  NotificationPreferencesEntity copyWith({bool? pushEnabled, List<String>? mutedTypes}) =>
      NotificationPreferencesEntity(
        pushEnabled: pushEnabled ?? this.pushEnabled,
        mutedTypes: mutedTypes ?? this.mutedTypes,
      );

  @override
  List<Object?> get props => [pushEnabled, mutedTypes];
}
