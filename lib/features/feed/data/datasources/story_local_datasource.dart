import '../models/story_model.dart';

/// Stories have no backend endpoint at all (the live API's spec has no
/// `/stories` resource) — this is a permanent, purely client-side seed
/// standing in for a feature the backend hasn't built yet, not a
/// placeholder for something that will later swap to [FeedRemoteDataSource].
/// Content matches the Yello Mobile v2 design source's demo stories.
abstract interface class StoryLocalDataSource {
  Future<List<StoryModel>> getStories();

  /// Flips [userId]'s tray to seen (mutates the in-memory seed in place —
  /// there's no backend to persist this to, so it only lasts the app
  /// session; see class doc).
  Future<void> markSeen(String userId);
}

class StoryLocalDataSourceImpl implements StoryLocalDataSource {
  final _latency = const Duration(milliseconds: 200);

  static final List<StoryModel> _stories = [
    StoryModel(
      userId: 'demo-sarah-jenkins',
      name: 'Sarah Jenkins',
      avatarSeed: 1,
      seen: false,
      segments: const [
        StorySegmentModel(
          time: '2H AGO',
          tag: 'MORNING LIGHT',
          caption: 'The east stairwell only does this for eleven minutes.',
        ),
        StorySegmentModel(time: '2H AGO', tag: 'MORNING LIGHT', caption: 'Same wall, four minutes later.'),
        StorySegmentModel(time: '1H AGO', tag: 'MORNING LIGHT', caption: "Then it's gone until tomorrow."),
      ],
    ),
    StoryModel(
      userId: 'demo-marcus-cole',
      name: 'Marcus Cole',
      avatarSeed: 2,
      seen: false,
      segments: const [
        StorySegmentModel(time: '4H AGO', tag: 'STUDIO', caption: 'Third model. Still too heavy.'),
        StorySegmentModel(time: '3H AGO', tag: 'STUDIO', caption: 'Took 40 grams out of the base.'),
      ],
    ),
    StoryModel(
      userId: 'demo-elena-rostova',
      name: 'Elena Rostova',
      avatarSeed: 3,
      seen: true,
      segments: const [
        StorySegmentModel(time: '6H AGO', tag: 'OFF-SITE', caption: 'Concrete, cold coffee, good company.'),
      ],
    ),
    StoryModel(
      userId: 'demo-david-kim',
      name: 'David Kim',
      avatarSeed: 4,
      seen: true,
      segments: const [
        StorySegmentModel(time: '9H AGO', tag: 'FIELD NOTE', caption: 'Found a perfect shadow. Left it there.'),
        StorySegmentModel(time: '8H AGO', tag: 'FIELD NOTE', caption: 'Came back. Still there.'),
      ],
    ),
  ];

  @override
  Future<List<StoryModel>> getStories() async {
    await Future<void>.delayed(_latency);
    return List.unmodifiable(_stories);
  }

  @override
  Future<void> markSeen(String userId) async {
    final index = _stories.indexWhere((s) => s.userId == userId);
    if (index == -1 || _stories[index].seen) return;
    final s = _stories[index];
    _stories[index] = StoryModel(
      userId: s.userId,
      name: s.name,
      avatarSeed: s.avatarSeed,
      segments: s.segments,
      seen: true,
    );
  }
}
