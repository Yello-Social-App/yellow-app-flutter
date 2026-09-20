import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../feed/domain/entities/comment_entity.dart';
import '../../../feed/domain/entities/post_entity.dart' show ReactionType;
import '../../../feed/domain/usecases/add_comment_usecase.dart' show kCommentMaxChars;
import '../entities/community_entity.dart';
import '../entities/community_post_entity.dart';
import '../repositories/communities_repository.dart';

class GetCommunitiesParams extends Equatable {
  const GetCommunitiesParams({this.query, this.membership, this.sort = CommunitySort.popular, this.page = 0});

  /// Free-text filter on name/tagline. Null or blank means no filter — the
  /// backend has no minimum length here (unlike `/users/search`), but sending
  /// an empty `q` is still pointless, so it is dropped below.
  final String? query;
  final CommunityMembershipFilter? membership;
  final CommunitySort sort;
  final int page;

  @override
  List<Object?> get props => [query, membership, sort, page];
}

class GetCommunitiesUseCase implements UseCase<CommunitiesPage, GetCommunitiesParams> {
  GetCommunitiesUseCase(this._repository);
  final CommunitiesRepository _repository;

  @override
  Future<Either<Failure, CommunitiesPage>> call(GetCommunitiesParams params) {
    final query = params.query?.trim();
    return _repository.getCommunities(
      query: (query == null || query.isEmpty) ? null : query,
      membership: params.membership,
      sort: params.sort,
      page: params.page,
    );
  }
}

/// [slug], not a uuid — see [CommunityEntity.slug].
class CommunitySlugParams extends Equatable {
  const CommunitySlugParams(this.slug);
  final String slug;

  @override
  List<Object?> get props => [slug];
}

class GetCommunityUseCase implements UseCase<CommunityEntity, CommunitySlugParams> {
  GetCommunityUseCase(this._repository);
  final CommunitiesRepository _repository;

  @override
  Future<Either<Failure, CommunityEntity>> call(CommunitySlugParams params) =>
      _repository.getCommunity(params.slug);
}

class JoinCommunityUseCase implements UseCase<CommunityEntity, CommunitySlugParams> {
  JoinCommunityUseCase(this._repository);
  final CommunitiesRepository _repository;

  @override
  Future<Either<Failure, CommunityEntity>> call(CommunitySlugParams params) =>
      _repository.joinCommunity(params.slug);
}

class LeaveCommunityUseCase implements UseCase<CommunityEntity, CommunitySlugParams> {
  LeaveCommunityUseCase(this._repository);
  final CommunitiesRepository _repository;

  @override
  Future<Either<Failure, CommunityEntity>> call(CommunitySlugParams params) =>
      _repository.leaveCommunity(params.slug);
}

class CommunityFeedParams extends Equatable {
  const CommunityFeedParams({
    this.scope = CommunityFeedScope.all,
    this.sort = CommunityPostSort.hot,
    this.cursor,
  });

  final CommunityFeedScope scope;
  final CommunityPostSort sort;
  final String? cursor;

  @override
  List<Object?> get props => [scope, sort, cursor];
}

/// The cross-community timeline — `GET /community-posts`.
class GetCommunityFeedUseCase implements UseCase<CommunityPostsPage, CommunityFeedParams> {
  GetCommunityFeedUseCase(this._repository);
  final CommunitiesRepository _repository;

  @override
  Future<Either<Failure, CommunityPostsPage>> call(CommunityFeedParams params) =>
      _repository.getCommunityPostFeed(scope: params.scope, sort: params.sort, cursor: params.cursor);
}

class CommunityPostsParams extends Equatable {
  const CommunityPostsParams({required this.slug, this.sort = CommunityPostSort.hot, this.cursor});

  final String slug;
  final CommunityPostSort sort;
  final String? cursor;

  @override
  List<Object?> get props => [slug, sort, cursor];
}

/// One community's own threads — `GET /communities/{slug}/posts`.
class GetCommunityPostsUseCase implements UseCase<CommunityPostsPage, CommunityPostsParams> {
  GetCommunityPostsUseCase(this._repository);
  final CommunitiesRepository _repository;

  @override
  Future<Either<Failure, CommunityPostsPage>> call(CommunityPostsParams params) =>
      _repository.getCommunityPosts(params.slug, sort: params.sort, cursor: params.cursor);
}

class CreateCommunityPostParams extends Equatable {
  const CreateCommunityPostParams({
    required this.slug,
    required this.title,
    required this.tag,
    this.body,
  });

