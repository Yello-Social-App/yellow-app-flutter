import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart'
    show VideoTrack, VideoTrackRenderer, VideoViewFit;

import '../../../../core/call/call_room.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../chat/presentation/bloc/messages_cubit.dart';
import '../../domain/entities/call_entity.dart';
import '../bloc/call_cubit.dart';
import 'call_widgets.dart';

/// A group call once it is joined (or joining): a title bar, everyone as a
/// tile in a paged two-column grid, a screen share shown large above them,
/// and a control tray at the bottom. White in light mode, black in dark
/// ([CallPalette]).
///
/// Tiles come from the LiveKit room — who is connected to the media right
/// now — plus a dimmed tile for everyone the server still lists as being
/// rung. Names and avatars come from the conversation (`CallState.members`);
/// neither the call nor the room carries them.
class GroupCallView extends StatelessWidget {
  const GroupCallView({super.key, required this.state});

  final CallState state;

  @override
  Widget build(BuildContext context) {
    final p = CallPalette.of(context);
    final sharing = state.sharing;
    return SafeArea(
      child: Column(
        children: [
          _TitleBar(state: state),
          const SizedBox(height: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: sharing == null
                  ? _TileGrid(tiles: _tilesOf(state))
                  : Column(
                      children: [
                        Expanded(
                          child: _ScreenStage(
                            member: sharing,
                            name: _nameOf(state, sharing),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 132,
                          child: _TileStrip(tiles: _tilesOf(state)),
                        ),
                      ],
                    ),
            ),
          ),
          if (state.notice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Text(
                state.notice!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(color: p.colors.ink),
              ),
            ),
          const SizedBox(height: 14),
          _ControlTray(state: state),
        ],
      ),
    );
  }
}

/// One tile's worth of person: connected ([member] set) or still being rung.
class _Tile {
  const _Tile({
    required this.id,
    required this.peer,
    this.member,
    this.isRinging = false,
  });

  final String id;
  final CallPeer peer;
  final CallRoomMember? member;
  final bool isRinging;
}

List<_Tile> _tilesOf(CallState state) {
  final inRoom = <String>{};
  final tiles = <_Tile>[];
  for (final member in state.roomMembers) {
    inRoom.add(member.identity);
    tiles.add(
      _Tile(
        id: member.identity,
        member: member,
        peer: member.isLocal
            ? _you(state, member.identity)
            : _peerOf(state, member.identity, member.name),
      ),
    );
  }
  // Before the room is joined, still show the viewer where they will be.
  if (tiles.isEmpty) tiles.add(_Tile(id: '', peer: _you(state, '')));
  for (final p in state.call?.participants ?? const <CallParticipant>[]) {
    if (p.state != CallParticipantState.invited || inRoom.contains(p.userId))
      continue;
    tiles.add(
      _Tile(id: p.userId, peer: _peerOf(state, p.userId, ''), isRinging: true),
    );
  }
  return tiles;
}

CallPeer _you(CallState state, String identity) {
  final me = state.members[identity];
  return CallPeer(
    name: 'You',
    avatarSeed: me?.avatarSeed ?? 0,
    avatarUrl: me?.avatarUrl,
  );
}

CallPeer _peerOf(CallState state, String userId, String fallbackName) =>
    state.members[userId] ??
    CallPeer(
      name: fallbackName.isNotEmpty ? fallbackName : 'Member',
      avatarSeed: userId.hashCode.abs(),
    );

String _nameOf(CallState state, CallRoomMember member) => member.isLocal
    ? 'Your screen'
    : '${_peerOf(state, member.identity, member.name).firstName}’s screen';

