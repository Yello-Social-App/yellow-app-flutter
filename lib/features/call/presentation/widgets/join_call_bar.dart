import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/call_entity.dart';
import '../bloc/call_cubit.dart';
import '../bloc/conversation_call_cubit.dart';

/// "Join call · 3 in call" under a chat's header while the conversation has
/// a live call the viewer is not in on this device. Reads the page's
/// [ConversationCallCubit]; collapses to nothing otherwise.
///
/// While this device is already in that call it becomes "Return to call",
/// so the bar never offers a second join of the same call.
class JoinCallBar extends StatelessWidget {
  const JoinCallBar({super.key, required this.peerOf});

  /// How the call screen names the conversation, read at tap time.
  final CallPeer Function() peerOf;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConversationCallCubit, CallEntity?>(
      builder: (context, call) => BlocBuilder<CallCubit, CallState>(
        bloc: sl<CallCubit>(),
        buildWhen: (previous, current) => previous.call?.id != current.call?.id || previous.isLive != current.isLive,
        builder: (context, own) {
          // A DM's live call is the ring itself — nothing to join from here.
          if (call == null || !call.isGroup) return const SizedBox.shrink();
          final isHere = own.isLive && own.call?.id == call.id;
          return _Bar(
            joined: call.joinedCount,
            isVideo: call.isVideo,
            label: isHere ? 'Return' : 'Join',
            onTap: isHere ? sl<CallCubit>().expand : () => sl<CallCubit>().joinCall(call: call, peer: peerOf()),
          );
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.joined, required this.isVideo, required this.label, required this.onTap});

  final int joined;
  final bool isVideo;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: colors.yelb,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Icon(
                  isVideo ? CupertinoIcons.video_camera_solid : CupertinoIcons.phone_fill,
                  size: 18,
                  color: colors.yeld,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    joined == 1 ? 'Group call · 1 person in call' : 'Group call · $joined in call',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleSm.copyWith(color: colors.ink),
                  ),
                ),
                const SizedBox(width: 10),
                DecoratedBox(
                  decoration: BoxDecoration(color: colors.grn, borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(label, style: AppTextStyles.button.copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
