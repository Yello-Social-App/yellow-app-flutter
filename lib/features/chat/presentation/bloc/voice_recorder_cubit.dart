import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/audio/voice_recorder.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/attachment_entity.dart';
import '../../domain/usecases/chat_usecases.dart';

/// Bars in the recorder's radial meter. The circle is drawn from exactly
/// this many readings whichever state it is in — a rolling window of the
/// last [kVoiceRadialBars] while recording, the whole take resampled down to
/// it afterwards — so the ring never changes density under the eye.
const int kVoiceRadialBars = 60;

/// How often the meter and the clock update. Fast enough that the ring
/// reacts to a syllable, slow enough not to rebuild a 60-bar painter at
/// screen rate.
const Duration kVoiceTick = Duration(milliseconds: 80);

enum VoiceRecorderStatus {
  /// Before the first [VoiceRecorderCubit.start] — and where a re-record
  /// passes through.
  idle,

  /// The microphone was refused. Terminal: the sheet shows why and offers
  /// nothing but a way out, since only the OS settings can undo it.
  denied,
  recording,

  /// The take is finished and on disk: play it back, send it, or throw it
  /// away and record another.
  review,
  uploading,

  /// Uploaded. The sheet shows the check, then hands the attachment back.
  sent,
}

class VoiceRecorderState extends Equatable {
  const VoiceRecorderState({
    this.status = VoiceRecorderStatus.idle,
    this.elapsed = Duration.zero,
    this.levels = const [],
    this.previewPosition = Duration.zero,
    this.isPreviewPlaying = false,
    this.attachment,
    this.errorMessage,
  });

  final VoiceRecorderStatus status;

  /// How long the take runs. While recording this is the clock; in review it
  /// is the recording's length.
  final Duration elapsed;

  /// [kVoiceRadialBars] values, 0–1, ready to draw. Empty before the first
  /// reading lands.
  final List<double> levels;

  final Duration previewPosition;
  final bool isPreviewPlaying;

  /// The uploaded voice attachment, once [VoiceRecorderStatus.sent].
  final AttachmentEntity? attachment;

  /// A failed upload, or a recording too short to send. Shown in place of
  /// the status pill; the take is kept either way so Send can be tried
  /// again.
  final String? errorMessage;

  bool get isRecording => status == VoiceRecorderStatus.recording;
  bool get isReviewing => status == VoiceRecorderStatus.review;
  bool get isUploading => status == VoiceRecorderStatus.uploading;
  bool get isSent => status == VoiceRecorderStatus.sent;

  /// True once there is a take worth sending — the Send button's enabled
  /// state, and the reason a half-second mis-tap can't be sent at all.
  bool get canSend => isReviewing && elapsed >= voiceMinDuration;

  /// Time to show under the orb: the playhead while previewing, otherwise
  /// the length of the take.
  Duration get displayTime => isPreviewPlaying || previewPosition > Duration.zero ? previewPosition : elapsed;

  /// 0–1 through the preview, which splits the ring into played and unplayed.
  double get previewProgress {
    if (!isReviewing || elapsed.inMilliseconds <= 0) return 0;
    return (previewPosition.inMilliseconds / elapsed.inMilliseconds).clamp(0.0, 1.0);
  }

  VoiceRecorderState copyWith({
    VoiceRecorderStatus? status,
    Duration? elapsed,
    List<double>? levels,
    Duration? previewPosition,
    bool? isPreviewPlaying,
    AttachmentEntity? attachment,
    String? errorMessage,
  }) => VoiceRecorderState(
    status: status ?? this.status,
    elapsed: elapsed ?? this.elapsed,
    levels: levels ?? this.levels,
    previewPosition: previewPosition ?? this.previewPosition,
    isPreviewPlaying: isPreviewPlaying ?? this.isPreviewPlaying,
    attachment: attachment ?? this.attachment,
    // Deliberately not `?? this.errorMessage`: every transition clears the
    // last failure unless it sets a new one, so a stale "couldn't send" can
    // never sit over a fresh recording.
    errorMessage: errorMessage,
  );

  @override
  List<Object?> get props => [
    status,
    elapsed,
    levels,
    previewPosition,
    isPreviewPlaying,
    attachment,
    errorMessage,
  ];
}

