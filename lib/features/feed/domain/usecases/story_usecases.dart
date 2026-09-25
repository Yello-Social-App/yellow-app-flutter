import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/story_entity.dart';
import '../repositories/story_repository.dart';

/// Every story action, in one file the way `react_usecases.dart` groups the
/// reaction ones — they share a single repository and are only ever read
/// together.

/// The whole stories rail: your own ring plus everyone else's.
class GetStoryRailUseCase implements UseCase<StoryRailEntity, NoParams> {
  GetStoryRailUseCase(this._repository);

  final StoryRepository _repository;

  @override
  Future<Either<Failure, StoryRailEntity>> call(NoParams params) => _repository.getRail();
}

/// One user's active stories — for opening a ring from their profile.
class GetUserStoriesUseCase implements UseCase<List<StoryEntity>, String> {
  GetUserStoriesUseCase(this._repository);

  final StoryRepository _repository;

  @override
  Future<Either<Failure, List<StoryEntity>>> call(String userId) => _repository.getUserStories(userId);
}

/// One story by id — a deep link, or a refetch for a fresh signed image URL.
class GetStoryUseCase implements UseCase<StoryEntity, String> {
  GetStoryUseCase(this._repository);

  final StoryRepository _repository;

  @override
  Future<Either<Failure, StoryEntity>> call(String storyId) => _repository.getStory(storyId);
}

class CreateStoryParams extends Equatable {
  const CreateStoryParams({
    this.text,
    this.background,
    this.image,
    this.visibility = StoryVisibility.friends,
  });

  /// The whole story on a `TEXT` one, an optional caption on an `IMAGE` one.
  final String? text;

  /// Required for a `TEXT` story, ignored server-side on an `IMAGE` one.
  final StoryBackground? background;

  /// Non-null makes this an `IMAGE` story.
  final File? image;
  final StoryVisibility visibility;

  @override
  List<Object?> get props => [text, background, image?.path, visibility];
}

class CreateStoryUseCase implements UseCase<StoryEntity, CreateStoryParams> {
  CreateStoryUseCase(this._repository);

  final StoryRepository _repository;

  @override
  Future<Either<Failure, StoryEntity>> call(CreateStoryParams params) => _repository.createStory(
        text: params.text,
        background: params.background,
        image: params.image,
        visibility: params.visibility,
      );
}

/// Marks one slide seen by the viewer. Fire-and-forget at every call site —
/// a failed view never interrupts playback.
class MarkStoryViewedUseCase implements UseCase<void, String> {
  MarkStoryViewedUseCase(this._repository);

  final StoryRepository _repository;

  @override
  Future<Either<Failure, void>> call(String storyId) => _repository.markViewed(storyId);
}

class GetStoryViewersParams extends Equatable {
  const GetStoryViewersParams({required this.storyId, this.page = 0});
  final String storyId;
  final int page;

  @override
  List<Object?> get props => [storyId, page];
}

class GetStoryViewersUseCase implements UseCase<StoryViewersPage, GetStoryViewersParams> {
  GetStoryViewersUseCase(this._repository);

  final StoryRepository _repository;

  @override
  Future<Either<Failure, StoryViewersPage>> call(GetStoryViewersParams params) =>
      _repository.getViewers(params.storyId, page: params.page);
}

class GetStoryArchiveParams extends Equatable {
  const GetStoryArchiveParams({this.page = 0, this.filter = const StoryArchiveFilter()});
  final int page;
  final StoryArchiveFilter filter;

  @override
  List<Object?> get props => [page, filter.from, filter.to, filter.type];
}

class GetStoryArchiveUseCase implements UseCase<StoryArchivePage, GetStoryArchiveParams> {
  GetStoryArchiveUseCase(this._repository);

  final StoryRepository _repository;

  @override
  Future<Either<Failure, StoryArchivePage>> call(GetStoryArchiveParams params) =>
      _repository.getArchive(page: params.page, filter: params.filter);
}

class DeleteStoryUseCase implements UseCase<void, String> {
  DeleteStoryUseCase(this._repository);

  final StoryRepository _repository;

  @override
  Future<Either<Failure, void>> call(String storyId) => _repository.deleteStory(storyId);
}

class ReplyToStoryParams extends Equatable {
  const ReplyToStoryParams({required this.storyId, required this.text, required this.clientId});

  final String storyId;
  final String text;

  /// The idempotency key for the DM. Generated once per reply attempt and
  /// **reused** across retries — see `StoryRepository.replyToStory`.
  final String clientId;

  @override
  List<Object?> get props => [storyId, text, clientId];
}

class ReplyToStoryUseCase implements UseCase<StoryReplyReceipt, ReplyToStoryParams> {
  ReplyToStoryUseCase(this._repository);

  final StoryRepository _repository;

  @override
  Future<Either<Failure, StoryReplyReceipt>> call(ReplyToStoryParams params) => _repository.replyToStory(
        storyId: params.storyId,
        text: params.text,
        clientId: params.clientId,
      );
}
