import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/audio/voice_note_player.dart';
import '../../../../core/audio/voice_note_plays_store.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/attachment_entity.dart';

/// A voice note inside a message bubble: play button, waveform, length.
///
/// The waveform is the server's — `voice.waveform`, measured from the audio
/// on upload — so every device draws the same note the same way, and a
/// bubble needs no audio decoded locally to look right before it is played.
///
/// It watches [VoiceNotePlayer]'s single notifier rather than holding a
/// player of its own: only one note plays at a time, so all but one bubble
/// on screen are drawing a state that is not theirs, which is exactly what
/// [VoiceNotePlayback.isFor] decides.
///
/// A second notifier, [VoiceNotePlaysStore], says whether this note has ever
/// been listened to. An unheard one is drawn in the accent — yellow play
/// button under an ink ring, accent waveform, a dot after the length — the
/// same yellow-on-ink language the Inbox already uses for an unread row, so
/// "not listened to yet" reads the way "not read yet" does. A heard note
/// falls back to the quiet ink style, which is what a transcript is mostly
/// made of.
class VoiceNoteBubble extends StatelessWidget {
  const VoiceNoteBubble({super.key, required this.attachment, required this.onYellow, required this.onPlay});

  final AttachmentEntity attachment;

  /// On the sender's own (yellow) bubble the ink inverts, the same way text
  /// and the file chip already do.
  final bool onYellow;

  /// Asks the page to play this note. It lives there because playing may
  /// first need a fresh presigned link, which is a cubit's call to make —
  /// see `ChatCubit.playableVoiceUrl`.
  final ValueChanged<AttachmentEntity> onPlay;

  static const double _waveWidth = 110;
  static const double _waveHeight = 26;
  static const double _buttonSize = 34;
  static const double _newDotSize = 7;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final voice = attachment.voice;
    if (voice == null) return const SizedBox.shrink();

    final ink = onYellow ? colors.onYel : colors.ink;
    final dim = onYellow ? colors.onYel.withValues(alpha: 0.35) : colors.line2;
    final player = sl<VoiceNotePlayer>();
    final plays = sl<VoiceNotePlaysStore>();

