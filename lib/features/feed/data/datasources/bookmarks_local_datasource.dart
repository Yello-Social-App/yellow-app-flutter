import 'package:shared_preferences/shared_preferences.dart';

/// "Save a post" has no backend endpoint on the live API — this persists
/// the saved-post-id set on-device via `shared_preferences` instead. Not
/// synced across devices; that's an accepted trade-off for a feature the
/// backend doesn't support yet, not a bug.
abstract interface class BookmarksLocalDataSource {
  Future<Set<String>> getSavedIds();
  Future<bool> toggle(String postId);
  Future<bool> isSaved(String postId);
}

class BookmarksLocalDataSourceImpl implements BookmarksLocalDataSource {
  static const _key = 'feed.saved_post_ids';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<Set<String>> getSavedIds() async {
    final prefs = await _prefs;
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  @override
  Future<bool> isSaved(String postId) async => (await getSavedIds()).contains(postId);

  @override
  Future<bool> toggle(String postId) async {
    final prefs = await _prefs;
    final ids = await getSavedIds();
    final nowSaved = !ids.contains(postId);
    nowSaved ? ids.add(postId) : ids.remove(postId);
    await prefs.setStringList(_key, ids.toList());
    return nowSaved;
  }
}
