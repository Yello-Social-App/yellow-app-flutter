import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography scale lifted from the Yello Mobile v2 design source.
///
/// The mockup uses two families:
/// - **Geist** — display headings, names, buttons (weights 500-900), plus
///   the uppercase eyebrow / meta / timestamp labels the design source sets
///   in Geist Mono — the mono face was dropped app-wide in favour of Geist.
/// - **Nunito** — body copy, inputs (swapped in app-wide for Inter).
///
/// Every size in the app comes from a named step here. A `copyWith(fontSize:)`
/// at a call site is drift — the same kind of title ended up 13, 14, 15, 16 and
/// 17px across screens that way — so add a step instead of overriding one.
///
/// Styles are defined WITHOUT color; apply the token color via `copyWith`
/// (usually `AppColors.of(context).ink` / `.ink2` / `.ink3`).
abstract final class AppTextStyles {
  static TextStyle get _geistBase => GoogleFonts.geist();
  static TextStyle get _nunitoBase => GoogleFonts.nunito();

  /// "Circle.", "Inbox.", "Signals." page-level display heading (Feed's own
  /// used to read "Today." at this style too, before its header swapped to
  /// `YelloWordmark` — see that widget and `FeedPage._Header`).
  /// `font:800 34px/.95 Geist,sans-serif;letter-spacing:-.045em`
  static const double displayXlFontSize = 34;
  static TextStyle get displayXl => _geistBase.copyWith(
    fontSize: displayXlFontSize,
    height: 0.95,
    fontWeight: FontWeight.w800,
    letterSpacing: -displayXlFontSize * 0.045,
  );

  /// Profile name / story caption large display.
  /// `font:800 26-29px Geist;letter-spacing:-.04em`
  static TextStyle get displayLg => _geistBase.copyWith(
    fontSize: 26,
    height: 1.05,
    fontWeight: FontWeight.w800,
    letterSpacing: -26 * 0.04,
  );

  /// "New post" sheet title, stat values.
  /// `font:800 20px Geist;letter-spacing:-.03em`
  static const double titleLgFontSize = 20;
  static TextStyle get titleLg => _geistBase.copyWith(
    fontSize: titleLgFontSize,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -titleLgFontSize * 0.03,
  );

  /// Post author name, conversation name, comment name.
  /// `font:700 14-15px Geist;letter-spacing:-.012em`
  static TextStyle get titleMd => _geistBase.copyWith(
    fontSize: 14,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -14 * 0.012,
  );

  /// Card / thread headline — a post, project or community card's title.
  /// One step up from [titleMd], which is the author/row-name size.
  /// `font:700 16px Geist`
  static TextStyle get titleCard =>
      titleMd.copyWith(fontSize: 16, letterSpacing: -16 * 0.012);

  /// List-row name — conversation rows, reactor rows, snackbar titles.
  /// `font:700 15px Geist`
  static TextStyle get titleRow =>
      titleMd.copyWith(fontSize: 15, letterSpacing: -15 * 0.012);

  /// Avatar initials / small bold labels.
  static TextStyle get titleSm =>
      _geistBase.copyWith(fontSize: 12, height: 1, fontWeight: FontWeight.w800);

  /// Button label (pill CTAs like "Accept", "Follow", "PUBLISH").
  /// `font:700 11-13px Geist`
  static TextStyle get button =>
      _geistBase.copyWith(fontSize: 12, height: 1, fontWeight: FontWeight.w700);

  /// Quote-card display text.
  /// `font:800 23px/1.18 Geist;letter-spacing:-.035em`
  static TextStyle get quote => _geistBase.copyWith(
    fontSize: 23,
    height: 1.18,
    fontWeight: FontWeight.w800,
    letterSpacing: -23 * 0.035,
  );

  /// Larger pill CTA label — the auth screens' primary buttons and the
  /// Rooms tab bar, where a 12px label reads undersized against a full-width
  /// control. `font:700 13px Geist`
  static TextStyle get buttonLg => button.copyWith(fontSize: 13);

  /// Uppercase eyebrow label ("STORIES", "REQUESTS", section headers).
  /// `font:600 10.5-11px Geist;letter-spacing:.16em;uppercase`
  static TextStyle get eyebrow => _geistBase.copyWith(
    fontSize: 11,
    height: 1,
    fontWeight: FontWeight.w600,
    letterSpacing: 11 * 0.16,
  );

  /// Smaller meta line (post meta, timestamps, nav labels). The `Mono` in
  /// the name is historical — it's set in Geist like everything else.
  /// `font:500 9-10.5px Geist;letter-spacing:.09-.13em;uppercase`
  static TextStyle get metaMono => _geistBase.copyWith(
    fontSize: 10.5,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: 10.5 * 0.1,
  );

  /// Micro meta label — tag pills, card meta, counters: the 9px step the
  /// design uses wherever [metaMono] would crowd its container.
  static TextStyle get metaMonoSm =>
      metaMono.copyWith(fontSize: 9, letterSpacing: 9 * 0.1);

  /// Tiny nav-bar label.
  static TextStyle get navLabel => _geistBase.copyWith(
    fontSize: 10,
    height: 1,
    fontWeight: FontWeight.w600,
    letterSpacing: 10 * 0.06,
  );

  /// Body copy ("Nunito"), e.g. post captions, comment text.
  /// `font:400 14-16px/1.45-1.55 Nunito`
  static TextStyle get body => _nunitoBase.copyWith(
    fontSize: 15,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  /// Smaller body copy (comment bubbles, sub-captions).
  static TextStyle get bodySm => _nunitoBase.copyWith(
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  /// Body copy one step up from [bodySm] — auth helper text, profile bios,
  /// dialog copy. `font:400 14px Nunito`
  static TextStyle get bodyMd => bodySm.copyWith(fontSize: 14);

  /// Placeholder / hint text inside inputs.
  static TextStyle get hint => _nunitoBase.copyWith(
    fontSize: 14,
    height: 1,
    fontWeight: FontWeight.w400,
  );
}
