import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart' show VideoTrack, VideoTrackRenderer, VideoViewFit;

import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../domain/entities/call_entity.dart';
import '../bloc/call_cubit.dart';
import 'call_widgets.dart';
import 'group_call_view.dart';

/// The full-screen call: who, what state it is in, and the controls that
/// state allows. Shown by `CallHost` above the whole app, white in light mode
/// and black in dark ([CallPalette]).
///
/// A group call, once joined, is [GroupCallView]'s tile grid; ringing,
/// ended and every 1:1 phase use the layout here.
class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = CallPalette.of(context);
    // Opaque, so nothing under the call can be tapped through it.
    return Material(
      color: palette.background,
      child: BlocBuilder<CallCubit, CallState>(
        builder: (context, state) {
          if (state.isGroup && (state.phase == CallPhase.active || state.phase == CallPhase.connecting)) {
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: palette.overlayStyle,
              child: GroupCallView(state: state),
            );
          }
          final remote = state.phase == CallPhase.active ? state.remoteVideo : null;
          // Their screen is drawn whole; a camera fills the screen.
          final remoteIsScreen = state.roomMembers.any((m) => !m.isLocal && m.screen != null);
          final local = state.phase == CallPhase.active && state.cameraEnabled ? state.localVideo : null;
          final chrome = SafeArea(
            child: Column(
              children: [
                _TopBar(state: state, overVideo: remote != null),
                Expanded(child: remote != null ? const SizedBox.shrink() : _Identity(state: state)),
                if (remote != null && state.notice != null) _Notice(state.notice!),
                if (state.screenSharing) const _Notice('You’re sharing your screen'),
                _Controls(state: state),
                const SizedBox(height: 28),
              ],
            ),
          );
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: remote != null ? SystemUiOverlayStyle.light : palette.overlayStyle,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (remote != null) ...[
                  ColoredBox(
                    color: Colors.black,
                    child: VideoTrackRenderer(
                      remote,
                      key: ValueKey(remote),
                      fit: remoteIsScreen ? VideoViewFit.contain : VideoViewFit.cover,
                    ),
                  ),
                  const _Scrim(),
                  OnVideoTheme(child: chrome),
                ] else
                  chrome,
                if (local != null)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 64,
                    right: 16,
                    child: _SelfView(track: local),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The call shrunk to a pill at the top of the app — tap it to come back.
class CallPill extends StatelessWidget {
  const CallPill({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CallCubit>();
    final palette = CallPalette.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Center(
          child: Material(
            color: palette.background,
            shape: StadiumBorder(side: BorderSide(color: palette.colors.line, width: 1.5)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: cubit.expand,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                child: BlocBuilder<CallCubit, CallState>(
                  builder: (context, state) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PeerAvatar(state: state, size: 30),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.peer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.titleSm.copyWith(color: palette.colors.ink),
                            ),
                            const SizedBox(height: 3),
                            _Status(
                              state: state,
                              style: AppTextStyles.metaMonoSm.copyWith(color: palette.colors.ink2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (state.phase == CallPhase.incoming) ...[
                        CallRoundAction(
                          color: palette.colors.red,
                          icon: CupertinoIcons.phone_down_fill,
                          size: 34,
                          semanticLabel: 'Decline',
                          onTap: cubit.decline,
                        ),
                        const SizedBox(width: 6),
                        CallRoundAction(
                          color: palette.colors.grn,
                          icon: CupertinoIcons.phone_fill,
                          size: 34,
                          semanticLabel: 'Accept',
                          onTap: cubit.accept,
                        ),
                      ] else if (state.isLive)
                        CallRoundAction(
                          color: palette.colors.red,
                          icon: CupertinoIcons.phone_down_fill,
                          size: 34,
                          semanticLabel: 'Hang up',
                          onTap: cubit.hangUp,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.overVideo});

  final CallState state;

  /// With the other person's video full screen, the name and status move up
  /// here from the middle of the screen.
  final bool overVideo;

  @override
  Widget build(BuildContext context) {
    final palette = CallPalette.of(context);
    final colors = palette.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          AppIconButton(
            icon: const Icon(CupertinoIcons.chevron_down),
            size: 40,
            backgroundColor: palette.raised,
            borderColor: colors.line,
            iconColor: colors.ink,
            onPressed: context.read<CallCubit>().minimize,
          ),
          Expanded(
            child: overVideo
                ? Column(
                    children: [
                      Text(
                        state.peer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleRow.copyWith(color: colors.ink),
                      ),
                      const SizedBox(height: 4),
                      _Status(
                        state: state,
                        style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
                      ),
                    ],
                  )
                : Text(
                    switch ((state.isGroup, state.isVideo)) {
                      (true, true) => 'YELLO GROUP VIDEO CALL',
                      (true, false) => 'YELLO GROUP CALL',
                      (false, true) => 'YELLO VIDEO CALL',
                      (false, false) => 'YELLO AUDIO CALL',
                    },
                    textAlign: TextAlign.center,
                    style: AppTextStyles.eyebrow.copyWith(color: colors.ink3),
                  ),
          ),
          // Balances the minimize button so the title centres on the screen.
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.state});

  final CallState state;

  @override
  Widget build(BuildContext context) {
    final colors = CallPalette.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PeerAvatar(state: state, size: 112),
          const SizedBox(height: 22),
          Text(
            state.peer.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLg.copyWith(color: colors.ink),
          ),
          const SizedBox(height: 10),
          if (state.phase == CallPhase.ended)
            Text(
              state.endMessage ?? 'Call ended',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd.copyWith(color: colors.ink2),
            )
          else
            _Status(
              state: state,
              style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
            ),
          if (state.notice != null) ...[const SizedBox(height: 18), _Notice(state.notice!)],
        ],
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  const _PeerAvatar({required this.state, required this.size});

  final CallState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final peer = state.peer;
    return AppAvatar(
      initials: peer.name.initials,
      seed: peer.avatarSeed,
      imageUrl: peer.avatarUrl,
      cacheKey: peer.avatarCacheKey,
      size: size,
      ringColor: CallPalette.of(context).colors.line,
    );
  }
}

/// One line saying where the call is — or, once someone else is in, how
/// long it has run.
class _Status extends StatelessWidget {
  const _Status({required this.state, required this.style});

  final CallState state;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final call = state.call;
    final answeredAt = call?.answeredAt;
    if (state.phase == CallPhase.active && state.peerJoined && !state.isReconnecting && answeredAt != null) {
      final timer = CallTimerText(since: answeredAt, style: style);
      if (!state.isGroup) return timer;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          timer,
          Text('  ·  ${call!.joinedCount} IN CALL', style: style),
        ],
      );
    }
    final ringing = call?.participants.where((p) => p.state == CallParticipantState.invited).length ?? 0;
    final caller = call == null ? null : state.members[call.initiatorId];
    final label = switch (state.phase) {
      CallPhase.outgoing when call == null => 'CALLING…',
      CallPhase.outgoing when state.isGroup && ringing > 0 => 'RINGING $ringing ${ringing == 1 ? 'PERSON' : 'PEOPLE'}…',
      CallPhase.outgoing => 'RINGING…',
      CallPhase.incoming when state.isGroup && caller != null =>
        '${caller.firstName.toUpperCase()} IS CALLING THE GROUP',
      CallPhase.incoming when state.isGroup => 'INCOMING GROUP CALL',
      CallPhase.incoming => state.isVideo ? 'INCOMING VIDEO CALL' : 'INCOMING CALL',
      CallPhase.connecting => 'CONNECTING…',
      CallPhase.active => state.isReconnecting ? 'RECONNECTING…' : 'CONNECTING…',
      CallPhase.interrupted => 'CALL IN PROGRESS',
      CallPhase.ended => (state.endMessage ?? 'Call ended').toUpperCase(),
      CallPhase.idle => '',
    };
    return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = CallPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(color: palette.raised, borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm.copyWith(color: palette.colors.ink),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state});

  final CallState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CallCubit>();
    final colors = CallPalette.of(context).colors;
    return SizedBox(
      // One height for every phase, so the identity block above does not
      // jump when the ringing buttons give way to the in-call ones.
      height: 190,
      child: switch (state.phase) {
        CallPhase.incoming => _AnswerRow(
          declineLabel: 'Decline',
          acceptLabel: 'Accept',
          acceptIcon: state.isVideo ? CupertinoIcons.video_camera_solid : CupertinoIcons.phone_fill,
          onDecline: cubit.decline,
          onAccept: cubit.accept,
        ),
        CallPhase.interrupted => _AnswerRow(
          declineLabel: state.isGroup ? 'Leave' : 'End',
          acceptLabel: 'Rejoin',
          acceptIcon: CupertinoIcons.phone_fill,
          onDecline: cubit.hangUp,
          onAccept: cubit.rejoin,
        ),
        CallPhase.ended || CallPhase.idle => const SizedBox.shrink(),
        CallPhase.outgoing || CallPhase.connecting || CallPhase.active => Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Toggle(
                  icon: state.speakerOn ? CupertinoIcons.speaker_3_fill : CupertinoIcons.speaker_1_fill,
                  label: 'Speaker',
                  isOn: state.speakerOn,
                  onTap: cubit.toggleSpeaker,
                ),
                _Toggle(
                  icon: CupertinoIcons.video_camera_solid,
                  label: 'Camera',
                  isOn: state.cameraEnabled,
                  onTap: cubit.toggleCamera,
                ),
                if (state.cameraEnabled)
                  _Toggle(
                    icon: CupertinoIcons.camera_rotate,
                    label: 'Flip',
                    isOn: false,
                    onTap: state.phase == CallPhase.active ? cubit.flipCamera : null,
                  ),
                _Toggle(
                  icon: state.micEnabled ? CupertinoIcons.mic_fill : CupertinoIcons.mic_slash_fill,
                  label: state.micEnabled ? 'Mute' : 'Unmute',
                  isOn: !state.micEnabled,
                  onTap: cubit.toggleMicrophone,
                ),
                if (cubit.canShareScreen && state.phase == CallPhase.active)
                  _Toggle(
                    icon: CupertinoIcons.rectangle_on_rectangle,
                    label: state.screenSharing ? 'Stop' : 'Share',
                    isOn: state.screenSharing,
                    onTap: cubit.toggleScreenShare,
                  ),
              ],
            ),
            const SizedBox(height: 30),
            CallRoundAction(
              color: colors.red,
              icon: CupertinoIcons.phone_down_fill,
              size: 70,
              semanticLabel: 'Hang up',
              onTap: cubit.hangUp,
            ),
          ],
        ),
      },
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    required this.declineLabel,
    required this.acceptLabel,
    required this.acceptIcon,
    required this.onDecline,
    required this.onAccept,
  });

  final String declineLabel;
  final String acceptLabel;
  final IconData acceptIcon;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final colors = CallPalette.of(context).colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _Labelled(
          label: declineLabel,
          child: CallRoundAction(color: colors.red, icon: CupertinoIcons.phone_down_fill, size: 70, onTap: onDecline),
        ),
        _Labelled(
          label: acceptLabel,
          child: CallRoundAction(color: colors.grn, icon: acceptIcon, size: 70, onTap: onAccept),
        ),
      ],
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 10),
        Text(label, style: AppTextStyles.metaMono.copyWith(color: CallPalette.of(context).colors.ink2)),
      ],
    );
  }
}

/// An on/off control: a solid disc when on, a soft one when off.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.label, required this.isOn, required this.onTap});

  final IconData icon;
  final String label;
  final bool isOn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = CallPalette.of(context);
    return _Labelled(
      label: label,
      child: Material(
        color: isOn ? palette.disc : palette.raised,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 56,
            child: Icon(icon, size: 24, color: isOn ? palette.onDisc : palette.colors.ink),
          ),
        ),
      ),
    );
  }
}

/// This phone's own camera, small in the corner.
class _SelfView extends StatelessWidget {
  const _SelfView({required this.track});

  final VideoTrack track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 104,
        height: 140,
        child: ColoredBox(
          color: CallPalette.of(context).raised,
          child: VideoTrackRenderer(track, key: ValueKey(track), fit: VideoViewFit.cover),
        ),
      ),
    );
  }
}

/// Darkens the top and bottom of full-screen video so the name and the
/// controls stay legible over a bright picture. A static gradient — no blur.
class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xB3000000)],
            stops: [0, 0.22, 0.6, 1],
          ),
        ),
      ),
    );
  }
}
