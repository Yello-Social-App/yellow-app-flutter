import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/image_placeholder.dart';
import '../bloc/story_cubit.dart';

class StoryViewerPage extends StatelessWidget {
  const StoryViewerPage({super.key, required this.userIndex});

  final int userIndex;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<StoryCubit>()..start(userIndex),
      child: const _StoryView(),
    );
  }
}

class _StoryView extends StatelessWidget {
  const _StoryView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StoryCubit, StoryState>(
      listenWhen: (prev, curr) => curr.status == StoryStatus.finished,
      listener: (context, state) => Navigator.of(context).maybePop(),
      builder: (context, state) {
        final cubit = context.read<StoryCubit>();
        final user = state.currentUser;
        final segment = state.currentSegment;

        // This is a full-bleed Stack (the photo fills the entire screen,
        // deliberately not wrapped in SafeArea so it doesn't letterbox) —
        // every piece of chrome instead adds the safe-area inset itself on
        // top of its original hand-tuned offset, so it clears the status
        // bar/notch/home-indicator/gesture-pill on any device instead of
        // just whatever the design was eyeballed against.
        final topInset = MediaQuery.paddingOf(context).top;
        final bottomInset = MediaQuery.paddingOf(context).bottom;

        return Scaffold(
          backgroundColor: const Color(0xFF0B0A07),
          body: state.status != StoryStatus.playing || user == null || segment == null
              ? const SizedBox.shrink()
              : Stack(
                  children: [
                    const Positioned.fill(child: ImagePlaceholder(caption: 'story image', dark: true)),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.72),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.88),
                            ],
                            stops: const [0, 0.34, 0.6, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 52 + topInset,
                      left: 14,
                      right: 14,
                      child: Row(
                        children: [
                          for (var i = 0; i < user.segments.length; i++) ...[
                            if (i > 0) const SizedBox(width: 5),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 3,
                                  value: i < state.segmentIndex
                                      ? 1
                                      : i == state.segmentIndex
                                          ? state.progress / 100
                                          : 0,
                                  backgroundColor: Colors.white.withValues(alpha: 0.32),
                                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      top: 72 + topInset,
                      left: 14,
                      right: 14,
                      child: Row(
                        children: [
                          AppAvatar(initials: user.name.initials, seed: user.avatarSeed, size: 38),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.name,
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 5),
                                Text(segment.time,
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 10.5)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 120 + topInset,
                      bottom: 120 + bottomInset,
                      child: Row(
                        children: [
                          Expanded(flex: 32, child: GestureDetector(onTap: cubit.previous, behavior: HitTestBehavior.opaque)),
                          Expanded(flex: 52, child: GestureDetector(onTap: cubit.next, behavior: HitTestBehavior.opaque)),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 100 + bottomInset,
                      child: IgnorePointer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4C542),
                                border: Border.all(color: Colors.black.withValues(alpha: 0.5), width: 1.5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                segment.tag,
                                style: const TextStyle(
                                    color: Color(0xFF14120C), fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.4),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              segment.caption,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 29, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.08),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 30 + bottomInset,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('Send a message',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 9),
                          GestureDetector(
                            onTap: cubit.toggleLike,
                            child: AnimatedScale(
                              scale: state.liked ? 1.1 : 1,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.elasticOut,
                              child: Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.3),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                                ),
                                child: Icon(
                                  state.liked ? Icons.favorite : Icons.favorite_border,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
