import 'package:flutter/material.dart';

import 'app_colors.dart';

/// How surfaces are *drawn*, as opposed to what color they are ([AppColors]).
///
/// [AppThemeFlavor.ink] keeps the classic palette but swaps the soft chrome for
/// a bold one: a 2px ink outline on every card and button, and a hard offset
/// shadow under it. [AppThemeFlavor.pchumBen] keeps the soft chrome and adds
/// festival ornaments on top of it. The other flavors are the plain soft look.
/// Exposed as a [ThemeExtension] next to [AppColors] so a widget asks "am I
/// outlined?" or "do I draw the festival ornament?" the same way it asks for a
/// color, instead of switching on the flavor itself.
///
/// Every shadow built here has **zero blur** — a solid, offset copy of the
/// shape. That is deliberate: a blurred `BoxShadow` in a rebuilding widget
/// crashed this project's Impeller renderer (docs/GOTCHAS.md), and a hard
/// shadow is also simply what the look calls for.
@immutable
class AppStyle extends ThemeExtension<AppStyle> {
  const AppStyle({required this.outlined, this.pchumBen = false});

  /// The soft look: hairline borders, blurred card shadows (ADR-012).
  static const soft = AppStyle(outlined: false);

  /// The ink-outline look (ADR-050).
  static const ink = AppStyle(outlined: true);

  /// The soft look plus the Pchum Ben ornaments (ADR-057).
  static const festive = AppStyle(outlined: false, pchumBen: true);

  final bool outlined;

  /// Whether the Pchum Ben ornaments are drawn: the lotus-petal friezes, the
  /// skylines, the greeting card. They live in
  /// `shared/widgets/pchum_ben_ornaments.dart`; every call site is behind
  /// this flag, so the other flavors render exactly what they did before.
  final bool pchumBen;

  /// Card offset — posts, profile header, details, settings groups.
  static const double cardOffset = 5;

  /// Pill containers — the create-post prompt, inputs, segmented tabs.
  static const double pillOffset = 4;

  /// Buttons and round icon buttons.
  static const double buttonOffset = 3;

  /// Small filled things — an active chip, an unread badge.
  static const double chipOffset = 2;

  static AppStyle resolve(AppThemeFlavor flavor) => switch (flavor) {
    AppThemeFlavor.ink => ink,
    AppThemeFlavor.pchumBen => festive,
    AppThemeFlavor.classic || AppThemeFlavor.quietRails => soft,
  };

  static AppStyle of(BuildContext context) => Theme.of(context).extension<AppStyle>() ?? soft;

  /// Outline width for cards and buttons. The soft look's 1.5 is the width
  /// every hairline in the app already uses.
  double get borderWidth => outlined ? 2 : 1.5;

  /// A solid, unblurred copy of the shape offset down-right by [offset], in
  /// [color] — by default the `shell` token, the app's near-black, so the
  /// shadow stays black in dark mode too, under cream outlines (a cream one
  /// read as a glow). Empty in the soft look, so a caller can pass it
  /// straight to `boxShadow:`.
  List<BoxShadow> hardShadow(AppColors colors, double offset, {Color? color}) => outlined
      ? [BoxShadow(color: color ?? colors.shell, offset: Offset(offset, offset))]
      : const [];

  @override
  AppStyle copyWith({bool? outlined, bool? pchumBen}) =>
      AppStyle(outlined: outlined ?? this.outlined, pchumBen: pchumBen ?? this.pchumBen);

  /// A switch rather than a blend: a half-drawn outline or half an ornament
  /// has no meaning, so the theme change flips it at the midpoint of
  /// `MaterialApp`'s crossfade.
  @override
  AppStyle lerp(ThemeExtension<AppStyle>? other, double t) {
    if (other is! AppStyle) return this;
    return t < 0.5 ? this : other;
  }
}
