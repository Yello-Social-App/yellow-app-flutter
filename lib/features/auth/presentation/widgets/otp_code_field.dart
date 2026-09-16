import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';

/// A row of [length] single-digit boxes standing in for one OTP field —
/// same pill-field palette as `AuthFormField` (colors.surf2 fill,
/// colors.line border), just split one box per digit instead of one plain
/// text field. [controller] is kept in sync with the combined code, so an
/// existing call site that only ever read `controller.text` (e.g.
/// `AuthCubit.verifyOtp`) needs no changes. [onCompleted] fires once every
/// box is filled — the box-input equivalent of the old field's
/// `onSubmitted` (auto-verify once the code is fully typed).
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;
  final void Function(String code)? onCompleted;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  late final List<TextEditingController> _boxes;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    // Seeds from whatever the caller's controller already held (usually
    // empty, but this keeps a pre-filled/restored value from vanishing).
    final existing = widget.controller.text.split('');
    _boxes = List.generate(
      widget.length,
      (i) =>
          TextEditingController(text: i < existing.length ? existing[i] : ''),
    );
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _boxes) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _syncController() {
    widget.controller.text = _boxes.map((c) => c.text).join();
    if (widget.controller.text.length == widget.length) {
      widget.onCompleted?.call(widget.controller.text);
    }
  }

  void _onChanged(int index, String value) {
    // Pasting the full code lands it in whichever box was focused —
    // spread it across the rest instead of leaving it truncated to that
    // one box's single character.
    if (value.length > 1) {
      final digits = value.split('');
      for (var i = 0; i < digits.length && index + i < widget.length; i++) {
        _boxes[index + i].text = digits[i];
      }
      _focusNodes[(index + digits.length).clamp(0, widget.length - 1)]
          .requestFocus();
      _syncController();
      return;
    }
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    _syncController();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < widget.length; i++)
          SizedBox(
            width: 50,
            height: 65,
            child: Focus(
              // Backspace on an already-empty box hops back and clears the
              // previous digit, matching every native OTP box input.
              onKeyEvent: (node, event) {
                final isBackspace =
                    event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.backspace;
                if (isBackspace && _boxes[i].text.isEmpty && i > 0) {
                  _boxes[i - 1].clear();
                  _focusNodes[i - 1].requestFocus();
                  _syncController();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surf2,
                  borderRadius: BorderRadius.circular(AppRadii.xs),
                  border: Border.all(color: colors.line, width: 1.5),
                ),
                alignment: Alignment.center,
                child: TextField(
                  controller: _boxes[i],
                  focusNode: _focusNodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: widget
                      .length, // allows a full-code paste; _onChanged spreads it out
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTextStyles.displayLg.copyWith(color: colors.ink),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (value) => _onChanged(i, value),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
