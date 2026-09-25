import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/features/communities/domain/entities/community_entity.dart';
import 'package:yello_social_app/features/communities/domain/entities/community_post_entity.dart';
import 'package:yello_social_app/features/communities/domain/usecases/communities_usecases.dart';
import 'package:yello_social_app/features/communities/presentation/bloc/community_feed_cubit.dart';

class _MockGetFeed extends Mock implements GetCommunityFeedUseCase {}

class _MockVote extends Mock implements VoteCommunityPostUseCase {}

class _MockReact extends Mock implements ReactToCommunityPostUseCase {}

CommunityPostEntity buildCommunityPost({
  String id = 'cp1',
  int commentCount = 0,
  Map<String, int> reactionCounts = const {},
  int score = 0,
}) {
  return CommunityPostEntity(
    id: id,
    community: const CommunitySummaryEntity(slug: 'design', name: 'Design', emoji: '🎨'),
    authorId: 'u1',
    authorUsername: 'amara',
    title: 'Atrium light exploration',
    body: 'Notes from the third pass.',
    tag: 'DISCUSSION',
    score: score,
    reactionCounts: reactionCounts,
    commentCount: commentCount,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  late _MockGetFeed getFeed;
  late _MockVote vote;
  late _MockReact react;

  setUp(() {
    getFeed = _MockGetFeed();
    vote = _MockVote();
    react = _MockReact();
  });

  CommunityFeedCubit buildCubit() => CommunityFeedCubit(getFeed: getFeed, vote: vote, react: react);

  // The timeline is never re-fetched on the way back from a thread, so this
  // handoff is the only thing standing between the user and the counts the
  // row had when they tapped it. See ADR-032.
  blocTest<CommunityFeedCubit, CommunityFeedState>(
    'applyUpdated swaps the thread the user came back from, with its new counts',
    build: buildCubit,
    seed: () => CommunityFeedState(
      status: CommunityFeedStatus.loaded,
      posts: [
        buildCommunityPost(id: 'cp1', commentCount: 2, reactionCounts: const {'LIKE': 1}),
        buildCommunityPost(id: 'cp2', commentCount: 9),
      ],
    ),
    act: (cubit) => cubit.applyUpdated(
      buildCommunityPost(id: 'cp1', commentCount: 3, reactionCounts: const {'LIKE': 1, 'WOW': 1}),
    ),
    expect: () => [
      predicate<CommunityFeedState>(
        (s) =>
            s.posts.first.id == 'cp1' &&
            s.posts.first.commentCount == 3 &&
            s.posts.first.reactionTotal == 2 &&
            // …and only that row: the one beside it is untouched, and the
            // order the server sorted is kept even though `hot` has genuinely
            // moved underneath this list.
            s.posts.last.id == 'cp2' &&
            s.posts.last.commentCount == 9,
      ),
    ],
  );

  blocTest<CommunityFeedCubit, CommunityFeedState>(
    'applyUpdated ignores a thread this timeline no longer lists',
    build: buildCubit,
    seed: () => CommunityFeedState(status: CommunityFeedStatus.loaded, posts: [buildCommunityPost(id: 'cp1')]),
    act: (cubit) => cubit.applyUpdated(buildCommunityPost(id: 'gone', commentCount: 4)),
    // Nothing at all: the rebuilt list compares equal to the current one, and
    // `Cubit.emit` drops a state that `==` what it already holds.
    expect: () => <CommunityFeedState>[],
    verify: (cubit) => expect(cubit.state.posts.single.id, 'cp1'),
  );
}
