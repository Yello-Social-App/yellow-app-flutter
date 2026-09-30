import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../../../../core/theme/app_colors.dart';
import '../bloc/call_cubit.dart';

/// The call UI's colours. It follows the theme: pure white in light mode and
/// pure black in dark — the chat header slab's pairing — with the active
/// token set for everything drawn on it (ADR-048).
///
/// Only what sits *on* full-screen video stays dark in both modes, since
/// light text over a scrim is the one thing that reads on any picture; see
/// [OnVideoTheme].
class CallPalette {
  const CallPalette._(this.colors, this.isDark);

  factory CallPalette.of(BuildContext context) => CallPalette._(
    AppColors.of(context),
    Theme.of(context).brightness == Brightness.dark,
  );

  /// The active theme's tokens — `ink`, `red`, `yel` and the rest.
  final AppColors colors;
  final bool isDark;

  /// The whole screen behind the call.
  Color get background => isDark ? Colors.black : Colors.white;

  /// One step off [background]: a tile, a notice, the self-view frame.
  Color get raised => isDark ? colors.surf : colors.slot;

  /// A solid disc that stands out against [background] — the top-bar
  /// buttons, an "on" toggle — and the glyph drawn on it.
  Color get disc => colors.ink;
  Color get onDisc => background;

  /// The group call's control tray: a light bar on black, a soft grey bar on
  /// white — and the discs drawn on it, which contrast with the bar.
  Color get tray => isDark ? colors.ink : raised;
  Color get trayDisc => isDark ? Colors.black : colors.ink;
  Color get onTrayDisc => isDark ? colors.ink : Colors.white;

  /// Status-bar icons that read on [background].
  SystemUiOverlayStyle get overlayStyle =>
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
}

/// Makes [child] read the dark token set whatever the theme — for what a 1:1
/// call draws over the other person's full-screen video, where a scrim keeps
/// light text legible and dark text would vanish into a dark picture.
class OnVideoTheme extends StatelessWidget {
  const OnVideoTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) return child;
    return Theme(
      data: theme.copyWith(
        brightness: Brightness.dark,
        extensions: [
          ...theme.extensions.values.where((e) => e is! AppColors),
          AppColors.dark,
        ],
      ),
      child: child,
    );
  }
}

/// A filled round button — answer, decline, hang up.
///
/// [semanticLabel] names it for a screen reader. Not a `Tooltip`: the call
/// UI sits above the router, where there is no `Overlay` for one to float in
/// (`docs/GOTCHAS.md`).
class CallRoundAction extends StatelessWidget {
  const CallRoundAction({
    super.key,
    required this.color,
    required this.icon,
    required this.size,
    required this.onTap,
    this.iconColor = Colors.white,
    this.semanticLabel,
  });

  final Color color;
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final Color iconColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, size: size * 0.42, color: iconColor),
          ),
        ),
      ),
    );
  }
}

/// How long the call has run. Ticks once a second on its own, so the rest of
/// the screen does not rebuild with it.
class CallTimerText extends StatefulWidget {
  const CallTimerText({super.key, required this.since, required this.style});

  final DateTime since;
  final TextStyle style;

  @override
  State<CallTimerText> createState() => _CallTimerTextState();
}

class _CallTimerTextState extends State<CallTimerText> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      formatCallDuration(DateTime.now().difference(widget.since)),
      style: widget.style.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
