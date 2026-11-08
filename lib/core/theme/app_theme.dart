// ThemeData for Ludo Mela: a game look on top of Material 3.
//
// Why a thin theme: the game draws its own buttons, panels and dialogs (the
// kit in core/widgets), so Material only supplies text defaults, the scaffold
// colour and the things we do not repaint (text selection, tooltips,
// scrollbars). Ink splashes are switched off — the kit's sink-on-press is the
// only touch feedback — and fonts come from AppFonts alone.

import 'package:flutter/material.dart';

import 'colors.dart';
import 'fonts.dart';

/// The one ThemeData of the app (dark, game blue).
ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF47BA2B),
    onPrimary: LmColors.white,
    secondary: Color(0xFFFFC61F),
    onSecondary: LmColors.inkOnGold,
    tertiary: Color(0xFF8B55F0),
    onTertiary: LmColors.white,
    error: LmColors.badgeRed,
    onError: LmColors.white,
    surface: LmColors.panelLo,
    onSurface: LmColors.white,
    surfaceContainerHighest: LmColors.well,
    outline: LmColors.panelRim,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
  final text = _withWeightAxis(
    base.textTheme.apply(
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.fallback,
      bodyColor: LmColors.white,
      displayColor: LmColors.white,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: LmColors.deep,
    canvasColor: LmColors.deep,
    textTheme: text,
    primaryTextTheme: text,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    dividerColor: const Color(0x14FFFFFF),
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    iconTheme: const IconThemeData(color: LmColors.white),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Color(0xFFFFC61F),
      selectionColor: Color(0x66FFC61F),
      selectionHandleColor: Color(0xFFFFC61F),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: LmColors.navy, borderRadius: BorderRadius.circular(8)),
      textStyle: AppFonts.bodyStyle(size: 12, weight: FontWeight.w700, color: LmColors.white),
    ),
    scrollbarTheme: const ScrollbarThemeData(thickness: WidgetStatePropertyAll(0)),
  );
}

/// Baloo 2 is a variable font: every Material text style also sets the `wght`
/// axis to its own weight, so Material widgets (fields, dialogs, tooltips) match
/// the kit instead of drawing the default instance.
TextTheme _withWeightAxis(TextTheme t) {
  TextStyle? axis(TextStyle? s) => s?.copyWith(fontVariations: AppFonts.weightAxis(s.fontWeight ?? FontWeight.w400));
  return t.copyWith(
    displayLarge: axis(t.displayLarge),
    displayMedium: axis(t.displayMedium),
    displaySmall: axis(t.displaySmall),
    headlineLarge: axis(t.headlineLarge),
    headlineMedium: axis(t.headlineMedium),
    headlineSmall: axis(t.headlineSmall),
    titleLarge: axis(t.titleLarge),
    titleMedium: axis(t.titleMedium),
    titleSmall: axis(t.titleSmall),
    bodyLarge: axis(t.bodyLarge),
    bodyMedium: axis(t.bodyMedium),
    bodySmall: axis(t.bodySmall),
    labelLarge: axis(t.labelLarge),
    labelMedium: axis(t.labelMedium),
    labelSmall: axis(t.labelSmall),
  );
}
