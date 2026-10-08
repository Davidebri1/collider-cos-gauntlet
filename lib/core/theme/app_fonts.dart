import 'dart:ui' as ui show FontFeature, Shadow;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bundled-safe typography for the two display families the app uses.
///
/// The Smart Gen surfaces were authored against a small `AppFonts` facade so
/// they never reach for the network mid-build. v8.4 ships the families through
/// `google_fonts` (already a dependency, already cached by the service worker),
/// so this is the same facade backed by those families rather than by font
/// files in `assets/fonts`.
///
/// The named parameters mirror [TextStyle]'s constructor so every call site
/// reads the same as it did against the original.
class AppFonts {
  AppFonts._();

  static TextStyle instrumentSans({
    bool inherit = true,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    ui.Shadow? shadow,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    List<String>? fontFamilyFallback,
    String? debugLabel,
    Locale? locale,
  }) {
    return _tune(
      GoogleFonts.instrumentSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        wordSpacing: wordSpacing,
        textBaseline: textBaseline,
        height: height,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        decorationThickness: decorationThickness,
      ),
      inherit: inherit,
      color: color,
      backgroundColor: backgroundColor,
      shadow: shadow,
      shadows: shadows,
      fontFeatures: fontFeatures,
      fontFamilyFallback: fontFamilyFallback,
      debugLabel: debugLabel,
      locale: locale,
    );
  }

  static TextStyle cormorantGaramond({
    bool inherit = true,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    ui.Shadow? shadow,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    List<String>? fontFamilyFallback,
    String? debugLabel,
    Locale? locale,
  }) {
    return _tune(
      GoogleFonts.cormorantGaramond(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        wordSpacing: wordSpacing,
        textBaseline: textBaseline,
        height: height,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        decorationThickness: decorationThickness,
      ),
      inherit: inherit,
      color: color,
      backgroundColor: backgroundColor,
      shadow: shadow,
      shadows: shadows,
      fontFeatures: fontFeatures,
      fontFamilyFallback: fontFamilyFallback,
      debugLabel: debugLabel,
      locale: locale,
    );
  }

  static TextStyle _tune(
    TextStyle base, {
    required bool inherit,
    Color? color,
    Color? backgroundColor,
    ui.Shadow? shadow,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    List<String>? fontFamilyFallback,
    String? debugLabel,
    Locale? locale,
  }) {
    return base.copyWith(
      inherit: inherit,
      color: color,
      backgroundColor: backgroundColor,
      shadows: shadows ?? (shadow == null ? null : [shadow]),
      fontFeatures: fontFeatures,
      fontFamilyFallback: fontFamilyFallback,
      debugLabel: debugLabel,
      locale: locale,
    );
  }

  /// Applies the display family across a text theme.
  static TextTheme instrumentSansTextTheme([TextTheme? base]) {
    return (base ?? ThemeData.dark().textTheme).apply(fontFamily: 'Instrument Sans');
  }
}