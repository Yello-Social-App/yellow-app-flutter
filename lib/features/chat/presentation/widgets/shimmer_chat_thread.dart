import 'package:flutter/material.dart';

import '../../../../shared/widgets/shimmer_loading.dart';

/// The chat screen's loading skeleton — a short back-and-forth of bubble
/// bones in place of a lone spinner in the middle of the thread.
///
/// Mirrors `_MessageBubble` (chat_page.dart): bubbles cap at 78% of the
/// screen width (minus the 36px sender column on incoming rows), use the
/// same 20px corners with the tail corner pulled to 6 on the last bubble of
/// a run, and incoming runs end on the 28px sender avatar. A one-line bubble
/// is 15/12 padding around a 22.5px body line; two lines add another 22.5.
class ShimmerChatThread extends StatelessWidget {
  const ShimmerChatThread({super.key});

  static const double _avatar = 28;
  static const double _senderColumn = _avatar + 8;
  static const double _oneLine = 47;
  static const double _twoLines = 69;

  /// (mine, [(width fraction, height)...]) — one entry per run.
  static const _runs = <(bool, List<(double, double)>)>[
    (false, [(0.62, _oneLine), (0.44, _oneLine)]),
    (true, [(0.56, _oneLine)]),
    (false, [(0.74, _twoLines)]),
    (true, [(0.38, _oneLine), (0.66, _twoLines)]),
    (false, [(0.5, _oneLine)]),
    (true, [(0.46, _oneLine)]),
  ];

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).width;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      children: [
        for (var r = 0; r < _runs.length; r++) ...[
          if (r > 0) const SizedBox(height: 14),
          for (var b = 0; b < _runs[r].$2.length; b++) ...[
            if (b > 0) const SizedBox(height: 4),
            _bubble(
              mine: _runs[r].$1,
              tailed: b == _runs[r].$2.length - 1,
              width: (screen * 0.78 - (_runs[r].$1 ? 0 : _senderColumn)) * _runs[r].$2[b].$1,
              height: _runs[r].$2[b].$2,
            ),
          ],
        ],
      ],
    );
  }

  Widget _bubble({required bool mine, required bool tailed, required double width, required double height}) {
    final bone = ShimmerBox(
      width: width,
      height: height,
      corners: BorderRadius.only(
        topLeft: const Radius.circular(20),
        topRight: const Radius.circular(20),
        bottomLeft: Radius.circular(!mine && tailed ? 6 : 20),
        bottomRight: Radius.circular(mine && tailed ? 6 : 20),
      ),
    );
    if (mine) return Align(alignment: Alignment.centerRight, child: bone);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: _avatar,
          child: tailed ? const ShimmerBox(width: _avatar, height: _avatar, borderRadius: _avatar / 2) : null,
        ),
        const SizedBox(width: _senderColumn - _avatar),
        Flexible(child: bone),
      ],
    );
  }
}
