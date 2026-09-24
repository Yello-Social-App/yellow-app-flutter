import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/story_entity.dart';
import '../../domain/repositories/story_repository.dart';
import '../datasources/story_remote_datasource.dart';

class StoryRepositoryImpl implements StoryRepository {
  StoryRepositoryImpl(this._remote, this._networkInfo);

  final StoryRemoteDataSource _remote;
  final NetworkInfo _networkInfo;

  Future<Either<Failure, T>> _run<T>(Future<T> Function() body) async {
    if (!await _networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await body());
    } on AppException catch (e) {
      return Left(ErrorHandler.toFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, StoryRailEntity>> getRail() => _run(() async {
        // Two independent reads — `/stories/me` is deliberately excluded
        // from `/stories/feed`, so the rail always needs both. Fired
        // together rather than in sequence: the rail is above the fold on
        // Home and one round-trip of latency is the whole budget.
        //
        // `Future.wait` rather than two bare `await`s: it rethrows the
        // original exception (so `_run`'s `on AppException` still catches
        // it) *and* consumes the other future's error, which a sequential
        // pair would leave unhandled when the first one is the one to fail.
        final results = await Future.wait<Object>([_remote.getMyStories(), _remote.getFeed()]);
        final mine = results[0] as List<StoryEntity>;
        final feed = results[1] as ({List<StoryRingEntity> rings, bool hasMore});
        return StoryRailEntity(mine: StoryRingEntity.mine(mine), rings: feed.rings);
      });

  @override
  Future<Either<Failure, List<StoryEntity>>> getUserStories(String userId) =>
      _run(() => _remote.getUserStories(userId));

  @override
  Future<Either<Failure, StoryEntity>> getStory(String storyId) => _run(() => _remote.getStory(storyId));

  @override
  Future<Either<Failure, StoryEntity>> createStory({
    String? text,
    StoryBackground? background,
    File? image,
    StoryVisibility visibility = StoryVisibility.friends,
  }) => _run(() => _remote.createStory(text: text, background: background, image: image, visibility: visibility));

  @override
  Future<Either<Failure, void>> markViewed(String storyId) => _run(() => _remote.markViewed(storyId));

  @override
  Future<Either<Failure, StoryViewersPage>> getViewers(String storyId, {int page = 0}) => _run(() async {
        final result = await _remote.getViewers(storyId, page: page);
        return StoryViewersPage(
          viewers: result.viewers,
          hasMore: result.hasMore,
          totalElements: result.totalElements,
        );
      });

  @override
  Future<Either<Failure, StoryArchivePage>> getArchive({
    int page = 0,
    StoryArchiveFilter filter = const StoryArchiveFilter(),
  }) => _run(() async {
        final result = await _remote.getArchive(page: page, filter: filter);
        return StoryArchivePage(stories: result.stories, hasMore: result.hasMore);
      });

  @override
  Future<Either<Failure, void>> deleteStory(String storyId) => _run(() => _remote.deleteStory(storyId));

  @override
  Future<Either<Failure, StoryReplyReceipt>> replyToStory({
    required String storyId,
    required String text,
    required String clientId,
  }) => _run(() => _remote.replyToStory(storyId: storyId, text: text, clientId: clientId));
}
