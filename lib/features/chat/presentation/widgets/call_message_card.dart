import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/message_entity.dart';

/// A call, read back out of a message's text.
///
/// `yello-chat`'s `Message` has no call field (`docs/BACKEND.md`), yet call
/// notes do arrive in a thread as ordinary text messages — "Cancelled voice
/// call" — from a sender this app is not. The words are all there is to go
/// on, so this is a **reading of the text, not a fact from the wire**: a
/// person who types exactly "Missed voice call" gets the card too.
class CallMessage {
  const CallMessage({required this.isVideo, required this.isGroup, required this.connected, this.status});

  final bool isVideo;
  final bool isGroup;

  /// Somebody answered. False for a call that only rang: missed, cancelled,
  /// declined, busy or failed.
  final bool connected;

  /// What became of it — "Cancelled", "No answer", "1:05" — or null when the
  /// text says only that there was a call.
  final String? status;

  String get title {
    final kind = isVideo ? 'video' : 'voice';
    return isGroup ? 'Group $kind call' : '${kind[0].toUpperCase()}${kind.substring(1)} call';
  }
}

/// The whole text, and nothing but a call note: an optional lead ("Missed"),
/// the kind of call, an optional tail (" · 1:05"). Anchored at both ends so a
/// sentence that merely mentions a call stays a sentence.
final RegExp _callText = RegExp(
  r'^(?:(?<lead>missed|cancell?ed|declined|unanswered|incoming|outgoing|you (?:declined|missed) an?)\s+)?'
  r'(?<group>group\s+)?(?<media>voice|audio|video)\s+call'
  r'(?:\s*[·•:,–—-]?\s*(?<tail>ended|declined|cancell?ed|missed|failed|unanswered|no answer|line busy|busy|\d{1,2}(?::\d{2}){1,2}))?$',
  caseSensitive: false,
);

/// Longer than any call note, shorter than most sentences — checked before
/// the pattern so an ordinary message costs one comparison.
const int _callTextMaxLength = 48;

/// The call [message] is a note of, or null for every other message.
///
/// Only a bare text message qualifies. A quote, a file, a sticker or an edit
/// each mean a person wrote it.
CallMessage? callMessageOf(MessageEntity message) {
  if (message.isDeleted || message.isEdited || message.isInviteCard || message.isSticker) return null;
  if (message.hasAttachments || message.replyTo != null || message.isStoryReply) return null;
  final text = message.body.trim();
  if (text.isEmpty || text.length > _callTextMaxLength) return null;
  final match = _callText.firstMatch(text);
  if (match == null) return null;

  final lead = match.namedGroup('lead')?.toLowerCase();
  final tail = match.namedGroup('tail')?.toLowerCase();
  final leadRang = lead != null && lead != 'incoming' && lead != 'outgoing';
  final tailTalked = tail == null || tail == 'ended' || tail.contains(':');
  return CallMessage(
    isVideo: match.namedGroup('media')!.toLowerCase() == 'video',
    isGroup: match.namedGroup('group') != null,
    connected: !leadRang && tailTalked,
    // "Missed" outranks whatever follows it; otherwise the tail is the news.
    status: _statusLabel(leadRang ? lead : tail ?? lead),
  );
}

String? _statusLabel(String? word) => switch (word) {
  null => null,
  'cancelled' || 'canceled' => 'Cancelled',
  'unanswered' || 'no answer' => 'No answer',
  'busy' || 'line busy' => 'Line busy',
  final w when w.startsWith('you declined') => 'Declined',
  final w when w.startsWith('you missed') => 'Missed',
  // A talk time is shown as written; a single word gets its capital.
  final w => w.contains(':') ? w : '${w[0].toUpperCase()}${w.substring(1)}',
};

/// What a call note's bubble holds in place of its text: a round badge, the
/// kind of call, and what became of it.
///
/// Flat — no shadow (`docs/GOTCHAS.md`); red says the call never connected,
/// the same reading as `CallLogLine`.
class CallMessageCard extends StatelessWidget {
  const CallMessageCard({super.key, required this.call});

  final CallMessage call;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = call.connected ? colors.ink : colors.red;
    final IconData icon;
    if (!call.connected) {
      icon = CupertinoIcons.phone_down_fill;
    } else {
      icon = call.isVideo ? CupertinoIcons.video_camera_solid : CupertinoIcons.phone_fill;
    }
    final status = call.status;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 17, color: accent),
        ),
        const SizedBox(width: 10),
        // The words give way before the badge does on a narrow phone.
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                call.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMd.copyWith(color: colors.ink, fontWeight: FontWeight.w700),
              ),
              if (status != null) ...[
                const SizedBox(height: 3),
                Text(
                  status.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.metaMono.copyWith(color: call.connected ? colors.ink2 : colors.red),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
