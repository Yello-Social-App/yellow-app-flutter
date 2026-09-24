import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../domain/entities/story_entity.dart';
import '../bloc/story_compose_cubit.dart';
import '../widgets/story_background.dart';

/// "Add to your story" — one screen for both kinds of story, because
/// `POST /stories` is one path with two request bodies: JSON for a `TEXT`
/// story on a cover, multipart for an `IMAGE` one with an optional caption.
///
/// Pops with the created [StoryEntity] so the caller can drop it straight
/// into "Your story"; the spec is explicit that no follow-up
/// `GET /stories/me` is needed.
class StoryComposePage extends StatelessWidget {
  const StoryComposePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<StoryComposeCubit>(),
      child: const _StoryComposeView(),
    );
  }
}

class _StoryComposeView extends StatefulWidget {
  const _StoryComposeView();

  @override
  State<_StoryComposeView> createState() => _StoryComposeViewState();
}

class _StoryComposeViewState extends State<_StoryComposeView> {
  final _textController = TextEditingController();
  final _picker = ImagePicker();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    // Downscaled in the picker rather than shipped raw: the backend refuses
    // anything over 16 MP outright (`400 INVALID_IMAGE`) and re-encodes the
    // rest to fit 1080x1920 anyway, so sending a 12 MP original just makes
    // the upload slower for the user.
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: AppConstants.storyImageMaxDimension,
      maxHeight: AppConstants.storyImageMaxDimension,
    );
    if (picked == null || !mounted) return;
    context.read<StoryComposeCubit>().setImage(File(picked.path));
  }

  Future<void> _post() async {
    final cubit = context.read<StoryComposeCubit>();
    final ok = await cubit.post();
    if (!mounted) return;
    if (!ok) {
      AppStatusSnackbar.showError(context, message: cubit.state.errorMessage ?? 'Could not post your story.');
      return;
    }
    Navigator.of(context).pop(cubit.posted);
  }

  @override
  Widget build(BuildContext context) {
    // Full-bleed Stack, deliberately not wrapped in SafeArea (see
    // story_viewer_page.dart's identical comment) — each piece of chrome
    // adds the device's safe-area inset on top of its original hand-tuned
    // offset instead, so it clears the status bar/notch/gesture-pill on any
    // device rather than whichever one the design was eyeballed against.
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return BlocBuilder<StoryComposeCubit, StoryComposeState>(
      builder: (context, state) {
        final cubit = context.read<StoryComposeCubit>();
        return Scaffold(
          backgroundColor: const Color(0xFF0B0A07),
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Positioned.fill(
                child: state.isPhoto
                    // `contain`, matching `_StoryFrame` in the viewer — the
                    // composer has to frame the shot exactly as it will play
                    // back, or the user picks a photo against a preview that
                    // crops differently from the posted story.
                    ? Image.file(state.image!, fit: BoxFit.contain)
                    : DecoratedBox(decoration: BoxDecoration(gradient: storyBackgroundGradient(state.background))),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0, 0.28, 0.55, 1],
                    ),
                  ),
                ),
              ),

              // The text itself, centred on a cover story the way it will
              // play back. On a photo it is a caption, so it stays small and
              // sits with the rest of the bottom chrome.
              if (!state.isPhoto)
                Positioned(
                  left: 22,
                  right: 22,
                  top: 150 + topInset,
                  bottom: 220 + bottomInset,
                  child: Center(
                    child: TextField(
                      controller: _textController,
                      onChanged: cubit.setText,
                      maxLines: null,
                      maxLength: AppConstants.storyMaxChars,
                      textAlign: TextAlign.center,
                      cursorColor: storyBackgroundForeground(state.background),
                      style: TextStyle(
                        color: storyBackgroundForeground(state.background),
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1.12,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        hintText: 'Say something',
                        hintStyle: TextStyle(
                          color: storyBackgroundForeground(state.background).withValues(alpha: 0.45),
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),

              Positioned(
                top: 50 + topInset,
                left: 14,
                right: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundButton(icon: Icons.close, onTap: () => Navigator.of(context).maybePop()),
                    _VisibilityPill(
                      visibility: state.visibility,
                      onTap: () => cubit.setVisibility(
                        state.visibility == StoryVisibility.public
                            ? StoryVisibility.friends
                            : StoryVisibility.public,
                      ),
                    ),
                    _RoundButton(
                      icon: state.isPhoto ? Icons.text_fields : Icons.photo_library_outlined,
                      onTap: state.isPhoto ? cubit.clearImage : () => _pick(ImageSource.gallery),
                    ),
                  ],
                ),
              ),

              Positioned(
                top: 104 + topInset,
                right: 14,
                child: Column(
                  children: [
                    _RoundButton(icon: Icons.photo_camera_outlined, onTap: () => _pick(ImageSource.camera)),
                    const SizedBox(height: 9),
                    _RoundButton(icon: Icons.photo_outlined, onTap: () => _pick(ImageSource.gallery)),
                  ],
                ),
              ),

              // Cover picker — text stories only; the server ignores
              // `background` entirely on an image story.
              if (!state.isPhoto)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 96 + bottomInset,
                  child: SizedBox(
                    height: 48,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: StoryBackground.all.length,
                      itemBuilder: (context, index) {
                        final cover = StoryBackground.all[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 9),
                          child: StoryCoverSwatch(
                            background: cover,
                            selected: cover == state.background,
                            onTap: () => cubit.setBackground(cover),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              if (state.isPhoto)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 96 + bottomInset,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: TextField(
                      controller: _textController,
                      onChanged: cubit.setText,
                      maxLength: AppConstants.storyMaxChars,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Add a caption',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),

              Positioned(
                left: 14,
                right: 14,
                bottom: 30 + bottomInset,
                child: _PostButton(
                  enabled: state.canPost,
                  busy: state.isPosting,
                  label: state.visibility == StoryVisibility.public ? 'Share publicly' : 'Share with friends',
                  onTap: _post,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VisibilityPill extends StatelessWidget {
  const _VisibilityPill({required this.visibility, required this.onTap});

  final StoryVisibility visibility;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPublic = visibility == StoryVisibility.public;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isPublic ? Icons.public : Icons.group_outlined, size: 13, color: Colors.white),
            const SizedBox(width: 7),
            Text(
              '${visibility.label.toUpperCase()} · 24H',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.35), width: 1.5)),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 44, height: 44, child: Icon(icon, color: Colors.white, size: 18)),
      ),
    );
  }
}

class _PostButton extends StatelessWidget {
  const _PostButton({required this.enabled, required this.busy, required this.label, required this.onTap});

  final bool enabled;
  final bool busy;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF14120C);
    return Material(
      color: enabled ? const Color(0xFFF4C542) : const Color(0xFF6B6558),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: ink, width: 1.5),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2, color: ink),
                  )
                : Text(
                    label,
                    style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
          ),
        ),
      ),
    );
  }
}
