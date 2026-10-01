import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/entities/call_log_entry.dart';
import '../bloc/call_cubit.dart' show formatCallDuration;

/// What a finished call's line says, from where the viewer stands.
String callLogLabel(CallLogEntry entry) {
  final call = entry.isVideo ? 'video call' : 'voice call';
  final title = entry.isVideo ? 'Video call' : 'Voice call';
  final talkTime = entry.talkTime;
  return switch (entry.endReason) {
    CallEndReason.hangup => talkTime == null ? '$title ended' : '$title · ${formatCallDuration(talkTime)}',
    // In a group DECLINED means everyone rung refused, so it is nobody's own.
    CallEndReason.declined when entry.isGroup || entry.isOutgoing => '$title declined',
    CallEndReason.declined => 'You declined a $call',
    CallEndReason.cancelled => entry.isOutgoing ? 'Cancelled $call' : 'Missed $call',
    CallEndReason.missed => entry.isOutgoing ? '$title · no answer' : 'Missed $call',
    CallEndReason.busy => '$title · line busy',
    CallEndReason.failed => '$title failed',
  };
}

/// A finished call in a chat thread: one centred line between the messages,
/// with the time it rang.
///
/// Not a bubble — nobody sent it, and nothing can be done to it. Flat on
/// purpose: colour says whether the call connected, no shadow
/// (`docs/GOTCHAS.md`).
class CallLogLine extends StatelessWidget {
  const CallLogLine({super.key, required this.entry, required this.time});

  final CallLogEntry entry;

  /// When it rang, already formatted the way the thread formats a message's.
  final String time;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final IconData icon;
    if (entry.wasUnanswered) {
      icon = CupertinoIcons.phone_down_fill;
    } else {
      icon = entry.isVideo ? CupertinoIcons.video_camera_solid : CupertinoIcons.phone_fill;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surf2,
            border: Border.all(color: colors.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: entry.wasUnanswered ? colors.red : colors.ink2),
                const SizedBox(width: 8),
                // The label gives way before the time does on a narrow phone.
                Flexible(
                  child: Text(
                    callLogLabel(entry),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySm.copyWith(color: colors.ink),
                  ),
                ),
                const SizedBox(width: 8),
                Text(time, style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
