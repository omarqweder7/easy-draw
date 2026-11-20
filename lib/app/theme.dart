import 'package:material_ui/material_ui.dart';

import '../design/tokens.dart';

/// Builds ThemeData from the Easy Draw tokens. Custom components carry most of
/// the styling; this makes any remaining framework widget match as well.
class EDTheme {
  static ThemeData build(EDPalette p, String lang) {
    final t = EDText.build(p, lang);
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.isDark ? p.accent : p.accentText,
      onPrimary: p.isDark ? p.onAccent : Colors.white,
      primaryContainer: p.accentSoft,
      onPrimaryContainer: p.text,
      secondary: p.textMuted,
      onSecondary: p.bg,
      secondaryContainer: p.elevated,
      onSecondaryContainer: p.text,
      tertiary: p.accent,
      onTertiary: p.onAccent,
      error: p.danger,
      onError: p.onDanger,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.textMuted,
      surfaceContainerLowest: p.bg,
      surfaceContainerLow: p.bg,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.elevated,
      surfaceContainerHighest: p.elevated,
      outline: p.borderStrong,
      outlineVariant: p.border,
      scrim: p.scrim,
      shadow: Colors.black,
      inverseSurface: p.text,
      onInverseSurface: p.bg,
      inversePrimary: p.accentText,
    );
    final control = RoundedRectangleBorder(borderRadius: Radii.controlR);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: p.brightness);
    return base.copyWith(
      extensions: [p, t],
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      splashFactory: InkSparkle.constantTurbulenceSeedSplashFactory,
      highlightColor: p.text.withValues(alpha: 0.04),
      splashColor: p.text.withValues(alpha: 0.08),
      hoverColor: p.text.withValues(alpha: 0.04),
      focusColor: p.accent.withValues(alpha: 0.18),
      textTheme: base.textTheme.copyWith(
        displaySmall: t.display,
        headlineSmall: t.headline,
        titleLarge: t.title,
        titleMedium: t.titleSm,
        titleSmall: t.label,
        bodyLarge: t.body,
        bodyMedium: t.body,
        bodySmall: t.bodySm,
        labelLarge: t.label,
        labelMedium: t.labelSm,
        labelSmall: t.caption,
      ),
      iconTheme: IconThemeData(color: p.text, size: Sizes.iconSize),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.isDark ? p.accent : p.accentText,
        selectionColor: p.accent.withValues(alpha: 0.35),
        selectionHandleColor: p.isDark ? p.accent : p.accentText,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: p.isDark ? p.elevated : p.text, borderRadius: Radii.tagR, border: Border.all(color: p.border)),
        textStyle: t.labelSm.copyWith(color: p.isDark ? p.text : p.bg),
        padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.xs),
        waitDuration: const Duration(milliseconds: 400),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? p.elevated : p.text,
        contentTextStyle: t.bodySm.copyWith(color: p.isDark ? p.text : p.bg),
        actionTextColor: p.isDark ? p.accent : p.accent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: Radii.cardR, side: BorderSide(color: p.isDark ? p.border : Colors.transparent)),
        insetPadding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.m),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.isDark ? p.accent : p.accentText,
        linearTrackColor: p.border,
        circularTrackColor: p.border,
        linearMinHeight: 3,
      ),
      scrollbarTheme: ScrollbarThemeData(thumbColor: WidgetStatePropertyAll(p.borderStrong), radius: const Radius.circular(2)),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: p.scrim,
        showDragHandle: false,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        barrierColor: p.scrim,
        shape: RoundedRectangleBorder(borderRadius: Radii.cardR, side: BorderSide(color: p.border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: t.body.copyWith(color: p.textFaint),
        labelStyle: t.bodySm,
        border: OutlineInputBorder(borderRadius: Radii.controlR, borderSide: BorderSide(color: p.border)),
        enabledBorder: OutlineInputBorder(borderRadius: Radii.controlR, borderSide: BorderSide(color: p.border)),
        focusedBorder: OutlineInputBorder(borderRadius: Radii.controlR, borderSide: BorderSide(color: p.isDark ? p.accent : p.accentText, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.border,
        thumbColor: p.accent,
        overlayColor: p.accent.withValues(alpha: 0.16),
        trackHeight: 4,
        valueIndicatorColor: p.elevated,
        valueIndicatorTextStyle: t.numeric,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: Radii.cardR, side: BorderSide(color: p.border)),
        textStyle: t.body,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: EDPageTransitions(),
        TargetPlatform.iOS: EDPageTransitions(),
      }),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      // Framework buttons are rarely used directly; keep them on-brand anyway.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          minimumSize: const Size(64, Sizes.touch),
          shape: control,
          textStyle: t.label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.accentText, minimumSize: const Size(48, Sizes.touch), shape: control, textStyle: t.label),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: p.text, minimumSize: const Size(Sizes.touch, Sizes.touch))),
    );
  }
}

/// Subtle 200 ms fade + short slide, replaced by an instant switch when the
/// user asks for reduced motion.
class EDPageTransitions extends PageTransitionsBuilder {
  const EDPageTransitions();

  @override
  Duration get transitionDuration => Motion.base;

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final a = CurvedAnimation(parent: animation, curve: Motion.curve);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }
}
