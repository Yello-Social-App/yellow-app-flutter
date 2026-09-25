import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../utils/logger.dart';

/// What the one shared player is doing, for whichever bubble cares.
///
/// [noteId] is the only thing a bubble compares itself against: every voice
/// bubble in the transcript watches the same notifier, and all but one of
/// them are looking at a state that isn't theirs.
@immutable
class VoiceNotePlayback {
  const VoiceNotePlayback({this.noteId, this.isPlaying = false, this.position = Duration.zero, this.total});

  static const VoiceNotePlayback idle = VoiceNotePlayback();

  /// The attachment id being played, or null when nothing is loaded.
  final String? noteId;
  final bool isPlaying;
  final Duration position;

  /// The player's own measurement, which only arrives once the stream has
  /// been opened — until then a bubble shows the server's `durationMs`.
  final Duration? total;

  bool isFor(String id) => noteId == id;

  /// 0–1 through the note, for the played/unplayed split in the waveform.
  double progressFor(String id, Duration fallbackTotal) {
    if (!isFor(id)) return 0;
    final length = (total ?? fallbackTotal).inMilliseconds;
    if (length <= 0) return 0;
    return (position.inMilliseconds / length).clamp(0.0, 1.0);
  }

  VoiceNotePlayback copyWith({String? noteId, bool? isPlaying, Duration? position, Duration? total}) =>
      VoiceNotePlayback(
        noteId: noteId ?? this.noteId,
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        total: total ?? this.total,
      );
}

/// One `just_audio` player for the whole app, so one voice note plays at a
/// time — starting a second one stops the first, which is what the API's own
/// client checklist asks for and what every other messenger does.
///
/// A singleton rather than a player per bubble for the same reason: a
/// transcript can hold hundreds of voice notes, and each `AudioPlayer` is a
/// real platform player with its own buffers.
///
/// It takes a **presigned URL**, never an attachment: links expire after an
/// hour (`urlExpiresAt`) and it is the caller's job to have a live one — see
/// `ChatCubit.playableVoiceUrl`, which refreshes through
/// `GET /ws/attachments/{id}` before it gets here.
class VoiceNotePlayer {
  VoiceNotePlayer({AudioPlayer Function()? createPlayer}) : _createPlayer = createPlayer ?? AudioPlayer.new;

  final AudioPlayer Function() _createPlayer;

  /// Built on the first play, not in the constructor: this is a DI
  /// singleton, so a session that never opens a voice note never opens an
  /// audio session — and a widget test that happens to construct one never
  /// reaches for a platform channel that isn't there.
  AudioPlayer? _playerOrNull;
  StreamSubscription<Duration>? _positions;
  StreamSubscription<PlayerState>? _states;

  AudioPlayer get _player => _playerOrNull ??= _listenTo(_createPlayer());

  AudioPlayer _listenTo(AudioPlayer player) {
    _positions = player.positionStream.listen((position) {
      if (playback.value.noteId != null) playback.value = playback.value.copyWith(position: position);
    });
    _states = player.playerStateStream.listen((state) {
      final current = playback.value;
      if (current.noteId == null) return;
      if (state.processingState == ProcessingState.completed) {
        // Rewind rather than leave the bar full: the next tap should play
        // the note again, not sit at the end doing nothing.
        unawaited(player.pause());
        unawaited(player.seek(Duration.zero));
        playback.value = current.copyWith(isPlaying: false, position: Duration.zero);
        return;
      }
      playback.value = current.copyWith(isPlaying: state.playing);
    });
    return player;
  }

  /// Watched by every voice bubble on screen.
  final ValueNotifier<VoiceNotePlayback> playback = ValueNotifier(VoiceNotePlayback.idle);

  /// Plays [noteId] from [url], or pauses/resumes it when it is already the
  /// loaded one. Returns false when the source could not be opened at all —
  /// an expired link the caller did not refresh, or a note the server has
  /// since deleted.
  Future<bool> toggle({required String noteId, required String url}) async {
    if (playback.value.isFor(noteId)) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return true;
    }

    // A different note: whatever was playing stops here, before the new
    // source is set, so two notes never overlap even briefly.
    await _player.stop();
    playback.value = VoiceNotePlayback(noteId: noteId);
    try {
      final total = await _player.setUrl(url);
      playback.value = playback.value.copyWith(total: total);
      // `play()` completes when playback *finishes*, so it is deliberately
      // not awaited — awaiting it would hold this call open for the length
      // of the note.
      unawaited(_player.play());
      return true;
    } on Exception catch (e) {
      appLogger.w('VoiceNotePlayer could not open $noteId — $e');
      playback.value = VoiceNotePlayback.idle;
      return false;
    }
  }

  /// Jumps within the loaded note — the waveform is a scrubber.
  Future<void> seek(String noteId, Duration position) async {
    if (!playback.value.isFor(noteId)) return;
    await _player.seek(position);
  }

  Future<void> stop() async {
    // Nothing loaded means nothing to stop — and, on a cold player, nothing
    // worth constructing one for.
    if (playback.value.noteId == null) return;
    await _player.stop();
    playback.value = VoiceNotePlayback.idle;
  }

  /// Stops if what is playing is one of [noteIds] — a note whose message was
  /// just deleted or unsent, which the API's checklist asks to interrupt
  /// rather than let play on out of a bubble that is no longer there.
  Future<void> stopIfPlayingAnyOf(Iterable<String> noteIds) async {
    final current = playback.value.noteId;
    if (current != null && noteIds.contains(current)) await stop();
  }

  Future<void> dispose() async {
    await _positions?.cancel();
    await _states?.cancel();
    await _playerOrNull?.dispose();
    _playerOrNull = null;
    playback.dispose();
  }
}