/// Drives one voice note: record it, listen back, upload it.
///
/// It stops at the uploaded [AttachmentEntity] and does **not** send the
/// message — `ChatCubit.sendVoiceNote` does that, so a voice note goes out
/// through the same optimistic-bubble path as everything else instead of a
/// second delivery route that would have to learn about retries, reply
/// targets and the inbox preview all over again.
///
/// **Pause is a stop, and the red button records a new take rather than
/// resuming the old one.** The design it follows shows resume, but a paused
/// `MediaRecorder` has no readable file on Android — so a paused take could
/// not be played back, which is what its own "tap to preview" promises.
/// Finishing the take instead makes preview work always, at the cost of a
/// resume nobody asked for. See ADR-033.
class VoiceRecorderCubit extends Cubit<VoiceRecorderState> {
  VoiceRecorderCubit({
    required this.conversationId,
    required VoiceRecorder recorder,
    required UploadVoiceAttachmentUseCase upload,
    AudioPlayer? previewPlayer,
  }) : _recorder = recorder,
       _upload = upload,
       _preview = previewPlayer ?? AudioPlayer(),
       super(const VoiceRecorderState());

  final String conversationId;
  final VoiceRecorder _recorder;
  final UploadVoiceAttachmentUseCase _upload;
  final AudioPlayer _preview;

  /// The finished take. Null until [stop], and again after [discard].
  File? _take;

  Timer? _ticker;
  final Stopwatch _clock = Stopwatch();
  StreamSubscription<double>? _amplitudes;
  StreamSubscription<Duration>? _previewPositions;
  StreamSubscription<PlayerState>? _previewStates;

  /// Every reading of the take, in order. Kept whole so the review ring can
  /// be resampled from the real recording rather than from whatever happened
  /// to be in the rolling window when it stopped.
  final List<double> _takeLevels = [];

  /// The rolling window the recording ring draws, oldest first.
  final List<double> _window = List.filled(kVoiceRadialBars, _silence, growable: true);

  static const double _silence = 0.04;

  /// Asks for the microphone and starts recording.
  ///
  /// Called straight from the sheet's own `initState`: the design opens
  /// already recording, so the mic button is the whole interaction and
  /// there is no "press record" step once the sheet is up.
  Future<void> start() async {
    if (state.isRecording || state.isUploading) return;
    if (!await _recorder.hasPermission()) {
      if (!isClosed) emit(const VoiceRecorderState(status: VoiceRecorderStatus.denied));
      return;
    }

    await _stopPreview();
    _take = null;
    _takeLevels.clear();
    _window.fillRange(0, _window.length, _silence);

    try {
      await _recorder.start();
    } on Exception catch (e) {
      appLogger.w('VoiceRecorderCubit.start failed — $e');
      if (!isClosed) {
        emit(const VoiceRecorderState(errorMessage: "Couldn't start recording."));
      }
      return;
    }
    if (isClosed) return;

    _clock
      ..reset()
      ..start();
    _amplitudes = _recorder.amplitudes(interval: kVoiceTick).listen(_onAmplitude);
    _ticker = Timer.periodic(kVoiceTick, (_) => _onTick());
    emit(VoiceRecorderState(status: VoiceRecorderStatus.recording, levels: List.of(_window)));
  }

  /// Ends the take and moves to review. The 5:00 cap lands here too.
  Future<void> stop() async {
    if (!state.isRecording) return;
    await _endRecording();
    if (isClosed) return;

    final take = _take;
    if (take == null) {
      emit(const VoiceRecorderState(errorMessage: "That recording didn't save."));
      return;
    }
    emit(
      state.copyWith(
        status: VoiceRecorderStatus.review,
        levels: _resample(_takeLevels, kVoiceRadialBars),
        previewPosition: Duration.zero,
        isPreviewPlaying: false,
        errorMessage: state.elapsed < voiceMinDuration ? 'Too short — hold on a little longer.' : null,
      ),
    );
  }

  /// Throws the take away and records a new one — the red button in review.
  Future<void> recordAgain() async {
    await _stopPreview();
    await _recorder.discard();
    _take = null;
    if (isClosed) return;
    emit(const VoiceRecorderState());
    await start();
  }