    return ValueListenableBuilder<Set<String>?>(
      valueListenable: plays.heard,
      builder: (context, heardIds, _) {
        // Only a note someone sent *me* can be unheard: my own note is one I
        // recorded, and whether the other side has played it is a fact the
        // chat API does not report — so a yellow bubble is always drawn quiet.
        final unheard = !onYellow && !(heardIds?.contains(attachment.id) ?? true);

        return ValueListenableBuilder<VoiceNotePlayback>(
          valueListenable: player.playback,
          builder: (context, playback, _) {
            final isMine = playback.isFor(attachment.id);
            final isPlaying = isMine && playback.isPlaying;
            final progress = playback.progressFor(attachment.id, voice.duration);
            // Counts down while playing — what is left to listen to is the
            // useful number mid-note; the full length is the useful one at rest.
            final label = isMine && playback.position > Duration.zero
                ? formatVoiceDuration(voice.duration - playback.position)
                : voice.durationLabel;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  button: true,
                  label: isPlaying
                      ? 'Pause voice message'
                      : unheard
                      ? 'Play voice message, not listened to yet'
                      : 'Play voice message',
                  child: GestureDetector(
                    onTap: () => onPlay(attachment),
                    child: Container(
                      width: _buttonSize,
                      height: _buttonSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: unheard ? colors.yel : (onYellow ? colors.onYel : colors.ink),
                        shape: BoxShape.circle,
                        // The ink ring is what stops the yellow disc from
                        // dissolving into a light surface — the same ring the
                        // Inbox's unread badge wears, for the same reason.
                        border: unheard ? Border.all(color: colors.ink, width: 1.5) : null,
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 18,
                        color: unheard ? colors.onYel : (onYellow ? colors.yel : colors.bg),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Flexible, and the one thing in the row that is: everything
                // else is a fixed size, and on a 320pt phone an incoming
                // bubble has less room than the 110pt bar wants. Loose fit
                // means it draws at its full width wherever there is room
                // and gives ground only where there isn't — `_WaveformPainter`
                // resamples to whatever it gets, so a narrower bar is fewer
                // bars, not a clipped one.
                Flexible(
                  child: Builder(
                    builder: (waveContext) => GestureDetector(
                      // Scrubbing: the bar is the note's timeline, so a tap
                      // part-way along it jumps there — but only for the note
                      // that is loaded, since seeking one that isn't playing
                      // has nothing to seek.
                      onTapDown: isMine
                          ? (details) {
                              // The painted width, not `_waveWidth`: on a
                              // narrow bubble they differ, and the fraction
                              // has to be of what was actually drawn.
                              final box = waveContext.findRenderObject() as RenderBox?;
                              final width = box?.size.width ?? _waveWidth;
                              final fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
                              player.seek(attachment.id, voice.duration * fraction);
                            }
                          : null,
                      child: CustomPaint(
                        size: const Size(_waveWidth, _waveHeight),
                        painter: _WaveformPainter(
                          waveform: voice.waveform,
                          progress: isMine ? progress : 0,
                          played: ink,
                          // An unheard note has no played part yet, so this
                          // one color carries the whole waveform: `yeld`
                          // rather than `yel`, because the flat yellow is a
                          // fill and does not hold its own as 3px strokes on
                          // a white card.
                          unplayed: unheard ? colors.yeld : dim,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: AppTextStyles.metaMonoSm.copyWith(
                    color: unheard ? colors.ink : (onYellow ? colors.onYel : colors.ink2),
                    fontWeight: unheard ? FontWeight.w700 : null,
                  ),
                ),
                // The dot's box is held even once the note is heard, so a
                // bubble does not change width the instant it is played.
                const SizedBox(width: 6),
                SizedBox(
                  width: _newDotSize,
                  height: _newDotSize,
                  child: unheard
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.yel,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.ink),
                          ),
                        )
                      : null,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The bars. Each of the server's 0–100 values is one bar, resampled to
/// whatever number fits the width so a 64-value waveform and a 12-value one
/// both fill the same space.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.waveform, required this.progress, required this.played, required this.unplayed});

  final List<int> waveform;
  final double progress;
  final Color played;
  final Color unplayed;

  static const double _barWidth = 3;
  static const double _gap = 2;
  static const double _minHeight = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final count = ((size.width + _gap) / (_barWidth + _gap)).floor();
    if (count <= 0) return;
    final paint = Paint()
      ..strokeWidth = _barWidth
      ..strokeCap = StrokeCap.round;
    final middle = size.height / 2;

    for (var i = 0; i < count; i++) {
      final level = _levelAt(i, count);
      final height = (_minHeight + level * (size.height - _minHeight)).clamp(_minHeight, size.height);
      final x = i * (_barWidth + _gap) + _barWidth / 2;
      paint.color = (i + 0.5) / count <= progress ? played : unplayed;
      canvas.drawLine(Offset(x, middle - height / 2), Offset(x, middle + height / 2), paint);
    }
  }

  /// The loudest sample in this bar's slice, 0–1. A quiet note still shows
  /// something: an all-zero waveform, or none at all, draws a flat rail
  /// rather than nothing.
  double _levelAt(int index, int count) {
    if (waveform.isEmpty) return 0.18;
    final from = index * waveform.length ~/ count;
    final to = ((index + 1) * waveform.length ~/ count).clamp(from + 1, waveform.length);
    var peak = 0;
    for (var i = from; i < to; i++) {
      if (waveform[i] > peak) peak = waveform[i];
    }
    return (peak / 100).clamp(0.12, 1.0);
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.played != played ||
      oldDelegate.unplayed != unplayed ||
      !listEquals(oldDelegate.waveform, waveform);
}
