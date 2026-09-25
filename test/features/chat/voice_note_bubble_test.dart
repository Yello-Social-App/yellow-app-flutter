import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yello_social_app/core/audio/voice_note_player.dart';
import 'package:yello_social_app/core/audio/voice_note_plays_store.dart';
import 'package:yello_social_app/core/di/injection.dart';
import 'package:yello_social_app/core/theme/app_colors.dart';
import 'package:yello_social_app/features/chat/domain/entities/attachment_entity.dart';
import 'package:yello_social_app/features/chat/presentation/widgets/voice_note_bubble.dart';

/// The unheard/heard split (ADR-037) is drawn, not stored on the message —
/// so what is worth testing is that the two states differ on screen, that
/// the transcript starts quiet before the stored set has been read, and that
/// the extra dot did not push the row past the narrowest phone we ship to.
void main() {
  const narrowPhone = Size(320, 640);

  /// What an incoming bubble is given on a 320pt phone: 78% of the width,
  /// less the avatar column. Mirrors `_MessageRow` in `chat_page.dart`.
  const incomingMaxWidth = 320 * 0.78 - 36;

  final attachment = AttachmentEntity(
    id: 'att-1',
    kind: AttachmentKind.voice,
    fileName: 'voice-message.m4a',
    mimeType: 'audio/mp4',
    sizeBytes: 30412,
    voice: const VoiceMetaEntity(durationMs: 4870, waveform: [8, 22, 61, 100, 87, 45, 30, 72, 95, 60, 18, 5]),
    url: 'https://r2.example/voice.m4a',
  );

  late VoiceNotePlaysStore plays;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    plays = VoiceNotePlaysStore();
    sl
      ..registerSingleton<VoiceNotePlayer>(VoiceNotePlayer())
      ..registerSingleton<VoiceNotePlaysStore>(plays);
  });

  tearDown(() => sl.reset());

  Future<void> pumpBubble(WidgetTester tester, {bool onYellow = false}) async {
    tester.view.physicalSize = narrowPhone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: incomingMaxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                child: VoiceNoteBubble(attachment: attachment, onYellow: onYellow, onPlay: (_) {}),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color? playIconColor(WidgetTester tester) => tester.widget<Icon>(find.byIcon(Icons.play_arrow)).color;

  testWidgets('lays out inside an incoming bubble on the narrowest phone', (tester) async {
    await plays.restore();
    await pumpBubble(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('an unheard note is drawn in the accent, a heard one is not', (tester) async {
    await plays.restore();
    await pumpBubble(tester);

    expect(playIconColor(tester), AppColors.light.onYel, reason: 'unheard: yellow disc, ink icon');

    await plays.markHeard(attachment.id);
    await tester.pump();

    expect(playIconColor(tester), AppColors.light.bg, reason: 'heard: ink disc, page-coloured icon');
    expect(tester.takeException(), isNull);
  });

  testWidgets('stays quiet until the stored set has been read', (tester) async {
    // No `restore()`: this is the cold-start frame, where "heard" is not
    // known yet. Marking every note new here would flash the accent across
    // a whole transcript the user listened to yesterday.
    await pumpBubble(tester);

    expect(playIconColor(tester), AppColors.light.bg);
  });

  testWidgets('survives the IntrinsicWidth a reply quote wraps the bubble in', (tester) async {
    // A voice note sent as a reply puts this row under `IntrinsicWidth`
    // (see `_MessageRow`), which asks it for an intrinsic width — the one
    // question a flexible child can refuse to answer.
    await plays.restore();
    tester.view.physicalSize = narrowPhone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: incomingMaxWidth),
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Quoted message'),
                    VoiceNoteBubble(attachment: attachment, onYellow: false, onPlay: (_) {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('never marks the sender own note unheard', (tester) async {
    await plays.restore();
    await pumpBubble(tester, onYellow: true);

    // Whether the other side played it is a fact the chat API does not
    // report, so an own bubble is always the quiet style.
    expect(playIconColor(tester), AppColors.light.yel);
  });
}
