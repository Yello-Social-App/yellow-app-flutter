import 'dart:async';

import '../../../../core/utils/logger.dart';
import 'chat_frame_decoder.dart';
import 'chat_socket.dart';

/// The app's one answer to "who is online right now", folded from
/// `yello-chat`'s `presence` frames.
///
/// Presence is socket-only: no endpoint on any of the three services reports
/// it (`docs/BACKEND.md`), so what this holds is whatever the live connection
/// has said since it came up — and nothing at all while it is down. A user
/// missing from [onlineUserIds] therefore means *not known to be online*, not
/// "offline"; the UI draws a dot for the first and nothing for the second,
/// which reads correctly either way.
///
/// Lifecycle mirrors [ChatSocket]'s own: the frame subscription — and with it
/// the connection — is opened by the first [watch] listener and dropped when
/// the last one goes away. Whoever wants dots on screen holds a listener, so
/// no tab that cannot draw one pays for a WebSocket (ADR-038).
class PresenceTracker {
  PresenceTracker(this._socket);

  final ChatSocket _socket;

  /// Ids the socket has named as online, newest word wins.
  final Set<String> _online = {};

  late final StreamController<Set<String>> _changes = StreamController<Set<String>>.broadcast(
    onListen: _attach,
    onCancel: _detach,
  );

  StreamSubscription<Map<String, dynamic>>? _frames;
  StreamSubscription<bool>? _connection;

  /// The raw shape of a `presence` frame is not documented anywhere this repo
  /// can reach (see [ChatFrameDecoder.presence]), so the first one of the
  /// process is logged whole — read or not. Once, because a shape this client
  /// cannot read is a shape it cannot read on every tick, and because the
  /// point of the line is the shape, which does not change mid-session.
  ///
  /// The unreadable case is a *warning*, so it survives the release filter and
  /// a user's own device can report it; a frame that read fine is an `info`,
  /// which only a debug run prints — which is where `adb logcat` is anyway.
  bool _loggedFrame = false;
  bool _loggedUnreadable = false;

  Set<String> get onlineUserIds => Set.unmodifiable(_online);

  bool isOnline(String userId) => _online.contains(userId);

  /// Who is online now, then every change. The current set comes first so a
  /// screen opened long after the connection came up does not wait for
  /// someone's status to flip — the same reasoning as `watchEvents` yielding
  /// `LiveDeliveryChanged` before any frame.
  Stream<Set<String>> watch() async* {
    yield onlineUserIds;
    yield* _changes.stream;
  }

  void _attach() {
    // `frames` is what opens the socket; `connectionChanges` is a plain
    // broadcast and opens nothing, so the order here does not matter.
    _frames ??= _socket.frames.listen(_onFrame);
    _connection ??= _socket.connectionChanges.listen((isLive) {
      if (!isLive) _clear();
    });
  }

  void _detach() {
    unawaited(_frames?.cancel());
    unawaited(_connection?.cancel());
    _frames = null;
    _connection = null;
    // Nothing is listening and nothing is arriving: every id in here is now
    // a claim this client can no longer stand behind.
    _online.clear();
  }

  void _onFrame(Map<String, dynamic> frame) {
    if (frame['event'] != 'presence') return;
    final updates = ChatFrameDecoder.presence(frame);
    if (!_loggedFrame) {
      _loggedFrame = true;
      appLogger.i('yello-chat presence frame, read as $updates — $frame');
    }
    if (updates == null) {
      if (!_loggedUnreadable) {
        _loggedUnreadable = true;
        appLogger.w('yello-chat presence frame not understood — $frame');
      }
      return;
    }

    var changed = false;
    for (final update in updates) {
      changed |= update.isOnline ? _online.add(update.userId) : _online.remove(update.userId);
    }
    if (changed) _changes.add(onlineUserIds);
  }

  /// The connection dropped. Presence is live-only, so the set goes with it
  /// rather than leaving green dots on people who may have left hours ago.
  void _clear() {
    if (_online.isEmpty) return;
    _online.clear();
    _changes.add(onlineUserIds);
  }
}
