import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/comment_entity.dart';
import '../entities/post_entity.dart';
import '../entities/reaction_breakdown.dart';
import '../repositories/feed_repository.dart';

class ReactToPostParams extends Equatable {
  const ReactToPostParams({required this.post, required this.type});
  final PostEntity post;
  final ReactionType type;

  @override
  List<Object?> get props => [post, type];
}

/// Sets/switches/removes the viewer's reaction on a post — the multi-type
/// sibling of [LikePostUseCase] (kept separate rather than replacing it so
/// the existing single-tap "quick like" path is untouched).
class ReactToPostUseCase implements UseCase<PostEntity, ReactToPostParams> {
  ReactToPostUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, PostEntity>> call(ReactToPostParams params) =>
      _repository.reactToPost(params.post, params.type);
}

class ReactToCommentParams extends Equatable {
  const ReactToCommentParams({required this.comment, required this.type});
  final CommentEntity comment;
  final ReactionType type;

  @override
  List<Object?> get props => [comment, type];
}

/// Same set/switch/remove semantics as [ReactToPostUseCase], against a
/// comment (`targetType=COMMENT`).
class ReactToCommentUseCase implements UseCase<CommentEntity, ReactToCommentParams> {
  ReactToCommentUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, CommentEntity>> call(ReactToCommentParams params) =>
      _repository.reactToComment(params.comment, params.type);
}

class GetReactionSummaryParams extends Equatable {
  const GetReactionSummaryParams({required this.targetType, required this.targetId});

  /// `'POST'` or `'COMMENT'`.
  final String targetType;
  final String targetId;

  @override
  List<Object?> get props => [targetType, targetId];
}

/// On-demand reaction breakdown (`GET /reactions/{targetType}/{targetId}/summary`)
/// — e.g. the post overflow menu's "View reactions".
class GetReactionSummaryUseCase implements UseCase<ReactionBreakdown, GetReactionSummaryParams> {
  GetReactionSummaryUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, ReactionBreakdown>> call(GetReactionSummaryParams params) =>
      _repository.getReactionSummary(targetType: params.targetType, targetId: params.targetId);
}

class GetReactorsParams extends Equatable {
  const GetReactorsParams({required this.targetType, required this.targetId, this.type, this.page = 0});

  final String targetType;
  final String targetId;
  final ReactionType? type;
  final int page;

  @override
  List<Object?> get props => [targetType, targetId, type, page];
}

/// Paginated "who reacted, and with what" — distinct from
/// [GetReactionSummaryUseCase], which only returns per-type totals.
class GetReactorsUseCase implements UseCase<ReactorsPage, GetReactorsParams> {
  GetReactorsUseCase(this._repository);

  final FeedRepository _repository;

  @override
  Future<Either<Failure, ReactorsPage>> call(GetReactorsParams params) => _repository.getReactors(
    targetType: params.targetType,
    targetId: params.targetId,
    type: params.type,
    page: params.page,
  );
}
