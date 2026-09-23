import '../../domain/entities/feedback_entity.dart';

/// Parses the API's `Feedback`:
///
/// ```json
/// { "id": "0b6f6c3e-…", "featureId": "messages", "rating": 2,
///   "note": "Messages arrive out of order after sleep.",
///   "createdAt": "2026-09-22T10:15:00Z" }
/// ```
///
/// `diagnostics` is accepted on the way in and stored, but never comes
/// back, so there is nothing to read for it here.
class FeedbackModel extends FeedbackEntity {
  const FeedbackModel({
    required super.id,
    required super.feature,
    required super.rating,
    required super.createdAt,
    super.note,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'] as String? ?? '',
      feature: FeedbackFeature.fromWire(json['featureId'] as String?),
      // Clamped rather than trusted: the picker only ever sends 1-5, but a
      // row rendered as N stars should not be able to draw -1 of them.
      rating: ((json['rating'] as num?)?.toInt() ?? 1).clamp(1, 5),
      note: json['note'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
