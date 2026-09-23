import 'package:equatable/equatable.dart';

/// The backend's `featureId` vocabulary for `POST /v1/feedback` — all seven
/// values, because `GET /v1/feedback/me` can return any of them for a
/// rating submitted from another client or an older build.
///
/// [pickable] is the subset this app offers in its own picker: `compactMode`
/// and `inAppUpdates` name features Yello does not have, so asking someone
/// to rate them would be nonsense. They still parse — that is the whole
/// point of keeping them here.
enum FeedbackFeature {
  messages('messages', 'Messages'),
  stories('stories', 'Stories'),
  communities('communities', 'Communities'),
  showcase('showcase', 'Showcase'),
  compactMode('compact-mode', 'Compact mode'),
  inAppUpdates('in-app-updates', 'In-app updates'),
  other('other', 'Something else');

  const FeedbackFeature(this.wire, this.label);

  /// The exact string the API expects and returns.
  final String wire;

  /// Display copy for the picker and the "your recent feedback" list.
  final String label;

  /// What this app's own picker offers, in the order it lists them.
  static const List<FeedbackFeature> pickable = [messages, stories, communities, showcase, other];

  /// Unknown values fall back to [other] rather than throwing — a value the
  /// backend starts sending later should degrade to a readable row, not
  /// break the whole page (same rule `NotificationTypes` follows).
  static FeedbackFeature fromWire(String? value) =>
      FeedbackFeature.values.firstWhere((f) => f.wire == value, orElse: () => FeedbackFeature.other);
}

/// One submitted rating. `diagnostics` is stored server-side but never
/// returned, so it is not a field here — see `SubmitFeedbackParams`.
class FeedbackEntity extends Equatable {
  const FeedbackEntity({
    required this.id,
    required this.feature,
    required this.rating,
    required this.createdAt,
    this.note,
  });

  final String id;
  final FeedbackFeature feature;

  /// 1-5, as the API constrains it.
  final int rating;

  /// Trimmed server-side; an empty note is stored as null, never `""`.
  final String? note;

  final DateTime createdAt;

  @override
  List<Object?> get props => [id, feature, rating, note, createdAt];
}
