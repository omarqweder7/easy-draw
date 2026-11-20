import 'package:material_ui/material_ui.dart';

/// Easy Draw design tokens: the single source of truth for colour, type,
/// spacing, radii and motion. Components read these through `context.ds`
/// and `context.text`; screens should not hard-code visual values.

// ---------------------------------------------------------------------------
// Colour
// ---------------------------------------------------------------------------

@immutable
class EDPalette extends ThemeExtension<EDPalette> {
  const EDPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.elevated,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.accentSoft,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.border,
    required this.borderStrong,
    required this.danger,
    required this.onDanger,
    required this.warning,
    required this.panel,
    required this.scrim,
    required this.paper,
  });

  final Brightness brightness;
  final Color bg; // app background
  final Color surface; // cards, bars
  final Color elevated; // raised controls, sheets
  final Color accent; // electric lime: primary actions & active states only
  final Color onAccent; // text/icons on lime (always dark)
  final Color accentText; // lime-family colour that is readable as text on bg
  final Color accentSoft; // faint accent tint for selected surfaces
  final Color text;
  final Color textMuted;
  final Color textFaint; // disabled / tertiary
  final Color border;
  final Color borderStrong;
  final Color danger;
  final Color onDanger;
  final Color warning;
  final Color panel; // translucent workspace panels
  final Color scrim;
  final Color paper; // reference "paper" behind line art

  bool get isDark => brightness == Brightness.dark;

  /// Graphite (default) — matches the app icon.
  static const dark = EDPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF101418),
    surface: Color(0xFF1B2228),
    elevated: Color(0xFF252E36),
    accent: Color(0xFFBAFF32),
    onAccent: Color(0xFF0E1400),
    accentText: Color(0xFFBAFF32),
    accentSoft: Color(0x1FBAFF32),
    text: Color(0xFFF4F7F5),
    textMuted: Color(0xFFA7B2AC),
    textFaint: Color(0xFF6E7A74),
    border: Color(0xFF344039),
    borderStrong: Color(0xFF4A574F),
    danger: Color(0xFFFF6E5E),
    onDanger: Color(0xFF240400),
    warning: Color(0xFFFFC857),
    panel: Color(0xE6101418),
    scrim: Color(0x99060809),
    paper: Color(0xFFF4F7F5),
  );

  /// Light "paper" variant for people who prefer a light interface.
  static const light = EDPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF1F3F0),
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFE6EAE5),
    accent: Color(0xFFBAFF32),
    onAccent: Color(0xFF0E1400),
    accentText: Color(0xFF3A6400),
    accentSoft: Color(0x33BAFF32),
    text: Color(0xFF101418),
    textMuted: Color(0xFF4C5852),
    textFaint: Color(0xFF8A958F),
    border: Color(0xFFD2D9D3),
    borderStrong: Color(0xFFAEB9B2),
    danger: Color(0xFFC62828),
    onDanger: Color(0xFFFFFFFF),
    warning: Color(0xFF8A5A00),
    panel: Color(0xE6101418),
    scrim: Color(0x66060809),
    paper: Color(0xFFFFFFFF),
  );

  @override
  EDPalette copyWith() => this;

  @override
  EDPalette lerp(EDPalette? other, double t) => t < 0.5 ? this : (other ?? this);
}

// ---------------------------------------------------------------------------
// Spacing (8-point grid), radii, sizes, motion
// ---------------------------------------------------------------------------

abstract final class Space {
  static const double xxs = 4;
  static const double xs = 8;
  static const double s = 12;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Deliberately tight radii: angular, not pill-shaped.
abstract final class Radii {
  static const double tag = 4;
  static const double control = 8; // chips, inputs, small buttons
  static const double button = 10;
  static const double card = 12;
  static const double sheet = 18;

  static BorderRadius get tagR => BorderRadius.circular(tag);
  static BorderRadius get controlR => BorderRadius.circular(control);
  static BorderRadius get buttonR => BorderRadius.circular(button);
  static BorderRadius get cardR => BorderRadius.circular(card);
}

abstract final class Sizes {
  static const double touch = 48; // minimum touch target
  static const double buttonHeight = 52;
  static const double iconSize = 22;
  static const double stroke = 1; // border width
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 250);
  static const curve = Curves.easeOutCubic;

  /// Zero when the user or the OS asks for reduced motion.
  static Duration of(BuildContext context, [Duration d = base]) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}

// ---------------------------------------------------------------------------
// Typography
// ---------------------------------------------------------------------------

@immutable
class EDText extends ThemeExtension<EDText> {
  const EDText({
    required this.display,
    required this.headline,
    required this.title,
    required this.titleSm,
    required this.body,
    required this.bodySm,
    required this.label,
    required this.labelSm,
    required this.caption,
    required this.overline,
    required this.numeric,
  });

  final TextStyle display;
  final TextStyle headline;
  final TextStyle title;
  final TextStyle titleSm;
  final TextStyle body;
  final TextStyle bodySm;
  final TextStyle label;
  final TextStyle labelSm;
  final TextStyle caption;
  final TextStyle overline; // small caps-style section labels
  final TextStyle numeric; // slider values etc. (tabular figures)

  /// Space Grotesk for headings and Inter for text; Arabic uses Cairo and
  /// Hebrew uses Rubik throughout, since the Latin faces lack those scripts.
  factory EDText.build(EDPalette p, String lang) {
    final heading = switch (lang) { 'ar' => 'Cairo', 'he' => 'Rubik', _ => 'SpaceGrotesk' };
    final bodyFam = switch (lang) { 'ar' => 'Cairo', 'he' => 'Rubik', _ => 'Inter' };
    final latin = lang != 'ar' && lang != 'he';
    const fallback = ['Cairo', 'Rubik'];
    TextStyle s(String fam, double size, double w, {double h = 1.3, double ls = 0, Color? c}) => TextStyle(
          fontFamily: fam,
          fontFamilyFallback: fallback,
          fontSize: size,
          fontWeight: FontWeight.values[((w / 100).round() - 1).clamp(0, 8)],
          fontVariations: [FontVariation('wght', w)],
          height: h,
          letterSpacing: latin ? ls : 0,
          color: c ?? p.text,
        );
    return EDText(
      display: s(heading, 30, 700, h: 1.12, ls: -0.6),
      headline: s(heading, 24, 700, h: 1.18, ls: -0.3),
      title: s(heading, 19, 650, h: 1.25, ls: -0.1),
      titleSm: s(heading, 16, 600, h: 1.3),
      body: s(bodyFam, 15, 400, h: 1.5),
      bodySm: s(bodyFam, 13.5, 400, h: 1.45, c: p.textMuted),
      label: s(bodyFam, 15, 600, h: 1.2),
      labelSm: s(bodyFam, 13, 600, h: 1.2),
      caption: s(bodyFam, 12, 500, h: 1.3, c: p.textMuted),
      overline: s(heading, 12, 700, h: 1.2, ls: 1.2, c: p.textMuted),
      numeric: s(bodyFam, 13, 600, h: 1.2).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }

  @override
  EDText copyWith() => this;

  @override
  EDText lerp(EDText? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension DesignContext on BuildContext {
  EDPalette get ds => Theme.of(this).extension<EDPalette>() ?? EDPalette.dark;
  EDText get text => Theme.of(this).extension<EDText>()!;

  /// A size multiplied by the user's text scale (for fixed-height rows that
  /// contain text, e.g. horizontal chip lists).
  double scaled(double v) => MediaQuery.textScalerOf(this).scale(v);
}
