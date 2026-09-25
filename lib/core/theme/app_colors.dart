import 'package:flutter/material.dart';

/// Which palette family the app draws with. Orthogonal to [Brightness]: each
/// flavor supplies both a light and a dark [AppColors] set, so the four
/// themes the Theme screen offers are the two flavors crossed with the two
/// brightnesses.
///
/// Adding a flavor means adding a case here plus its two palettes in
/// [AppColors] — nothing else in the app hard-codes a palette, because every
/// widget reads tokens through `AppColors.of(context)`.
enum AppThemeFlavor {
  /// The original hand-tuned Yello Mobile v2 palette: warm off-white paper
  /// and warm charcoal, soft hairlines, amber-leaning yellow (ADR-020).
  classic('Classic', 'Warm paper and charcoal, soft seams.'),

  /// "Quiet rails", lifted from the Yello Design System artifact
  /// (`project/tokens.json` / `project/README.md`): neutral grey-black
  /// layers split by hairlines, one saturated yellow per view. Dark-first —
  /// the light set re-points the same roles rather than being its own
  /// design (ADR-035).
  quietRails('Quiet rails', 'Neutral greys, one saturated yellow.');

  const AppThemeFlavor(this.label, this.blurb);

  /// Name shown on the Theme screen.
  final String label;

  /// One-line description shown under [label].
  final String blurb;

  /// Round-trips through `shared_preferences`. The stored string is the enum
  /// `name`, so renaming a constant would orphan saved choices — keep the
  /// names stable and change [label] instead.
  static AppThemeFlavor fromName(String? name) => values.firstWhere((f) => f.name == name, orElse: () => classic);
}

/// Design-token color palette. It began as a 1:1 lift of the Yello Mobile v2
/// Claude Design source (`:root` / `[data-theme="dark"]` custom properties in
/// `Yello Mobile v2.dc.html`) and has since been retuned to a lighter, softer
/// set — see ADR-020 for which tokens moved and why. Exposed as a
/// [ThemeExtension] so every widget can reach the exact token set the app
/// draws with, rather than approximating it through Material's ColorScheme
/// roles.
///
/// Four palettes live here, as two [AppThemeFlavor]s crossed with the two
/// brightnesses: [light]/[dark] are the classic pair, and
/// [quietRailsLight]/[quietRailsDark] are the Yello Design System's own
/// tables. Pick one with [resolve] rather than naming a constant — the named
/// constants exist for the handful of widgets that deliberately want a fixed
/// set regardless of the active theme (see `messages_page.dart`).
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

  /// "Quiet rails" light — the design system's light table, which re-points
  /// the same roles the dark set defines rather than being drawn on its own.
  /// Neutral greys throughout (no warm cast anywhere), a pure-white card on a
  /// faintly grey canvas, and the yellow split in two: [yel] stays the
  /// saturated fill while [yeld] darkens to olive, which is the only way the
  /// accent holds 4.5:1 as *text* on a light ground.
  ///
  /// Two tokens have no direct counterpart in the source table and are
  /// derived here, both noted at their line: [line2] and [shell].
  static const quietRailsLight = AppColors(
    bg: Color(0xFFF7F7F5), // color-background
    surf: Color(0xFFFFFFFF), // color-surface-container-lowest
    // color-surface-container-low ("hover rows, input wells"), not
    // -high (#E4E4E0): against a pure-white card the high step reads as a
    // grey box rather than an inset, and `surf2` is mostly inset panels here.
    surf2: Color(0xFFF1F1EE),
    ink: Color(0xFF16181B), // color-on-surface
    ink2: Color(0xFF5C6470), // color-on-surface-variant
    ink3: Color(0xFF8A919C), // color-outline — ~3:1, so 13px+ metadata only
    line: Color(0xFFE2E2DE), // color-outline-variant (surfaces and dividers)
    // Derived: the midpoint between `line` and `surf`. The source table has
    // no token below outline-variant, and outline-strong (#D4D4CF) is the
    // *heavier* control border, so it can't stand in for the faint
    // inside-a-card divider `line2` means.
    line2: Color(0xFFF0F0EE),
    yel: Color(0xFFFFD60A), // color-primary-container
    yelb: Color(0xFFFFF2B8), // color-primary-fixed
    yeld: Color(0xFF7A6300), // color-primary — olive, for contrast on light
    onYel: Color(0xFF1A1400), // color-on-primary-container
    red: Color(0xFFBA1A1A), // color-error
    grn: Color(0xFF1B7A3F), // color-tertiary
    // Derived: `shell` is the one surface that stays dark in *both* themes
    // (ADR-009, and `messages_page.dart` paints fixed light ink on it), so
    // color-chrome's light value (#FBFBF9) can't be used. The light ramp's
    // darkest neutral stands in instead.
    shell: Color(0xFF16181B),
    slot: Color(0xFFEBEBE8), // color-surface-container
  );

  /// "Quiet rails" dark — the design system's default theme, and the one its
  /// light set is derived from. Near-black canvas, cards a single tonal step
  /// above it, and hairlines doing the separating work that shadow does
  /// elsewhere.
  static const quietRailsDark = AppColors(
    bg: Color(0xFF0B0B0C), // color-background
    surf: Color(0xFF0F0F12), // color-surface-container-lowest
    // color-surface-container-high. Dark needs the larger step its light
    // counterpart doesn't: -low (#131317) is barely off `surf` here.
    surf2: Color(0xFF1E1E24),
    ink: Color(0xFFF2F2F0), // color-on-surface
    ink2: Color(0xFF9C9CA2), // color-on-surface-variant
    ink3: Color(0xFF8A8A90), // color-outline
    line: Color(0xFF1C1C20), // color-outline-variant
    line2: Color(0xFF151519), // derived, as in [quietRailsLight]
    yel: Color(0xFFFFCE2B), // color-primary-container
    // color-primary-fixed-*dim*, not -fixed (#1A1A16): the plain tint is
    // within ~1% of `surf`, which would make a selected chip invisible. The
    // source calls -dim "a slightly stronger accent wash", which is exactly
    // what `yelb` is used for here.
    yelb: Color(0xFF2A2716),
    yeld: Color(0xFFFFCE2B), // color-primary — no darkening needed on dark
    onYel: Color(0xFF12120F), // color-on-primary-container
    red: Color(0xFFFF5D5D), // color-error
    grn: Color(0xFF3DDC84), // color-tertiary
    shell: Color(0xFF0E0E10), // color-chrome
    slot: Color(0xFF16161A), // color-surface-container
  );

  /// The palette for a ([AppThemeFlavor], [Brightness]) pair — the single
  /// place the four sets are selected from.
  static AppColors resolve(AppThemeFlavor flavor, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (flavor) {
      AppThemeFlavor.classic => isDark ? dark : light,
      AppThemeFlavor.quietRails => isDark ? quietRailsDark : quietRailsLight,
    };
  }

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
  static AppColors of(BuildContext context) => Theme.of(context).extension<AppColors>() ?? light;
}
