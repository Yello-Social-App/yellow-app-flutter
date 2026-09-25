import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yello_social_app/core/audio/voice_note_plays_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('treats every note as heard until the stored set has been read', () {
    final store = VoiceNotePlaysStore();

    // The point of this: a cold start must not flash the unheard accent
    // across a transcript of notes the user played yesterday.
    expect(store.heard.value, isNull);
    expect(store.isHeard('att-1'), isTrue);
  });

  test('restores what an earlier session heard', () async {
    SharedPreferences.setMockInitialValues({
      'chat.heard_voice_note_ids': ['att-1', 'att-2'],
    });
    final store = VoiceNotePlaysStore();

    await store.restore();

    expect(store.isHeard('att-1'), isTrue);
    expect(store.isHeard('att-3'), isFalse);
  });

  test('marking a note heard notifies listeners and survives a restart', () async {
    final store = VoiceNotePlaysStore();
    await store.restore();
    var notifications = 0;
    store.heard.addListener(() => notifications++);

    await store.markHeard('att-9');
    expect(store.isHeard('att-9'), isTrue);
    expect(notifications, 1);

    // Same id again: no second write, and no repaint of every bubble.
    await store.markHeard('att-9');
    expect(notifications, 1);

    final next = VoiceNotePlaysStore();
    await next.restore();
    expect(next.isHeard('att-9'), isTrue);
  });

  test('keeps the newest ids when the stored set is full', () async {
    final store = VoiceNotePlaysStore();
    await store.restore();

    for (var i = 0; i < 605; i++) {
      await store.markHeard('att-$i');
    }

    // The oldest fall off — an old note re-flagged as new is the harmless
    // side of this trade; a *new* note that reads as heard is not.
    expect(store.isHeard('att-0'), isFalse);
    expect(store.isHeard('att-604'), isTrue);
    expect(store.heard.value, hasLength(600));
  });
}