// -----------------------------------------------------------------------------
// Title bar
// -----------------------------------------------------------------------------

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.state});

  final CallState state;

  @override
  Widget build(BuildContext context) {
    final p = CallPalette.of(context);
    final cubit = context.read<CallCubit>();
    final answeredAt = state.call?.answeredAt;
    final joined = state.call?.joinedCount ?? 0;
    final metaStyle = AppTextStyles.metaMono.copyWith(color: p.colors.ink2);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          _LightCircle(
            icon: CupertinoIcons.arrow_left,
            semanticLabel: 'Minimize',
            onTap: cubit.minimize,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Text(
                    state.peer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleRow.copyWith(
                      color: p.colors.ink,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.phase == CallPhase.active &&
                          !state.isReconnecting &&
                          answeredAt != null)
                        CallTimerText(since: answeredAt, style: metaStyle)
                      else
                        Text(
                          state.isReconnecting
                              ? 'RECONNECTING…'
                              : 'CONNECTING…',
                          style: metaStyle,
                        ),
                      if (joined > 0)
                        Text('  ·  $joined IN CALL', style: metaStyle),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _ChatButton(conversationId: state.call?.conversationId),
        ],
      ),
    );
  }
}

/// A bare top-bar button — just the icon in the theme's ink, no disc behind
/// it; the ink ripple still marks the circular tap target.
class _LightCircle extends StatelessWidget {
  const _LightCircle({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = CallPalette.of(context);
    return CallRoundAction(
      color: Colors.transparent,
      iconColor: p.colors.ink,
      icon: icon,
      size: 48,
      semanticLabel: semanticLabel,
      onTap: onTap,
    );
  }
}

/// Opens the group's chat under the minimized call, with its unread count.
class _ChatButton extends StatelessWidget {
  const _ChatButton({required this.conversationId});

  final String? conversationId;

  @override
  Widget build(BuildContext context) {
    final p = CallPalette.of(context);
    final id = conversationId;
    return BlocSelector<MessagesCubit, MessagesState, int>(
      bloc: sl<MessagesCubit>(),
      selector: (state) =>
          state.conversations
              .where((c) => c.id == id)
              .firstOrNull
              ?.unreadCount ??
          0,
      builder: (context, unread) => Stack(
        clipBehavior: Clip.none,
        children: [
          _LightCircle(
            icon: CupertinoIcons.chat_bubble_2,
            semanticLabel: 'Open chat',
            onTap: id == null || id.isEmpty
                ? null
                : () => _openChat(context, id),
          ),
          if (unread > 0)
            Positioned(
              top: -2,
              left: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.colors.yel,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: AppTextStyles.metaMonoSm.copyWith(
                    color: p.colors.onYel,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The call sits above the router, so it navigates through the router
  /// itself — and does not stack a second copy of a chat already on top.
  void _openChat(BuildContext context, String id) {
    context.read<CallCubit>().minimize();
    final router = sl<AppRouter>().router;
    if (router.routerDelegate.currentConfiguration.uri.path == '/chat/$id')
      return;
    router.pushNamed(RouteNames.chat, pathParameters: {'conversationId': id});
  }
}

// -----------------------------------------------------------------------------
// Tiles
// -----------------------------------------------------------------------------

/// Pages of up to six tiles, two columns; a chevron at the edge when there is
/// another page.
class _TileGrid extends StatefulWidget {
  const _TileGrid({required this.tiles});

  final List<_Tile> tiles;

  @override
  State<_TileGrid> createState() => _TileGridState();
}

class _TileGridState extends State<_TileGrid> {
  static const int _perPage = 6;
  final PageController _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) => _pages.animateToPage(
    page,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final tiles = widget.tiles;
    final pageCount = math.max(1, (tiles.length / _perPage).ceil());
    final page = math.min(_page, pageCount - 1);
    return Stack(
      children: [
        PageView.builder(
          controller: _pages,
          itemCount: pageCount,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => _TilePage(
            tiles: tiles.skip(i * _perPage).take(_perPage).toList(),
            fillsPage: tiles.length > 2,
          ),
        ),
        if (page > 0)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _PageChevron(
              icon: CupertinoIcons.chevron_left,
              onTap: () => _go(page - 1),
            ),
          ),
        if (page < pageCount - 1)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _PageChevron(
              icon: CupertinoIcons.chevron_right,
              onTap: () => _go(page + 1),
            ),
          ),
      ],
    );
  }
}

class _PageChevron extends StatelessWidget {
  const _PageChevron({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = CallPalette.of(context);
    // No `tooltip:` — nothing above the router has an Overlay to show one in.
    return Center(
      child: Semantics(
        label: icon == CupertinoIcons.chevron_right
            ? 'Next page'
            : 'Previous page',
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: p.colors.ink, size: 28),
        ),
      ),
    );
  }
}

/// One page: one column for one or two people, two columns beyond that, rows
/// sharing the height — so a page of six looks like the reference, and a
/// page of two still fills the screen.
class _TilePage extends StatelessWidget {
  const _TilePage({required this.tiles, required this.fillsPage});

  final List<_Tile> tiles;

  /// More than two people in the call: every page keeps the three-row
  /// rhythm, so a last page of one tile is not stretched to the full screen.
  final bool fillsPage;

  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    final columns = tiles.length <= 2 && !fillsPage ? 1 : 2;
    final rows = fillsPage ? 3 : math.max(1, (tiles.length / columns).ceil());
    return Column(
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: _gap),
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: _gap),
                  Expanded(
                    child: r * columns + c < tiles.length
                        ? _TileView(
                            tile: tiles[r * columns + c],
                            key: ValueKey(tiles[r * columns + c].id),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// While a screen is shared: everyone as a row of small tiles under it.
class _TileStrip extends StatelessWidget {
  const _TileStrip({required this.tiles});

  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: tiles.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, i) => SizedBox(
        width: 100,
        child: _TileView(
          tile: tiles[i],
          compact: true,
          key: ValueKey(tiles[i].id),
        ),
      ),
    );
  }
}

class _TileView extends StatelessWidget {
  const _TileView({super.key, required this.tile, this.compact = false});

