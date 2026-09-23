import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/token_refresh_service.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../../../core/utils/logger.dart';
import 'chat_remote_datasource.dart';

/// The live connection to `yello-chat`: `wss://<host>/ws`, frames
/// `{ "event": string, "data": object }`.
///
/// **Handshake** (verified against the live service on 2026-09-22 by
/// sending incomplete frames and reading the validation errors back —
/// `tool/ws_probe.dart` repeats that): the upgrade needs no header; the
/// client must send `{ "event": "auth", "data": { "token": <access token> } }`
/// within a few seconds of connecting or the server closes with code 4401
/// "authentication timeout". Success is an `auth.ok` frame; a bad token is
/// `error { code: UNAUTHORIZED }`. `ping` → `pong { serverTime }` works
/// before auth too.
///
/// Lifecycle: connects when the first listener subscribes to [frames],
/// reconnects with exponential backoff while anyone is listening, and
/// closes when the last listener goes away — so an open chat screen is
/// what keeps the socket alive, and leaving it drops the connection.
/// [isConnected] tells the screen whether it can ease off its history poll.
///
/// Every decoded server frame goes out on [frames] as-is; the repository
/// turns them into `ChatEvent`s through `ChatFrameDecoder`. The one frame
/// handled here is `auth.ok` (marks the session live) and an auth `error`
/// (one token refresh, then give up until the next subscribe).
class ChatSocket {
  ChatSocket({
    required SecureStorageService secureStorage,
    required TokenRefreshService tokenRefresh,
    String? url,
  })  : _secureStorage = secureStorage,
        _tokenRefresh = tokenRefresh,
        _url = url;

  final SecureStorageService _secureStorage;
  final TokenRefreshService _tokenRefresh;
  final String? _url;

  late final StreamController<Map<String, dynamic>> _frames = StreamController<Map<String, dynamic>>.broadcast(
    onListen: _ensureConnected,
    onCancel: _disconnect,
  );
  final StreamController<bool> _connected = StreamController<bool>.broadcast();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  bool _authenticated = false;
  bool _connecting = false;
  bool _wantConnection = false;
  bool _refreshedOnce = false;
  int _attempt = 0;

  /// Bounds the backoff between reconnect attempts: 1 s, 2 s, 4 s … 30 s.
  static const Duration _maxBackoff = Duration(seconds: 30);

  /// Every decoded frame from the server, authenticated or not.
  Stream<Map<String, dynamic>> get frames => _frames.stream;

  /// True between `auth.ok` and the next disconnect.
  bool get isConnected => _authenticated;
  Stream<bool> get connectionChanges => _connected.stream;

  /// `wss://api.yello.cachewraith.com/ws` — the API base with the scheme
  /// swapped, unless a test passes one in.
  String get url {
    if (_url != null) return _url;
    final base = Uri.parse(AppConfig.baseUrl);
    return base.replace(scheme: base.scheme == 'http' ? 'ws' : 'wss', path: ChatRoutes.socketPath).toString();
  }

  /// Sends one frame. Dropped silently when the socket is not live — every
  /// client → server event here is best-effort (typing) or has an HTTP
  /// path the caller already uses.
  void send(String event, Map<String, dynamic> data) {
    final socket = _socket;
    if (socket == null || !_authenticated) return;
    try {
      socket.add(jsonEncode({'event': event, 'data': data}));
    } catch (e) {
      appLogger.w('ChatSocket: send($event) failed — $e');
    }
  }

  void _ensureConnected() {
    _wantConnection = true;
    _refreshedOnce = false;
    if (_socket != null || _connecting) return;
    unawaited(_connect());
  }

  Future<void> _connect() async {
    if (!_wantConnection || _connecting) return;
    _connecting = true;
    try {
      final socket = await WebSocket.connect(url).timeout(const Duration(seconds: 15));
      if (!_wantConnection) {
        await socket.close();
        return;
      }
      // Protocol-level keepalive; the server also answers an app-level
      // `ping`, but this needs no frame handling.
      socket.pingInterval = const Duration(seconds: 30);
      _socket = socket;
      _sub = socket.listen(_onRaw, onError: (Object e) => _onClosed(error: e), onDone: _onClosed);

      final token = await _secureStorage.readAccessToken();
      if (token == null) {
        appLogger.w('ChatSocket: no access token — not authenticating.');
        await _disconnect();
        return;
      }
      socket.add(jsonEncode({
        'event': 'auth',
        'data': {'token': token},
      }));
    } on Object catch (e) {
      appLogger.w('ChatSocket: connect failed — $e');
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _onRaw(dynamic raw) {
    if (raw is! String) return;
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (json is! Map<String, dynamic>) return;
    final event = json['event'];
    final data = json['data'];
    if (event is! String) return;

    switch (event) {
      case 'auth.ok':
        _attempt = 0;
        _setAuthenticated(true);
      case 'error':
        // Only the auth reply matters here; any other error belongs to a
        // request the repository made and is forwarded like any frame.
        if (!_authenticated && data is Map<String, dynamic> && data['code'] == 'UNAUTHORIZED') {
          unawaited(_onAuthRejected());
          return;
        }
    }
    _frames.add(json);
  }

  /// A rejected token is most often an expired one: refresh once and
  /// reconnect. A second rejection means the session really is gone —
  /// stop until something subscribes again (a re-login makes the chat
  /// screen do exactly that).
  Future<void> _onAuthRejected() async {
    await _teardownSocket();
    if (_refreshedOnce) {
      appLogger.w('ChatSocket: token rejected after a refresh — giving up.');
      _wantConnection = false;
      return;
    }
    _refreshedOnce = true;
    final refreshed = await _tokenRefresh.refresh();
    if (!refreshed) {
      appLogger.w('ChatSocket: token rejected and refresh failed — giving up.');
      _wantConnection = false;
      return;
    }
    unawaited(_connect());
  }

  void _onClosed({Object? error}) {
    if (error != null) appLogger.w('ChatSocket: closed with error — $error');
    unawaited(_teardownSocket());
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_wantConnection || _reconnectTimer != null) return;
    final delay = Duration(seconds: min(_maxBackoff.inSeconds, 1 << min(_attempt, 5)));
    _attempt++;
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      unawaited(_connect());
    });
  }

  Future<void> _teardownSocket() async {
    _setAuthenticated(false);
    await _sub?.cancel();
    _sub = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        await socket.close();
      } on Object catch (_) {
        // Already gone.
      }
    }
  }

  Future<void> _disconnect() async {
    _wantConnection = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _attempt = 0;
    await _teardownSocket();
  }

  void _setAuthenticated(bool value) {
    if (_authenticated == value) return;
    _authenticated = value;
    _connected.add(value);
  }

  /// Sign-out: drop the connection outright. Listeners stay subscribed;
  /// the next chat screen opened after a re-login reconnects with the new
  /// token because `onListen` fires again on the first new subscription —
  /// and `_wantConnection` is re-armed there too.
  Future<void> reset() => _disconnect();
}
