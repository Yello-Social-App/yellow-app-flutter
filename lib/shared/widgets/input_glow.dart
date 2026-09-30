import 'package:flutter/widgets.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_style.dart';
import 'glow_border.dart';

/// The outlined shell a borderless text field sits in: [fillColor] under a
/// crisp 1.5px [borderColor] outline that lights up into a glowing
/// [glowColor] ring while any field inside it has focus.
///
/// Focus is read from the subtree through a non-focusable [Focus], so callers
/// don't need to hand over a `FocusNode`. Only this shell rebuilds when focus
/// (or [controller]'s text) changes; [child] is passed through untouched.
/// The glow is [GlowBorder]'s painted blur, not a blurred `BoxShadow`, which
/// crashed this renderer on a rebuilding widget (`docs/GOTCHAS.md`).
///
/// For a field whose outline comes from its own `InputDecoration`, use
/// [GlowInputBorder] as the `focusedBorder` instead.
class InputGlow extends StatefulWidget {
  const InputGlow({
    super.key,
    required this.borderRadius,
    required this.child,
    this.fillColor,
    this.borderColor,
    this.glowColor,
    this.padding,
    this.controller,
  });

  final BorderRadius borderRadius;
  final Widget child;

  /// Painted behind [child]. Null leaves the shell unfilled.
  final Color? fillColor;

  /// The resting outline. Defaults to the theme's divider line.
  final Color? borderColor;

  /// The lit outline. Defaults to the brand yellow.
  final Color? glowColor;

  final EdgeInsetsGeometry? padding;

  /// When given, the outline also stays lit while this holds text — the chat
  /// composer's "there's an unsent draft" cue.
  final TextEditingController? controller;

  @override
  State<InputGlow> createState() => _InputGlowState();
}

class _InputGlowState extends State<InputGlow> {
  bool _focused = false;

  void _onFocusChange(bool focused) {
    if (focused != _focused) setState(() => _focused = focused);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = AppStyle.of(context);
    final padding = widget.padding;
    final shell = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.fillColor,
        borderRadius: widget.borderRadius,
        // Ink outline's hard shadow, only under a filled shell: an unfilled
        // one would show the solid offset straight through the field.
        boxShadow: widget.fillColor == null ? null : style.hardShadow(colors, AppStyle.pillOffset),
      ),
      child: padding == null ? widget.child : Padding(padding: padding, child: widget.child),
    );

    Widget outline(bool lit) => GlowBorder(
      color: lit ? (widget.glowColor ?? colors.yel) : (widget.borderColor ?? colors.line),
      borderRadius: widget.borderRadius,
      blur: lit ? 5 : 0,
      child: shell,
    );

    final controller = widget.controller;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _onFocusChange,
      child: controller == null
          ? outline(_focused)
          : ListenableBuilder(
              listenable: controller,
              builder: (context, _) => outline(_focused || controller.text.isNotEmpty),
            ),
    );
  }
}
