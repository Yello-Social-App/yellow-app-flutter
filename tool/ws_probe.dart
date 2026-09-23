// Probes yello-chat's WebSocket by sending frames and printing what comes
// back. This is how the `auth` handshake in `ChatSocket` was established
// (its validation errors name the missing field), and it is the quickest
// way to confirm any other frame's shape against the live service.
//
//   dart run tool/ws_probe.dart                    # unauthenticated: ping + auth schema
//   dart run tool/ws_probe.dart <access token>     # authenticated: typing frame schema
//
// The token is the yello-api access token (a JWT). It is used once, on the
// socket, and never written anywhere. Nothing here mutates data: `typing`
// is a transient signal and the conversation id below does not exist.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _url = 'wss://api.yello.cachewraith.com/ws';
const _nilUuid = '00000000-0000-0000-0000-000000000000';

Future<void> main(List<String> args) async {
  final token = args.isEmpty ? null : args.first;
  stdout.writeln('connecting $_url');
  final socket = await WebSocket.connect(_url).timeout(const Duration(seconds: 15));
  final closed = Completer<void>();
  socket.listen(
    (frame) => stdout.writeln('<< $frame'),
    onError: (Object e) => stdout.writeln('!! $e'),
    onDone: () {
      stdout.writeln('closed code=${socket.closeCode} reason=${socket.closeReason}');
      if (!closed.isCompleted) closed.complete();
    },
  );

  Future<void> send(Map<String, dynamic> frame) async {
    final raw = jsonEncode(frame);
    stdout.writeln('>> $raw');
    socket.add(raw);
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  // The server closes with 4401 "authentication timeout" a few seconds after
  // connect, so `auth` goes first.
  if (token == null) {
    await send({'event': 'auth', 'data': {'ref': 'a1'}});
    await send({'event': 'ping', 'data': {'ref': 'p1'}});
  } else {
    await send({'event': 'auth', 'data': {'ref': 'a1', 'token': token}});
    // With a valid token the server validates the frame's fields before it
    // looks the conversation up, so an empty `data` lists the required
    // paths, and a made-up conversation answers NOT_FOUND once the shape is
    // right — never a real side effect.
    await send({'event': 'typing', 'data': {'ref': 't1'}});
    await send({'event': 'typing', 'data': {'ref': 't2', 'conversationId': _nilUuid, 'isTyping': true}});
    await send({'event': 'typing', 'data': {'ref': 't3', 'conversationId': _nilUuid, 'typing': true}});
    await send({'event': 'ping', 'data': {'ref': 'p1'}});
  }

  await socket.close();
  await closed.future.timeout(const Duration(seconds: 5), onTimeout: () {});
}
