import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../utils/logger.dart';

/// Loudness, 0–1, of the last slice of audio the mic delivered.
///
/// `record` reports amplitude in **dBFS** — a negative number where 0 is
/// clipping and silence runs off towards -160 — which is not something a bar
/// height can use directly. [_floorDb] is where this app calls it silence:
/// quiet room noise sits around -50 dB, ordinary speech lands between -30 and
/// -10, so the window below keeps a normal voice in the upper half of the
/// bar rather than pinned to the floor.
const double _floorDb = -50;

/// Never report a completely flat bar: a recording in progress should look
/// alive even in a pause between words.
const double _minLevel = 0.05;

/// The one place the `record` plugin is touched.
///
/// It exists so [VoiceRecorderCubit] talks to something with four methods
/// and a stream instead of to a platform plugin — which also means the cubit
/// can be tested without a microphone.
///
/// Recordings are AAC-LC in an M4A container, mono: exactly what the voice
/// upload route lists for Flutter, so the server's transcode is a re-mux
/// rather than a decode. They are written to the system temp directory and
/// deleted on [discard] or once [stop]'s file has been uploaded — nothing
/// here is meant to survive the screen.
class VoiceRecorder {
  VoiceRecorder({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  /// The take in progress, or the last one [stop] handed back.
  File? _file;

  /// Whether the microphone is available *and* the user has said yes.
  ///
  /// `record` folds the permission request into this call, so on a first run
  /// it puts the system prompt up and answers once the user has decided.
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } on Exception catch (e) {
      appLogger.w('VoiceRecorder.hasPermission failed — $e');
      return false;
    }
  }

  /// Starts a new take, discarding any file left over from a previous one.
  Future<void> start() async {
    await _deleteFile();
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1, bitRate: 64000, sampleRate: 44100),
      path: path,
    );
    _file = File(path);
  }

  Future<void> pause() => _recorder.pause();

  Future<void> resume() => _recorder.resume();

  /// Ends the take and returns the file, or null if nothing was written.
  ///
  /// The caller owns the file from here: upload it, then [discard] to clean
  /// up. A stop with the recorder already stopped is a no-op, so this is safe
  /// to call from a dispose path that races the user's own Send.
  Future<File?> stop() async {
    final path = await _recorder.stop();
    if (path == null) return _file;
    final file = File(path);
    _file = file;
    return await file.exists() ? file : null;
  }

  /// Stops without keeping anything — the Discard button, and every exit
  /// path that isn't Send.
  Future<void> discard() async {
    try {
      await _recorder.cancel();
    } on Exception catch (e) {
      appLogger.w('VoiceRecorder.discard failed to cancel — $e');
    }
    await _deleteFile();
  }

  /// One reading every [interval]; the stream ends when recording stops.
  Stream<double> amplitudes({Duration interval = const Duration(milliseconds: 80)}) =>
      _recorder.onAmplitudeChanged(interval).map((amplitude) => _levelFromDb(amplitude.current));

  Future<void> dispose() async {
    await discard();
    await _recorder.dispose();
  }

  Future<void> _deleteFile() async {
    final file = _file;
    _file = null;
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (e) {
      // A leftover in the OS temp directory is the OS's problem, not a
      // reason to fail the discard the user asked for.
      appLogger.w('VoiceRecorder could not delete ${file.path} — $e');
    }
  }
}

/// dBFS → 0–1 against [_floorDb]. Infinity and NaN both read as silence:
/// some platforms report `-double.infinity` before the first buffer lands.
double _levelFromDb(double db) {
  if (db.isNaN || db.isInfinite) return _minLevel;
  final normalized = (db - _floorDb) / -_floorDb;
  return normalized.clamp(_minLevel, 1.0);
}
