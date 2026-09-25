import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/voice_note_player.dart';
import '../../../../core/audio/voice_recorder.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/attachment_entity.dart';
import '../../domain/usecases/chat_usecases.dart';
import '../bloc/voice_recorder_cubit.dart';

/// Opens the voice recorder over the conversation and returns the uploaded
/// attachment, or null if the user backed out.
///
/// The caller sends it: `ChatCubit.sendVoiceNote`. This route's job ends at
/// a `VOICE` attachment sitting on the server in its pending state.
///
/// A [PopupRoute] rather than a `showModalBottomSheet`, for the same reason
/// the reaction picker is one (ADR-031): the recorder is a full-bleed stage
/// with its own layout, not a sheet, and a popup route brings the barrier,
/// the back-button dismissal and a typed return value with it.
Future<AttachmentEntity?> showVoiceRecorder(
  BuildContext context, {
  required String conversationId,
  required String conversationName,
}) {
  // Nothing should be playing behind a recording — the mic would pick it up.
  sl<VoiceNotePlayer>().stop();
  return Navigator.of(context, rootNavigator: true).push<AttachmentEntity?>(
    _VoiceRecorderRoute(conversationId: conversationId, conversationName: conversationName),
  );
}

class _VoiceRecorderRoute extends PopupRoute<AttachmentEntity?> {
  _VoiceRecorderRoute({required this.conversationId, required this.conversationName});

  final String conversationId;
  final String conversationName;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => 'Voice message recorder';

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return BlocProvider(
      create: (_) => VoiceRecorderCubit(
        conversationId: conversationId,
        recorder: VoiceRecorder(),
        upload: sl<UploadVoiceAttachmentUseCase>(),
      )..start(),
      child: _VoiceRecorderStage(conversationName: conversationName),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(scale: Tween<double>(begin: 0.94, end: 1).animate(curved), child: child),
    );
  }
}

/// The stage itself: status line, meter, clock, controls.
class _VoiceRecorderStage extends StatelessWidget {
  const _VoiceRecorderStage({required this.conversationName});

  final String conversationName;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return BlocListener<VoiceRecorderCubit, VoiceRecorderState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        // The check lands, then the stage leaves with the attachment. Long
        // enough to read as "sent", short enough not to be a wait.
        if (state.isSent && state.attachment != null) {
          Future<void>.delayed(const Duration(milliseconds: 620), () {
            // `isCurrent` as well as `mounted`: the back gesture can start
            // this route leaving inside that pause, and a pop issued after
            // that one would take the conversation with it.
            if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
              Navigator.of(context).pop(state.attachment);
            }
          });
        }
      },
      child: Material(
        // The conversation stays visible underneath, well out of focus —
        // this is a stage over the chat, not a screen of its own.
        color: colors.bg.withValues(alpha: 0.94),
        child: SafeArea(
          child: BlocBuilder<VoiceRecorderCubit, VoiceRecorderState>(
            builder: (context, state) {
              final cubit = context.read<VoiceRecorderCubit>();
              if (state.status == VoiceRecorderStatus.denied) {
                return _MicDenied(onClose: () => Navigator.of(context).pop());
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatusPill(state: state, conversationName: conversationName),
                  const SizedBox(height: 22),
                  _Meter(state: state),
                  const SizedBox(height: 22),
                  _Clock(state: state),
                  const SizedBox(height: 28),
                  _Controls(state: state, cubit: cubit),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// "Recording to X" / "Ready to send" / "Sent to X" — and any error, which
/// takes the same slot rather than adding a line and moving everything else.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.state, required this.conversationName});

  final VoiceRecorderState state;
  final String conversationName;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final error = state.errorMessage;

    final (Color background, Color foreground, Widget? dot, String label) = switch (state) {
      _ when error != null => (colors.red.withValues(alpha: 0.12), colors.red, null, error),
      _ when state.isRecording => (
        colors.red.withValues(alpha: 0.12),
        colors.red,
        const _LiveDot(),
        'Recording to $conversationName',
      ),
      _ when state.isUploading => (colors.surf2, colors.ink2, null, 'Sending…'),
      _ when state.isSent => (colors.yelb, colors.yeld, null, 'Sent to $conversationName'),
      _ => (colors.surf2, colors.ink2, null, 'Tap to hear it back'),
    };

    return SizedBox(
      height: 30,
      child: Center(
        child: Container(
          padding: EdgeInsets.fromLTRB(dot == null ? 14 : 12, 6, 14, 6),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[dot, const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm.copyWith(color: foreground, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The blinking red dot beside "Recording". Opacity only — see
/// `docs/GOTCHAS.md` on animated decorations.
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.2).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: colors.red, shape: BoxShape.circle),
      ),
    );
  }
}

/// The 240px ring: bars around the outside, the orb in the middle.
class _Meter extends StatelessWidget {
  const _Meter({required this.state});

  final VoiceRecorderState state;

  static const double _size = 240;
  static const double _orbSize = 88;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<VoiceRecorderCubit>();
    final last = state.levels.isEmpty ? 0.0 : state.levels.last;

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // One painter for all 60 bars. Sixty rotated widgets rebuilding
          // twelve times a second is the version of this that drops frames.
          RepaintBoundary(
            child: CustomPaint(
              size: const Size.square(_size),
              painter: _RadialMeterPainter(
                levels: state.levels,
                progress: state.isReviewing ? state.previewProgress : null,
                active: colors.yel,
                idle: colors.line2,
                fading: state.isRecording,
              ),
            ),
          ),
          if (state.isRecording) const _Ripples(size: _orbSize),
          SizedBox.square(
            dimension: _orbSize,
            child: switch (state.status) {
              VoiceRecorderStatus.sent => _SentCheck(size: _orbSize),
              VoiceRecorderStatus.review => _PreviewButton(
                size: _orbSize,
                isPlaying: state.isPreviewPlaying,
                onTap: cubit.togglePreview,
              ),
              // Recording and uploading both show the mic. The orb swells
              // with the loudest part of the last slice, which is the only
              // motion in the middle of the ring.
              _ => _MicOrb(size: _orbSize, scale: state.isRecording ? 1 + last * 0.14 : 1),
            },
          ),
        ],
      ),
    );
  }
}

