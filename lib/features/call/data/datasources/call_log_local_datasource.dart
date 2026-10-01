import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/call_entity.dart';
import '../../domain/entities/call_log_entry.dart';

/// The call log has no backend — `yello-chat` writes no call line into a
/// conversation and lists no past calls — so it is persisted on-device via
/// `shared_preferences`, like saved posts. Not synced across devices; an
/// accepted trade-off, not a bug.
abstract interface class CallLogLocalDataSource {
  Future<List<CallLogEntry>> read();
  Future<void> write(List<CallLogEntry> entries);
  Future<void> clear();
}

class CallLogLocalDataSourceImpl implements CallLogLocalDataSource {
  static const _key = 'call.log';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<List<CallLogEntry>> read() async {
    final raw = (await _prefs).getString(_key);
    if (raw == null) return [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      // A value that no longer parses would otherwise block every later
      // note; start over instead.
      return [];
    }
    if (decoded is! List) return [];
    return [
      for (final item in decoded)
        if (item is Map<String, dynamic>) ?_fromJson(item),
    ];
  }

  @override
  Future<void> write(List<CallLogEntry> entries) async {
    await (await _prefs).setString(_key, jsonEncode([for (final entry in entries) _toJson(entry)]));
  }

  @override
  Future<void> clear() async {
    await (await _prefs).remove(_key);
  }

  static Map<String, dynamic> _toJson(CallLogEntry entry) => {
    'callId': entry.callId,
    'conversationId': entry.conversationId,
    'media': entry.media.wire,
    'group': entry.isGroup,
    'outgoing': entry.isOutgoing,
    'endReason': entry.endReason.name,
    'at': entry.at.toUtc().toIso8601String(),
    'talkSeconds': entry.talkTime?.inSeconds,
  };

  /// Null for a row that no longer reads — dropped rather than failing the
  /// whole log.
  static CallLogEntry? _fromJson(Map<String, dynamic> json) {
    final callId = json['callId'];
    final conversationId = json['conversationId'];
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    final endReason = CallEndReason.values.asNameMap()[json['endReason']];
    if (callId is! String || conversationId is! String || at == null || endReason == null) return null;
    final talkSeconds = json['talkSeconds'];
    return CallLogEntry(
      callId: callId,
      conversationId: conversationId,
      media: CallMedia.fromWire(json['media']),
      isGroup: json['group'] == true,
      isOutgoing: json['outgoing'] == true,
      endReason: endReason,
      at: at,
      talkTime: talkSeconds is int ? Duration(seconds: talkSeconds) : null,
    );
  }
}
