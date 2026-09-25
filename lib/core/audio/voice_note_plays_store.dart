import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';

/// Which voice notes this device has already listened to.
///
/// `yello-chat` has no per-attachment "played" flag — a message carries read
/// receipts, not playback state — so "heard" is a **local** fact, the same
/// shape as saved posts: it lives in `shared_preferences`, it is this
/// device's alone, and it does not follow the account to another phone. That
/// is a deliberate stand-in for a contract the API does not offer, not a
/// placeholder waiting to be wired up.
///
/// It is a [ValueNotifier] for the same reason [VoiceNotePlayer] is: every
/// voice bubble in the transcript watches one notifier and decides for
/// itself, instead of the page rebuilding a list to repaint one waveform.
class VoiceNotePlaysStore {
  static const _key = 'chat.heard_voice_note_ids';

  /// How many ids are kept. Oldest first, so the trim drops the notes least
  /// likely to still be on screen anywhere. A transcript scrolled far enough
  /// back to fall off this list shows its notes as heard, which is the safe
  /// wrong answer — an old note re-flagged as new is the loud one.
  static const _limit = 600;

  /// Insertion-ordered, which is what makes the trim above meaningful;
  /// [heard] hands out the set the bubbles actually ask questions of.
  final List<String> _order = [];

  /// Null until [restore] has finished — "not known yet", not "none heard".
  /// A bubble treats unknown as heard so a cold start never flashes the
  /// unheard accent across a transcript of notes the user listened to
  /// yesterday.
  final ValueNotifier<Set<String>?> heard = ValueNotifier(null);

  bool isHeard(String noteId) => heard.value?.contains(noteId) ?? true;

  /// Reads the stored ids. Called once from DI registration; safe to call
  /// again, though nothing does.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _order
        ..clear()
        ..addAll(prefs.getStringList(_key) ?? const []);
      heard.value = Set.unmodifiable(_order);
    } on Exception catch (e) {
      // A device that cannot read prefs still plays voice notes; it just
      // never marks one heard. Leaving the notifier null keeps every bubble
      // in the quiet style rather than marking them all new.
      appLogger.w('VoiceNotePlaysStore could not restore — $e');
    }
  }

  /// Marks a note listened to, at the moment playback starts — the same
  /// point every other messenger drops its "new" marker, and the only one
  /// that does not depend on the user staying until the end of the note.
  ///
  /// The notifier updates first and the write follows: the waveform should
  /// not wait on disk to stop looking new.
  Future<void> markHeard(String noteId) async {
    if (_order.contains(noteId)) return;
    _order.add(noteId);
    if (_order.length > _limit) _order.removeRange(0, _order.length - _limit);
    heard.value = Set.unmodifiable(_order);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _order);
    } on Exception catch (e) {
      appLogger.w('VoiceNotePlaysStore could not persist $noteId — $e');
    }
  }

  void dispose() => heard.dispose();
}
