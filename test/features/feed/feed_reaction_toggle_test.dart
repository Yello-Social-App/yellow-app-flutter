import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/network/network_info.dart';
import 'package:yello_social_app/features/feed/data/datasources/bookmarks_local_datasource.dart';
import 'package:yello_social_app/features/feed/data/datasources/feed_remote_datasource.dart';
import 'package:yello_social_app/features/feed/data/repositories/feed_repository_impl.dart';
import 'package:yello_social_app/features/feed/domain/entities/post_entity.dart';

import '../../helpers/mock_data.dart';

class _MockRemote extends Mock implements FeedRemoteDataSource {}

class _MockBookmarks extends Mock implements BookmarksLocalDataSource {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

/// The reaction endpoint is one POST toggle keyed on the type sent: the same
/// type as the viewer's current reaction removes it, a *different* one
/// switches to it. So which type `toggleLike` puts on the wire is the whole
/// behaviour of the quick-like tap, and it's what regressed — a plain tap on
/// a post the viewer had reacted to with 😆 used to send `LIKE`, which the
/// server read as "change it to LIKE" instead of "take my reaction back".
void main() {
  late _MockRemote remote;
  late _MockBookmarks bookmarks;
  late _MockNetworkInfo networkInfo;
  late FeedRepositoryImpl repository;

  ReactionSummary summaryOf(Map<String, int> counts, String? viewer) =>
      ReactionSummary(counts: counts, viewerReaction: viewer, total: counts.values.fold(0, (a, b) => a + b));

  setUp(() {
    remote = _MockRemote();
    bookmarks = _MockBookmarks();
    networkInfo = _MockNetworkInfo();
    repository = FeedRepositoryImpl(remote, bookmarks, networkInfo);
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
  });

  test('toggleLike sends LIKE when the viewer has not reacted yet', () async {
    when(() => remote.react(any(), type: any(named: 'type'))).thenAnswer((_) async => summaryOf({'LIKE': 1}, 'LIKE'));

    final result = await repository.toggleLike(buildPost(id: 'p1'));

    verify(() => remote.react('p1', type: 'LIKE')).called(1);
    expect(result.getOrElse(() => throw 'left').viewerReactionType, ReactionType.like);
  });

  test('toggleLike echoes the viewer\'s own reaction type so a non-LIKE reaction is removed, not switched', () async {
    when(() => remote.react(any(), type: any(named: 'type'))).thenAnswer((_) async => summaryOf({}, null));
    final reactedHaha = buildPost(id: 'p1').copyWith(reactionCounts: {'HAHA': 1}, viewerReaction: 'HAHA');

    final result = await repository.toggleLike(reactedHaha);

    // Not `type: 'LIKE'` — that's the bug this test pins down.
    verify(() => remote.react('p1', type: 'HAHA')).called(1);
    expect(result.getOrElse(() => throw 'left').viewerReactionType, isNull);
  });

  test('toggleLike still un-likes a post the viewer had liked', () async {
    when(() => remote.react(any(), type: any(named: 'type'))).thenAnswer((_) async => summaryOf({}, null));

    final result = await repository.toggleLike(buildPost(id: 'p1', likeCount: 1, viewerReaction: 'LIKE'));

    verify(() => remote.react('p1', type: 'LIKE')).called(1);
    expect(result.getOrElse(() => throw 'left').viewerReactionType, isNull);
  });
}
