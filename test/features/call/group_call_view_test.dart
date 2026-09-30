import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/call/call_room.dart';
import 'package:yello_social_app/core/di/injection.dart';
import 'package:yello_social_app/core/theme/app_colors.dart';
import 'package:yello_social_app/features/call/domain/entities/call_entity.dart';
import 'package:yello_social_app/features/call/presentation/bloc/call_cubit.dart';
import 'package:yello_social_app/features/call/presentation/widgets/call_widgets.dart';
import 'package:yello_social_app/features/call/presentation/widgets/group_call_view.dart';
import 'package:yello_social_app/features/chat/presentation/bloc/messages_cubit.dart';

class _CallCubit extends MockCubit<CallState> implements CallCubit {}

class _MessagesCubit extends MockCubit<MessagesState> implements MessagesCubit {}

final _state = CallState(
  phase: CallPhase.active,
  kind: CallKind.group,
  peer: const CallPeer(name: 'Weekend crew', avatarSeed: 3),
  members: const {'ana': CallPeer(name: 'Ana Sok', avatarSeed: 1)},
  call: CallEntity(
    id: 'call-9',
    conversationId: 'group-1',
    kind: CallKind.group,
    initiatorId: 'ana',
    media: CallMedia.video,
    status: CallStatus.active,
    createdAt: DateTime(2026, 9, 30, 8),
    answeredAt: DateTime(2026, 9, 30, 8, 0, 4),
    participants: const [
      CallParticipant(userId: 'ana', state: CallParticipantState.joined),
      CallParticipant(userId: 'me', state: CallParticipantState.joined),
      CallParticipant(userId: 'bo', state: CallParticipantState.invited),
    ],
    isOutgoing: false,
  ),
  peerJoined: true,
  roomMembers: const [
    CallRoomMember(identity: 'me', isLocal: true, micEnabled: true),
    CallRoomMember(identity: 'ana', isLocal: false, isSpeaking: true),
  ],
);

void main() {
  late _CallCubit cubit;

  setUp(() {
    cubit = _CallCubit();
    when(() => cubit.state).thenReturn(_state);
    when(() => cubit.canShareScreen).thenReturn(true);
    final messages = _MessagesCubit();
    when(() => messages.state).thenReturn(const MessagesState());
    sl.registerLazySingleton<MessagesCubit>(() => messages);
  });

  tearDown(() => sl.reset());

  // `CallHost` puts the call beside the router's Navigator, so nothing above
  // it has an Overlay. Rebuilding that here — MaterialApp's builder without
  // its child — is what caught a Tooltip crashing the screen on first open.
  testWidgets('builds with no Overlay above it, as CallHost hosts it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, _) => BlocProvider<CallCubit>.value(
          value: cubit,
          child: Material(child: GroupCallView(state: _state)),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Weekend crew'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Ana Sok'), findsOneWidget);
    expect(find.textContaining('ringing'), findsOneWidget, reason: 'bo is still being rung');
  });

  group('follows the theme', () {
    Future<CallPalette> paletteIn(WidgetTester tester, ThemeData theme) async {
      late CallPalette palette;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (context, _) => BlocProvider<CallCubit>.value(
            value: cubit,
            child: Material(
              child: Builder(
                builder: (context) {
                  palette = CallPalette.of(context);
                  return GroupCallView(state: _state);
                },
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      return palette;
    }

    testWidgets('white in light mode', (tester) async {
      final palette = await paletteIn(tester, ThemeData(extensions: const [AppColors.light]));
      expect(palette.background, Colors.white);
      expect(palette.colors.ink, AppColors.light.ink);
    });

    testWidgets('black in dark mode', (tester) async {
      final palette = await paletteIn(
        tester,
        ThemeData(brightness: Brightness.dark, extensions: const [AppColors.dark]),
      );
      expect(palette.background, Colors.black);
      expect(palette.colors.ink, AppColors.dark.ink);
    });

    testWidgets('what sits on video reads dark tokens even in light mode', (tester) async {
      late CallPalette onVideo;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [AppColors.light]),
          home: OnVideoTheme(
            child: Builder(
              builder: (context) {
                onVideo = CallPalette.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(onVideo.isDark, isTrue);
      expect(onVideo.colors.ink, AppColors.dark.ink);
    });
  });
}