  /// Plays the take back, or pauses it.
  Future<void> togglePreview() async {
    final take = _take;
    if (!state.isReviewing || take == null) return;

    if (_preview.playing) {
      await _preview.pause();
      return;
    }
    // A second listen after the first ran out starts from the top rather
    // than sitting at the end.
    if (_preview.processingState == ProcessingState.completed) await _preview.seek(Duration.zero);
    if (_preview.audioSource == null) {
      try {
        await _preview.setFilePath(take.path);
      } on Exception catch (e) {
        appLogger.w('VoiceRecorderCubit could not open the take — $e');
        if (!isClosed) emit(state.copyWith(errorMessage: "Couldn't play that back."));
        return;
      }
      if (isClosed) return;
      _previewPositions = _preview.positionStream.listen((position) {
        if (!isClosed && state.isReviewing) emit(state.copyWith(previewPosition: position));
      });
      _previewStates = _preview.playerStateStream.listen((playerState) {
        if (isClosed || !state.isReviewing) return;
        if (playerState.processingState == ProcessingState.completed) {
          emit(state.copyWith(isPreviewPlaying: false, previewPosition: Duration.zero));
        } else {
          emit(state.copyWith(isPreviewPlaying: playerState.playing));
        }
      });
    }
    unawaited(_preview.play());
  }

  /// Uploads the take. On success the state carries the attachment and the
  /// sheet hands it to `ChatCubit.sendVoiceNote`.
  ///
  /// A failure keeps the recording and the review state — the take is still
  /// on disk and Send can be pressed again, which is what the API's error
  /// table asks for on a 400 or a dropped connection.
  Future<void> send() async {
    final take = _take;
    if (take == null || state.isUploading) return;
    if (state.elapsed < voiceMinDuration) {
      emit(state.copyWith(errorMessage: 'Too short — hold on a little longer.'));
      return;
    }

    await _stopPreview();
    if (isClosed) return;
    emit(state.copyWith(status: VoiceRecorderStatus.uploading, isPreviewPlaying: false));

    final result = await _upload(UploadAttachmentParams(conversationId: conversationId, file: take));
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(status: VoiceRecorderStatus.review, errorMessage: failure.message)),
      (attachment) => emit(state.copyWith(status: VoiceRecorderStatus.sent, attachment: attachment)),
    );
  }

  /// Stops everything and deletes the file — the Discard button, and the
  /// close path when the sheet is dismissed any other way.
  Future<void> discard() async {
    await _endRecording();
    await _stopPreview();
    await _recorder.discard();
    _take = null;
  }

  @override
  Future<void> close() async {
    // A sheet closed mid-recording must not leave the mic open.
    await discard();
    await _preview.dispose();
    return super.close();
  }

  void _onAmplitude(double level) {
    if (!state.isRecording) return;
    _takeLevels.add(level);
    _window
      ..removeAt(0)
      ..add(level);
  }

  /// One place the clock and the ring are published, so they can never
  /// disagree about how far into the take they are.
  void _onTick() {
    if (isClosed || !state.isRecording) return;
    final elapsed = _clock.elapsed;
    if (elapsed >= voiceMaxDuration) {
      // The server refuses anything over five minutes, so the recorder
      // stops itself rather than letting the upload be the one to say no.
      emit(state.copyWith(elapsed: voiceMaxDuration, levels: List.of(_window)));
      unawaited(stop());
      return;
    }
    emit(state.copyWith(elapsed: elapsed, levels: List.of(_window)));
  }

  Future<void> _endRecording() async {
    _ticker?.cancel();
    _ticker = null;
    _clock.stop();
    await _amplitudes?.cancel();
    _amplitudes = null;
    if (_take != null) return;
    try {
      _take = await _recorder.stop();
    } on Exception catch (e) {
      appLogger.w('VoiceRecorderCubit.stop failed — $e');
      _take = null;
    }
  }

  Future<void> _stopPreview() async {
    await _previewPositions?.cancel();
    _previewPositions = null;
    await _previewStates?.cancel();
    _previewStates = null;
    if (_preview.playing) await _preview.stop();
  }
}

/// Squeezes a whole take down to [count] bars by taking the loudest reading
/// in each slice — a mean would average a recording's peaks away and leave a
/// flat ring that looks like nothing was said.
List<double> _resample(List<double> levels, int count) {
  if (levels.isEmpty) return List.filled(count, 0.05);
  final out = <double>[];
  for (var i = 0; i < count; i++) {
    final from = i * levels.length ~/ count;
    final to = ((i + 1) * levels.length ~/ count).clamp(from + 1, levels.length);
    var peak = 0.0;
    for (var j = from; j < to; j++) {
      if (levels[j] > peak) peak = levels[j];
    }
    out.add(peak);
  }
  return out;
}