  final _Tile tile;
  final bool compact;

  static const double _radius = 22;

  @override
  Widget build(BuildContext context) {
    final p = CallPalette.of(context);
    final member = tile.member;
    final camera = member?.camera;
    final speaking = member?.isSpeaking ?? false;
    return Opacity(
      opacity: tile.isRinging ? 0.55 : 1,
      child: DecoratedBox(
        // A colour change for "speaking" — no blurred glow (docs/GOTCHAS.md).
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: speaking ? p.colors.yel : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: ColoredBox(
            color: p.raised,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (camera != null)
                  VideoTrackRenderer(
                    camera,
                    key: ValueKey(camera),
                    fit: VideoViewFit.cover,
                  )
                else
                  _AvatarFace(peer: tile.peer, compact: compact),
                if (!compact)
                  Positioned(left: 10, top: 10, child: _MicBadge(tile: tile)),
                Positioned(
                  left: compact ? 6 : 10,
                  right: compact ? 6 : 10,
                  bottom: compact ? 6 : 10,
                  child: _NameChip(
                    label: tile.isRinging
                        ? '${tile.peer.firstName} · ringing'
                        : tile.peer.name,
                    compact: compact,
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

class _AvatarFace extends StatelessWidget {
  const _AvatarFace({required this.peer, required this.compact});

  final CallPeer peer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = CallPalette.of(context);
    return Center(
      child: AppAvatar(
        initials: peer.name.initials,
        seed: peer.avatarSeed,
        imageUrl: peer.avatarUrl,
        cacheKey: peer.avatarCacheKey,
        size: compact ? 44 : 72,
        ringColor: p.colors.line,
      ),
    );
  }
}

/// Top-left: a waveform while they talk, else their microphone's state.
class _MicBadge extends StatelessWidget {
  const _MicBadge({required this.tile});

  final _Tile tile;

  @override
  Widget build(BuildContext context) {
    final member = tile.member;
    final IconData icon;
    if (tile.isRinging) {
      icon = CupertinoIcons.phone_fill;
    } else if (member?.isSpeaking ?? false) {
      icon = CupertinoIcons.waveform;
    } else if (member?.micEnabled ?? false) {
      icon = CupertinoIcons.mic_fill;
    } else {
      icon = CupertinoIcons.mic_slash_fill;
    }
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0x59000000),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }
}

class _NameChip extends StatelessWidget {
  const _NameChip({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x59000000),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8,
            vertical: 4,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact ? AppTextStyles.metaMonoSm : AppTextStyles.metaMono)
                .copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// A shared screen, whole — `contain`, since a phone's portrait screen and a
/// desktop's landscape one both have to fit. The viewer's own share is not
/// drawn back to them (a hall of mirrors); a note says it is going out.
class _ScreenStage extends StatelessWidget {
  const _ScreenStage({required this.member, required this.name});

  final CallRoomMember member;
  final String name;

  @override
  Widget build(BuildContext context) {
    final p = CallPalette.of(context);
    final VideoTrack? screen = member.screen;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ColoredBox(
        color: p.raised,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (member.isLocal || screen == null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.rectangle_on_rectangle,
                      size: 40,
                      color: p.colors.ink2,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You’re sharing your screen',
                      style: AppTextStyles.titleSm.copyWith(
                        color: p.colors.ink,
                      ),
                    ),
                  ],
                ),
              )
            else
              VideoTrackRenderer(
                screen,
                key: ValueKey(screen),
                fit: VideoViewFit.contain,
              ),
            Positioned(
              left: 10,
              top: 10,
              child: _NameChip(label: name, compact: false),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Controls
// -----------------------------------------------------------------------------

/// The reference's tray — a light bar with black discs on the black screen,
/// a soft grey bar with dark discs on the white one — and the hang-up in
/// red. An "off" toggle is a hollow disc.
class _ControlTray extends StatelessWidget {
  const _ControlTray({required this.state});

  final CallState state;

  @override
  Widget build(BuildContext context) {
    final p = CallPalette.of(context);
    final cubit = context.read<CallCubit>();
    final active = state.phase == CallPhase.active;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.tray,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _TrayToggle(
                icon: state.cameraEnabled
                    ? CupertinoIcons.video_camera_solid
                    : CupertinoIcons.video_camera,
                semanticLabel: state.cameraEnabled
                    ? 'Turn camera off'
                    : 'Turn camera on',
                isOn: state.cameraEnabled,
                onTap: cubit.toggleCamera,
                onLongPress: state.cameraEnabled && active
                    ? cubit.flipCamera
                    : null,
              ),
              _TrayToggle(
                icon: state.speakerOn
                    ? CupertinoIcons.speaker_3_fill
                    : CupertinoIcons.headphones,
                semanticLabel: state.speakerOn ? 'Use earpiece' : 'Use speaker',
                isOn: state.speakerOn,
                onTap: cubit.toggleSpeaker,
              ),
              _TrayToggle(
                icon: state.micEnabled
                    ? CupertinoIcons.mic_fill
                    : CupertinoIcons.mic_slash_fill,
                semanticLabel: state.micEnabled ? 'Mute' : 'Unmute',
                isOn: state.micEnabled,
                onTap: cubit.toggleMicrophone,
              ),
              if (cubit.canShareScreen)
                _TrayToggle(
                  icon: CupertinoIcons.rectangle_on_rectangle,
                  semanticLabel: state.screenSharing
                      ? 'Stop sharing'
                      : 'Share screen',
                  isOn: state.screenSharing,
                  highlight: state.screenSharing,
                  onTap: active ? cubit.toggleScreenShare : null,
                ),
              CallRoundAction(
                color: p.colors.red,
                icon: CupertinoIcons.phone_down_fill,
                size: 54,
                semanticLabel: 'Leave call',
                onTap: cubit.hangUp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrayToggle extends StatelessWidget {
  const _TrayToggle({
    required this.icon,
    required this.semanticLabel,
    required this.isOn,
    required this.onTap,
    this.onLongPress,
    this.highlight = false,
  });

  final IconData icon;
  final String semanticLabel;
  final bool isOn;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Brand yellow rather than dark: something is going out that the user
  /// should not forget about (a screen share).
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = CallPalette.of(context);
    final fill = highlight
        ? p.colors.yel
        : (isOn ? p.trayDisc : Colors.transparent);
    final glyph = highlight
        ? p.colors.onYel
        : (isOn ? p.onTrayDisc : p.trayDisc);
    return Semantics(
      button: true,
      toggled: isOn,
      label: semanticLabel,
      child: Material(
        color: fill,
        shape: CircleBorder(
          side: BorderSide(
            color: isOn || highlight ? Colors.transparent : p.trayDisc,
            width: 1.5,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox.square(
            dimension: 54,
            child: Icon(
              icon,
              size: 23,
              color: onTap == null ? glyph.withValues(alpha: 0.4) : glyph,
            ),
          ),
        ),
      ),
    );
  }
}
