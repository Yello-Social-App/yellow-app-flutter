import 'package:flutter/material.dart';

/// Design-token color palette lifted 1:1 from the Yello Mobile v2 Claude
/// Design source (`:root` / `[data-theme="dark"]` custom properties in
/// `Yello Mobile v2.dc.html`). Exposed as a [ThemeExtension] so every widget
/// can reach the exact token set the design used, rather than approximating
/// them through Material's ColorScheme roles.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surf,
    required this.surf2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.line2,
    required this.yel,
    required this.yelb,
    required this.yeld,
    required this.onYel,
    required this.red,
    required this.grn,
    required this.shell,
    required this.slot,
  });

  /// Page background.
  final Color bg;

  /// Card / surface background.
  final Color surf;

  /// Secondary surface (chips, tiles, inset panels).
  final Color surf2;

  /// Primary text / icon ink.
  final Color ink;

  /// Secondary ink — meta labels, captions.
  final Color ink2;

  /// Tertiary ink — placeholders, disabled.
  final Color ink3;

  /// Standard hairline border.
  final Color line;

  /// Faint hairline border (dividers inside cards).
  final Color line2;

  /// Brand yellow accent.
  final Color yel;

  /// Yellow tint background.
  final Color yelb;

  /// Yellow-on-dark text variant.
  final Color yeld;

  /// Text color used on top of [yel].
  final Color onYel;

  /// Destructive / like-red.
  final Color red;

  /// Positive / online-green.
  final Color grn;

  /// Phone-shell chrome (device frame in the mockup; used for the bottom nav).
  final Color shell;

  /// Empty image-slot placeholder fill.
  final Color slot;

  static const light = AppColors(
    bg: Color(0xFFFBFAF6),
    surf: Color(0xFFFFFFFF),
    surf2: Color(0xFFF5F2EA),
    ink: Color(0xFF14120C),
    ink2: Color(0xFF5C5546),
    ink3: Color(0xFF918A7B),
    line: Color(0x2914120C),
    line2: Color(0x1714120C),
    yel: Color(0xFFF4C542),
    yelb: Color(0xFFFFF3CE),
    yeld: Color(0xFF6B5200),
    onYel: Color(0xFF14120C),
    red: Color(0xFFE4574F),
    grn: Color(0xFF2E9E5B),
    shell: Color(0xFF14120C),
    slot: Color(0xFFEDE9DF),
  );

  static const dark = AppColors(
    bg: Color(0xFF12100A),
    surf: Color(0xFF1C1A13),
    surf2: Color(0xFF26231A),
    ink: Color(0xFFF7F5F0),
    ink2: Color(0xFFA79F90),
    ink3: Color(0xFF7D7667),
    line: Color(0x33F7F5F0),
    line2: Color(0x1AF7F5F0),
    yel: Color(0xFFF4C542),
    yelb: Color(0xFF3E3106),
    yeld: Color(0xFFF4C542),
    onYel: Color(0xFF14120C),
    red: Color(0xFFF2726A),
    grn: Color(0xFF4FC07E),
    shell: Color(0xFF000000),
    slot: Color(0xFF2A261C),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surf,
    Color? surf2,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? line,
    Color? line2,
    Color? yel,
    Color? yelb,
    Color? yeld,
    Color? onYel,
    Color? red,
    Color? grn,
    Color? shell,
    Color? slot,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surf: surf ?? this.surf,
      surf2: surf2 ?? this.surf2,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      yel: yel ?? this.yel,
      yelb: yelb ?? this.yelb,
      yeld: yeld ?? this.yeld,
      onYel: onYel ?? this.onYel,
      red: red ?? this.red,
      grn: grn ?? this.grn,
      shell: shell ?? this.shell,
      slot: slot ?? this.slot,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surf: Color.lerp(surf, other.surf, t)!,
      surf2: Color.lerp(surf2, other.surf2, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      yel: Color.lerp(yel, other.yel, t)!,
      yelb: Color.lerp(yelb, other.yelb, t)!,
      yeld: Color.lerp(yeld, other.yeld, t)!,
      onYel: Color.lerp(onYel, other.onYel, t)!,
      red: Color.lerp(red, other.red, t)!,
      grn: Color.lerp(grn, other.grn, t)!,
      shell: Color.lerp(shell, other.shell, t)!,
      slot: Color.lerp(slot, other.slot, t)!,
    );
  }

  /// Convenience accessor: `AppColors.of(context).ink`.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;
}
