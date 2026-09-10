import 'package:flutter/material.dart';

import '../../../../shared/widgets/image_placeholder.dart';

/// Story-capture screen. There's no camera/media pipeline behind this yet
/// (see `shared/widgets/image_placeholder.dart`) — this reproduces the
/// mockup's chrome (tools rail, caption field, audience buttons) around the
/// placeholder frame so the flow is complete visually even before a real
/// capture step exists.
class StoryComposePage extends StatefulWidget {
  const StoryComposePage({super.key});

  @override
  State<StoryComposePage> createState() => _StoryComposePageState();
}

class _StoryComposePageState extends State<StoryComposePage> {
  final _captionController = TextEditingController();
  static const _tools = [Icons.title, Icons.emoji_emotions_outlined, Icons.edit_outlined, Icons.circle_outlined];

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A07),
      body: Stack(
        children: [
          const Positioned.fill(child: ImagePlaceholder(caption: 'drop a photo for your story', dark: true)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0, 0.30, 0.58, 1],
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'STORY · 24H',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 38),
              ],
            ),
          ),
          Positioned(
            top: 104 + topInset,
            right: 14,
            child: Column(
              children: [
                for (final tool in _tools)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _RoundButton(icon: tool),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 104 + bottomInset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(999),
              ),
              child: TextField(
                controller: _captionController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
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
            child: _PillButton(label: 'Share story', filled: true, onTap: () => Navigator.of(context).maybePop()),
          ),
        ],
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

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.filled, required this.onTap});
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? const Color(0xFFF4C542) : Colors.black.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: filled ? const Color(0xFF14120C) : Colors.white.withValues(alpha: 0.4), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: filled ? const Color(0xFF14120C) : Colors.white,
                fontWeight: filled ? FontWeight.w800 : FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