class _MicOrb extends StatelessWidget {
  const _MicOrb({required this.size, required this.scale});

  final double size;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: colors.yel, shape: BoxShape.circle),
        child: Icon(CupertinoIcons.mic, size: 34, color: colors.onYel),
      ),
    );
  }
}

class _PreviewButton extends StatelessWidget {
  const _PreviewButton({required this.size, required this.isPlaying, required this.onTap});

  final double size;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      label: isPlaying ? 'Pause preview' : 'Play preview',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surf,
            shape: BoxShape.circle,
            border: Border.all(color: colors.ink, width: 1.5),
          ),
          child: Icon(isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, size: 34, color: colors.ink),
        ),
      ),
    );
  }
}

class _SentCheck extends StatelessWidget {
  const _SentCheck({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.3, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(scale: value, child: child),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: colors.yel, shape: BoxShape.circle),
        child: Icon(CupertinoIcons.checkmark, size: 38, color: colors.onYel),
      ),
    );
  }
}

/// Three rings going out from the orb while recording, a third of a cycle
/// apart. Painted, not decorated — an animated blurred `BoxShadow` is this
/// project's documented crash (`docs/GOTCHAS.md`).
class _Ripples extends StatefulWidget {
  const _Ripples({required this.size});

  final double size;

  @override
  State<_Ripples> createState() => _RipplesState();
}

class _RipplesState extends State<_Ripples> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size * 2.4),
          painter: _RipplePainter(progress: _controller, color: colors.yel),
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.progress, required this.color}) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.width / 2 / 2.4;
    for (var ring = 0; ring < 3; ring++) {
      final t = (progress.value + ring / 3) % 1;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.45 * (1 - t));
      canvas.drawCircle(center, base * (1 + t * 1.3), paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) => oldDelegate.color != color;
}

/// The ring of level bars.
///
/// While recording it is a rolling window — oldest bar faded, newest at full
/// strength, so the ring reads as moving even when the level is steady. In
/// review it is the whole take, split at the playhead: everything before it
/// in the accent, everything after in the line colour.
class _RadialMeterPainter extends CustomPainter {
  _RadialMeterPainter({
    required this.levels,
    required this.progress,
    required this.active,
    required this.idle,
    required this.fading,
  });

  final List<double> levels;

  /// 0–1 playhead in review, null while recording.
  final double? progress;
  final Color active;
  final Color idle;

  /// Whether to fade the older end of the window.
  final bool fading;

