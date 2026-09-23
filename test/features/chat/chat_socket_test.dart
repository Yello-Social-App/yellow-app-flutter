import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/network/token_refresh_service.dart';
import 'package:yello_social_app/core/security/secure_storage_service.dart';
import 'package:yello_social_app/features/chat/data/datasources/chat_socket.dart';

class _Storage extends Mock implements SecureStorageService {}

class _Refresh extends Mock implements TokenRefreshService {}

/// A stand-in for `yello-chat`'s socket: expects `auth` first, answers
/// `auth.ok` for [validToken] and `error UNAUTHORIZED` otherwise, then echoes
/// whatever the test pushes through [push].
class _FakeChatServer {
  _FakeChatServer._(this._server);

  static Future<_FakeChatServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeChatServer._(server);
    server.listen(fake._onRequest);
    return fake;
  }

  final HttpServer _server;
  final List<Map<String, dynamic>> received = [];
  final _clients = <WebSocket>[];
  final _authed = Completer<void>();
  String validToken = 'good';

  String get url => 'ws://${_server.address.address}:${_server.port}/ws';
  Future<void> get authenticated => _authed.future;

  Future<void> _onRequest(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    _clients.add(socket);
    socket.listen((raw) {
      final frame = jsonDecode(raw as String) as Map<String, dynamic>;
      received.add(frame);
      if (frame['event'] == 'auth') {
        final data = frame['data'] as Map<String, dynamic>;
        if (data['token'] == validToken) {
          socket.add(jsonEncode({'event': 'auth.ok', 'data': {}}));
          if (!_authed.isCompleted) _authed.complete();
        } else {
          socket.add(jsonEncode({
            'event': 'error',
            'data': {'code': 'UNAUTHORIZED', 'message': 'Invalid token'},
          }));
        }
      }
    });
  }

  void push(Map<String, dynamic> frame) {
    for (final c in _clients) {
      c.add(jsonEncode(frame));
    }
  }

  Future<void> close() async {
    for (final c in _clients) {
      await c.close();
    }
    await _server.close(force: true);
  }
}

void main() {
  late _FakeChatServer server;
  late _Storage storage;
  late _Refresh refresh;

  setUp(() async {
    server = await _FakeChatServer.start();
    storage = _Storage();
    refresh = _Refresh();
  });

  tearDown(() => server.close());

  test('authenticates with the stored token on first subscribe and forwards frames', () async {
    when(storage.readAccessToken).thenAnswer((_) async => 'good');
    final socket = ChatSocket(secureStorage: storage, tokenRefresh: refresh, url: server.url);
    final connected = <bool>[];
    socket.connectionChanges.listen(connected.add);

    final frames = <Map<String, dynamic>>[];
    final sub = socket.frames.listen(frames.add);
    await server.authenticated.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(server.received.first['event'], 'auth');
    expect((server.received.first['data'] as Map)['token'], 'good');
    expect(socket.isConnected, isTrue);
    expect(connected, [true]);

    server.push({
      'event': 'typing',
      'data': {'conversationId': 'c1', 'userId': 'u2', 'isTyping': true},
    });
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(frames.map((f) => f['event']), contains('typing'));

    socket.send('typing', {'conversationId': 'c1', 'isTyping': true});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.received.last['event'], 'typing');

    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(socket.isConnected, isFalse, reason: 'the last unsubscribe closes the socket');
  });

  test('a rejected token is refreshed once, then the socket reconnects', () async {
    var token = 'stale';
    when(storage.readAccessToken).thenAnswer((_) async => token);
    when(refresh.refresh).thenAnswer((_) async {
      token = 'good';
      return true;
    });
    final socket = ChatSocket(secureStorage: storage, tokenRefresh: refresh, url: server.url);

    final sub = socket.frames.listen((_) {});
    await server.authenticated.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    verify(refresh.refresh).called(1);
    expect(server.received.where((f) => f['event'] == 'auth').length, 2);
    expect(socket.isConnected, isTrue);
    await sub.cancel();
  });

  test('send is a no-op before auth', () async {
    when(storage.readAccessToken).thenAnswer((_) async => null);
    final socket = ChatSocket(secureStorage: storage, tokenRefresh: refresh, url: server.url);
    final sub = socket.frames.listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 200));
    socket.send('typing', {'conversationId': 'c1', 'isTyping': true});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.received.where((f) => f['event'] == 'typing'), isEmpty);
    expect(socket.isConnected, isFalse);
    await sub.cancel();
  });
}
