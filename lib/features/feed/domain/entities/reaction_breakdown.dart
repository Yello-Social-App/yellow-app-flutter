import 'package:equatable/equatable.dart';

import 'post_entity.dart' show ReactionType;

/// The live per-type breakdown from
/// `GET /reactions/{targetType}/{targetId}/summary` — distinct from
/// `PostEntity.reactionCounts`/`CommentEntity.reactionCount`, which ride
/// along on the post/comment itself for free. This is a deliberate,
/// on-demand fetch for a "who reacted, and with what" view (see
/// `PostDetailCubit.getReactionSummary` / the post overflow menu's
/// "View reactions").
class ReactionBreakdown extends Equatable {
  const ReactionBreakdown({required this.counts, this.viewerReaction});

  final Map<ReactionType, int> counts;
  final ReactionType? viewerReaction;

  int get total => counts.values.fold(0, (a, b) => a + b);

  @override
  List<Object?> get props => [counts, viewerReaction];
}