  static const double _barWidth = 3;
  static const double _minBar = 4;
  static const double _maxBar = 30;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    final center = size.center(Offset.zero);
    // Bars stand on a circle just inside the box, growing outwards.
    final radius = size.width / 2 - _maxBar - 2;
    final paint = Paint()
      ..strokeWidth = _barWidth
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < levels.length; i++) {
      final angle = i * 2 * math.pi / levels.length - math.pi / 2;
      final length = _minBar + levels[i].clamp(0.0, 1.0) * _maxBar;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final from = center + direction * radius;
      final to = center + direction * (radius + length);

      final played = progress != null && i / levels.length < progress!;
      paint.color = switch (progress) {
        null => fading ? active.withValues(alpha: 0.2 + 0.8 * (i / (levels.length - 1))) : active,
        _ => played ? active : idle,
      };
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(_RadialMeterPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.active != active ||
      oldDelegate.idle != idle ||
      oldDelegate.fading != fading ||
      !listEquals(oldDelegate.levels, levels);
}

class _Clock extends StatelessWidget {
  const _Clock({required this.state});

  final VoiceRecorderState state;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final sub = switch (state.status) {
      VoiceRecorderStatus.recording => '/ ${formatVoiceDuration(voiceMaxDuration)}',
      VoiceRecorderStatus.review =>
        state.previewPosition > Duration.zero ? '/ ${formatVoiceDuration(state.elapsed)}' : 'recorded',
      VoiceRecorderStatus.uploading => 'sending',
      VoiceRecorderStatus.sent => 'sent',
      _ => '',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          formatVoiceDuration(state.displayTime),
          style: AppTextStyles.metaMono.copyWith(fontSize: 46, fontWeight: FontWeight.w600, color: colors.ink),
        ),
        const SizedBox(width: 8),
        Text(sub, style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3)),
      ],
    );
  }
}

/// Discard · stop-or-record-again · send.
class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.cubit});

  final VoiceRecorderState state;
  final VoiceRecorderCubit cubit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final busy = state.isUploading || state.isSent;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundButton(
          size: 52,
          icon: CupertinoIcons.delete,
          background: colors.surf,
          foreground: colors.ink2,
          border: colors.line,
          semanticLabel: 'Discard recording',
          onTap: busy
              ? null
              : () async {
                  await cubit.discard();
                  if (context.mounted) Navigator.of(context).pop();
                },
        ),
        const SizedBox(width: 28),
        if (state.isRecording)
          _RoundButton(
            size: 64,
            icon: CupertinoIcons.stop_fill,
            background: colors.surf,
            foreground: colors.ink,
            border: colors.ink,
            semanticLabel: 'Stop recording',
            onTap: cubit.stop,
          )
        else
          _RoundButton(
            size: 64,
            icon: CupertinoIcons.mic,
            background: colors.red,
            foreground: Colors.white,
            border: colors.red,
            semanticLabel: 'Record again',
            onTap: busy ? null : cubit.recordAgain,
          ),
        const SizedBox(width: 28),
        _RoundButton(
          size: 52,
          icon: CupertinoIcons.paperplane_fill,
          background: colors.yel,
          foreground: colors.onYel,
          border: colors.yel,
          semanticLabel: 'Send voice message',
          busy: state.isUploading,
          // Sending while still recording is the common case — one tap ends
          // the take and puts it on its way, rather than making Stop a step
          // the user has to know about.
          onTap: switch (state.status) {
            VoiceRecorderStatus.recording => () async {
              await cubit.stop();
              if (cubit.state.canSend) await cubit.send();
            },
            VoiceRecorderStatus.review when state.canSend => cubit.send,
            _ => null,
          },
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.size,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.border,
    required this.semanticLabel,
    required this.onTap,
    this.busy = false,
  });

  final double size;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color border;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: 1.5),
            ),
            child: busy
                ? SizedBox.square(
                    dimension: size * 0.36,
                    child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
                  )
                : Icon(icon, size: size * 0.38, color: foreground),
          ),
        ),
      ),
    );
  }
}

/// Terminal: only the OS settings can grant the microphone back, so this
/// says what happened and gets out of the way.
class _MicDenied extends StatelessWidget {
  const _MicDenied({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.mic_slash, size: 44, color: colors.ink3),
            const SizedBox(height: 16),
            Text(
              'Yello needs the microphone',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMd.copyWith(color: colors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Turn it on for Yello in your phone settings to send a voice message.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
            ),
            const SizedBox(height: 22),
            TextButton(onPressed: onClose, child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}
