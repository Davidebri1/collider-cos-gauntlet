import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum SpatialDepthPlane {
  /// Plane 0: Base Cosmos / Live Wallpaper
  base,

  /// Plane 1: Base / Prompt
  basePrompt,

  /// Plane 2: Resting Content Canvas (collapsed pills, base window)
  resting,

  /// Plane 3: Elevated Active Layer (expanded accordion, flyouts)
  elevated,

  /// Plane 4: Detached Ornaments & Focused Modals (nav capsule, zoom, popups)
  modal,

  /// Plane 5: Durable Full-Height Work Surfaces (Smart Gen, Marketplace, Consensus)
  workSurface,
}

class SpatialTheme {
  /// Optical blur sigma per depth plane according to Master Spec Table 2.1
  static double blurSigma(SpatialDepthPlane plane) {
    switch (plane) {
      case SpatialDepthPlane.base:
        return 0.0;
      case SpatialDepthPlane.basePrompt:
        return 16.0;
      case SpatialDepthPlane.resting:
        return 24.0;
      case SpatialDepthPlane.elevated:
        return 28.0;
      case SpatialDepthPlane.modal:
        return 32.0;
      case SpatialDepthPlane.workSurface:
        return 36.0;
    }
  }

  /// Translucent glass background tint per depth plane
  static Color glassBackground(SpatialDepthPlane plane) {
    switch (plane) {
      case SpatialDepthPlane.base:
        return Colors.transparent;
      case SpatialDepthPlane.basePrompt:
        return const Color(0x18FFFFFF);
      case SpatialDepthPlane.resting:
        return const Color(0x1EFFFFFF);
      case SpatialDepthPlane.elevated:
        return const Color(0x24FFFFFF);
      case SpatialDepthPlane.modal:
        return const Color(0x28FFFFFF);
      case SpatialDepthPlane.workSurface:
        return const Color(0x2CFFFFFF);
    }
  }

  /// Specular rim border opacity per depth plane
  static Color rimBorderColor(SpatialDepthPlane plane) {
    switch (plane) {
      case SpatialDepthPlane.base:
        return Colors.transparent;
      case SpatialDepthPlane.basePrompt:
      case SpatialDepthPlane.resting:
        return Colors.white.withOpacity(0.18);
      case SpatialDepthPlane.elevated:
        return Colors.white.withOpacity(0.24);
      case SpatialDepthPlane.modal:
        return Colors.white.withOpacity(0.28);
      case SpatialDepthPlane.workSurface:
        return Colors.white.withOpacity(0.32);
    }
  }

  /// Ambient occlusion drop shadow per depth plane
  static List<BoxShadow> ambientShadow(SpatialDepthPlane plane) {
    switch (plane) {
      case SpatialDepthPlane.base:
        return const [];
      case SpatialDepthPlane.basePrompt:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ];
      case SpatialDepthPlane.resting:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ];
      case SpatialDepthPlane.elevated:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ];
      case SpatialDepthPlane.modal:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.32),
            blurRadius: 48,
            offset: const Offset(0, 20),
          ),
        ];
      case SpatialDepthPlane.workSurface:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.36),
            blurRadius: 56,
            offset: const Offset(0, 24),
          ),
        ];
    }
  }
}

/// Universal, adult typography system: Regal cinematic display paired with
/// crystal-clear human-centered editorial readability. Zero cyberpunk or terminal fonts.
class SpatialTypography {
  /// Regal cinematic display header (app name, section titles, hero prompts)
  static TextStyle cinematicDisplay({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w600,
    Color color = Colors.white,
    double letterSpacing = 0.4,
  }) {
    return GoogleFonts.cormorantGaramond(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Primary UI title & window headers (timeless, authoritative, zero cyberpunk)
  static TextStyle windowTitle({
    double fontSize = 14.5,
    FontWeight fontWeight = FontWeight.w600,
    Color color = Colors.white,
    double letterSpacing = -0.2,
  }) {
    return GoogleFonts.instrumentSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// 1-Sentence Takeaways & Model Answers (adult, pure, high-legibility)
  static TextStyle summaryText({
    double fontSize = 12.5,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double height = 1.40,
  }) {
    return GoogleFonts.instrumentSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? Colors.white.withOpacity(0.92),
      height: height,
      letterSpacing: -0.1,
    );
  }

  /// Secondary callouts, timestamps, subtle status
  static TextStyle caption({
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) {
    return GoogleFonts.instrumentSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? Colors.white.withOpacity(0.55),
      letterSpacing: -0.1,
    );
  }
}