  final String slug;
  final String title;

  /// Must be one of the parent community's `tags` — the server validates it,
  /// so a composer offers those values rather than free text.
  final String tag;
  final String? body;

  @override
  List<Object?> get props => [slug, title, tag, body];
}

class CreateCommunityPostUseCase implements UseCase<CommunityPostEntity, CreateCommunityPostParams> {
  CreateCommunityPostUseCase(this._repository);
  final CommunitiesRepository _repository;

  @override
  Future<Either<Failure, CommunityPostEntity>> call(CreateCommunityPostParams params) {
    final title = InputSanitizer.sanitizeText(params.title, maxLength: kCommunityPostTitleMaxChars);
    if (title.isEmpty) {
      return Future.value(const Left(ValidationFailure('Give your post a title.')));
    }
    if (params.tag.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Pick a tag for your post.')));
    }
    final body = params.body == null
        ? null
        : InputSanitizer.sanitizeText(params.body!, maxLength: kCommunityPostBodyMaxChars);
    return _repository.createPost(
      params.slug,
      title: title,
      tag: params.tag.trim(),
      // A title-only thread is valid, so an empty body is sent as absent
      // rather than as an empty string.
      body: (body == null || body.isEmpty) ? null : body,
    );
  }
}

class VoteCommunityPostParams extends Equatable {
  const VoteCommunityPostParams({required this.post, required this.vote});
  final CommunityPostEntity post;

  /// The vote to end up with — pass [CommunityVote.none] to clear. Use
  /// `CommunityVote.toggledFrom` at the call site to turn a button tap into
  /// this absolute value.
  final CommunityVote vote;

  @override
  List<Object?> get props => [post, vote];
}

class VoteCommunityPostUseCase implements UseCase<CommunityPostEntity, VoteCommunityPostParams> {
  VoteCommunityPostUseCase(this._repository);
  final CommunitiesRepository _repository;

  @override
  Future<Either<Failure, CommunityPostEntity>> call(VoteCommunityPostParams params) =>
      _repository.vote(params.post, params.vote);
}

class ReactToCommunityPostParams extends Equatable {
  const ReactToCommunityPostParams({required this.post, required this.type});
  final CommunityPostEntity post;
  final ReactionType type;

  @override
  List<Object?> get props => [post, type];
}

class ReactToCommunityPostUseCase implements UseCase<CommunityPostEntity, ReactToCommunityPostParams> {
  ReactToCommunityPostUseCase(this._repository);
  final CommunitiesRepository _repository;

  @override
  Future<Either<Failure, CommunityPostEntity>> call(ReactToCommunityPostParams params) =>
      _repository.react(params.post, params.type);
}

class CommunityCommentsParams extends Equatable {
  const CommunityCommentsParams({required this.postId, this.page = 0});
  final String postId;
  final int page;

  @override
  List<Object?> get props => [postId, page];
}

class GetCommunityCommentsUseCase implements UseCase<CommunityCommentsPage, CommunityCommentsParams> {
  GetCommunityCommentsUseCase(this._repository);
  final CommunitiesRepository _repository;

  @override
  Future<Either<Failure, CommunityCommentsPage>> call(CommunityCommentsParams params) =>
      _repository.getComments(params.postId, page: params.page);
}

class AddCommunityCommentParams extends Equatable {
  const AddCommunityCommentParams({required this.postId, required this.text, this.parentCommentId});
  final String postId;
  final String text;
  final String? parentCommentId;

  @override
  List<Object?> get props => [postId, text, parentCommentId];
}

/// Comments on a community post go to their own collection
/// (`/community-posts/{id}/comments`), so this is a sibling of the feed's
/// `AddCommentUseCase` rather than a reuse of it — but the same 2000-char cap
/// applies, hence the shared constant.
class AddCommunityCommentUseCase implements UseCase<CommentEntity, AddCommunityCommentParams> {
  AddCommunityCommentUseCase(this._repository);
  final CommunitiesRepository _repository;

  @override
  Future<Either<Failure, CommentEntity>> call(AddCommunityCommentParams params) {
    final clean = InputSanitizer.sanitizeText(params.text, maxLength: kCommentMaxChars);
    if (clean.isEmpty) {
      return Future.value(const Left(ValidationFailure('Comment cannot be empty.')));
    }
    return _repository.addComment(params.postId, clean, parentCommentId: params.parentCommentId);
  }
}
