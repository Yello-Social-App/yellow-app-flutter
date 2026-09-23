import 'package:flutter/material.dart';

/// Design-token color palette. It began as a 1:1 lift of the Yello Mobile v2
/// Claude Design source (`:root` / `[data-theme="dark"]` custom properties in
/// `Yello Mobile v2.dc.html`) and has since been retuned to a lighter, softer
/// set — see ADR-020 for which tokens moved and why. Exposed as a
/// [ThemeExtension] so every widget can reach the exact token set the app
/// draws with, rather than approximating it through Material's ColorScheme
/// roles.
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

  /// The light set, deliberately soft rather than high-contrast:
  ///
  /// - hairlines sit at ~10% / ~6% ink instead of ~16% / ~9%, so a border
  ///   reads as a seam rather than a drawn outline;
  /// - the page is a warm off-white while a card stays pure white, so a
  ///   surface separates from the page on its own and no longer needs the
  ///   border to do that work (this is what lets the hairlines drop — see
  ///   ADR-012, whose `bg == surf` premise this replaces);
  /// - primary ink is a warm charcoal, not near-black (still 13:1 on a
  ///   card).
  ///
  /// [ink3] is the one token deliberately *not* lightened: at 3.4:1 on a
  /// card it is already at the 3:1 floor for placeholder and disabled text,
  /// and anything paler stops being readable.
  static const light = AppColors(
    bg: Color(0xFFFEFCF7),
    surf: Color(0xFFFFFFFF),
    surf2: Color(0xFFFAF7F0),
    ink: Color(0xFF2A2620),
    ink2: Color(0xFF6B6357),
    ink3: Color(0xFF918A7B),
    line: Color(0x1A14120C),
    line2: Color(0x0F14120C),
    yel: Color(0xFFF4C542),
    yelb: Color(0xFFFFF8E1),
    yeld: Color(0xFF6F5502),
    onYel: Color(0xFF2A2620),
    red: Color(0xFFE4574F),
    grn: Color(0xFF2E9E5B),
    shell: Color(0xFF14120C),
    slot: Color(0xFFF3F0E8),
  );

  /// The dark set, lifted off black by the same retune: surfaces move up a
  /// step (charcoal rather than near-black) and the light-on-dark hairlines
  /// come down from 20%/10% to 17%/8%, so the same "soft seam" reading holds
  /// in both themes.
  ///
  /// [shell] stays pure black on purpose — it is the one surface that is
  /// dark in *both* themes (ADR-009), and keeping it below the lifted [bg]
  /// is what still makes it read as a slab.
  static const dark = AppColors(
    bg: Color(0xFF1A1811),
    surf: Color(0xFF24211A),
    surf2: Color(0xFF2E2B21),
    ink: Color(0xFFF7F5F0),
    ink2: Color(0xFFA79F90),
    ink3: Color(0xFF7D7667),
    line: Color(0x2BF7F5F0),
    line2: Color(0x14F7F5F0),
    yel: Color(0xFFF4C542),
    yelb: Color(0xFF473807),
    yeld: Color(0xFFF4C542),
    onYel: Color(0xFF2A2620),
    red: Color(0xFFF2726A),
    grn: Color(0xFF4FC07E),
    shell: Color(0xFF000000),
    slot: Color(0xFF322E24),
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
