import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../utils/logger.dart';

/// The two sounds a call makes before anyone is connected: the callee's
/// ring and the caller's ringback. `yello-chat` rings over the socket and
/// leaves the sound to the app ("start your own ring sound"), so this is it.
///
/// Both are bundled WAVs (`tool/generate_call_tones.py`), one loop period
/// each, played on repeat until [stop].
///
/// The player is kept out of the app's audio session on purpose — no
/// activation, no interruption handling, no shared Android attributes. The
/// voice-note player owns that session, and WebRTC takes the audio route
/// over the moment the call connects; a tone that grabbed focus would fight
/// both. On Android the ring is played as a *ringtone* instead, which is what
/// makes it follow the phone's ringer: silent mode silences it, and the ring
/// volume, not the media volume, sets how loud it is.
class CallTones {
  CallTones({AudioPlayer Function()? createPlayer}) : _createPlayer = createPlayer ?? _defaultPlayer;

  static AudioPlayer _defaultPlayer() => AudioPlayer(
    handleInterruptions: false,
    handleAudioSessionActivation: false,
    androidApplyAudioAttributes: false,
  );

  static const String _ringtone = 'assets/sounds/call_ringtone.wav';
  static const String _ringback = 'assets/sounds/call_ringback.wav';

  /// A buzz alongside the ring, so a phone in a pocket is felt as well as
  /// heard. `HapticFeedback` follows the system's own vibration setting.
  static const Duration _buzzEvery = Duration(milliseconds: 1300);

  final AudioPlayer Function() _createPlayer;
  AudioPlayer? _player;
  Timer? _buzz;
  String? _playing;

  /// Bumped on every start and stop, so a slow asset load that finishes
  /// after [stop] does not start playing.
  int _generation = 0;

  /// The incoming-call ring.
  Future<void> ring() => _play(
    _ringtone,
    const AndroidAudioAttributes(
      contentType: AndroidAudioContentType.sonification,
      usage: AndroidAudioUsage.notificationRingtone,
    ),
    buzz: true,
  );

  /// What the caller hears while it rings on the other side.
  Future<void> ringback() => _play(
    _ringback,
    const AndroidAudioAttributes(
      contentType: AndroidAudioContentType.sonification,
      usage: AndroidAudioUsage.voiceCommunicationSignalling,
    ),
  );

  Future<void> stop() async {
    _generation++;
    _buzz?.cancel();
    _buzz = null;
    _playing = null;
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.dispose();
    } on Object catch (e) {
      appLogger.w('CallTones: stop failed — $e');
    }
  }

  Future<void> _play(String asset, AndroidAudioAttributes attributes, {bool buzz = false}) async {
    if (_playing == asset) return;
    await stop();
    final generation = ++_generation;
    _playing = asset;
    if (buzz) _buzz = Timer.periodic(_buzzEvery, (_) => HapticFeedback.vibrate());
    // A fresh player per tone: the Android attributes are fixed per audio
    // session, and the two tones want different ones.
    final player = _createPlayer();
    _player = player;
    try {
      await player.setAndroidAudioAttributes(attributes);
      await player.setAsset(asset);
      await player.setLoopMode(LoopMode.one);
      if (generation != _generation) return;
      // `play()` completes when playback stops, not when it starts.
      unawaited(player.play());
    } on Object catch (e) {
      appLogger.w('CallTones: could not play $asset — $e');
    }
  }
}
