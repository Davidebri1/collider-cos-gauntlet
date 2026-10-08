import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:collider_flutter/core/theme/app_fonts.dart';

/// The Smart Gen visionOS glass kit.
///
/// Every recipe below is ported from the supplied Figma references
/// (measured via the Figma API, not guessed):
///
/// - Dark frosted window: the Photos VR window — dark scrim under a
///   white-gradient fill, background blur ~40, white gradient edge stroke,
///   generous corner radius, soft drop shadow.
/// - Light frosted toolbar: Frame 5 toolbar — pale #E9E9EE fill, white
///   stroke, radius 24, blur 34.
/// - Bottom segmented pill bar: the Photos floating toolbar — dark glass
///   capsule holding outline pill segments, the active segment filled.
/// - Menu Tabs: light capsule bar with separated tabs (Keynote ref).
/// - Menu rows: 44pt rows, icon + label, active row = white pill highlight.
/// - Icon rail: slim vertical glass capsule, active icon in a white circle.
/// - Cards: light frosted cards with header rows (Widgets Board ref).
/// - Accents: iOS system palette swatches.
///
/// Desktop radii are scaled for a phone screen but the proportions,
/// layering order, and material behavior are the reference's.
class SGGlass {
  SGGlass._();

  // ---------------- radii ----------------
  static const double rWindow = 28.0;
  static const double rToolbar = 20.0;
  static const double rCard = 16.0;
  static const double rMenu = 20.0;
  static const double rRow = 22.0;
  static const double rPill = 999.0;

  // ---------------- blurs ----------------
  static const double blurWindow = 42.0;
  static const double blurBar = 30.0;
  static const double blurCard = 24.0;
  static const double blurMenu = 36.0;

  // ---------------- fills ----------------
  /// Dark frosted panel fill (Photos VR window recipe).
  static const LinearGradient darkFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x40FFFFFF), Color(0x1AFFFFFF)],
  );

  /// Deep glass fill for floating bars on dark (Photos bottom toolbar).
  static const LinearGradient deepFill = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x59FFFFFF), Color(0x26FFFFFF)],
  );

  /// Light frosted card fill (Widgets Board card recipe).
  static const LinearGradient lightFill = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xE9FFFFFF)],
  );

  /// Pale toolbar fill (Frame 5 toolbar: #E9E9EE).
  static const LinearGradient paleFill = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xF2EDEDF2), Color(0xD9E4E4EE)],
  );

  /// The signature glass edge: white fading to transparent.
  static const LinearGradient edgeStroke = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xB3FFFFFF), Color(0x14FFFFFF), Color(0x40FFFFFF)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient edgeStrokeSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x66FFFFFF), Color(0x0AFFFFFF)],
  );

  // ---------------- shadows ----------------
  static const List<BoxShadow> windowShadow = [
    BoxShadow(color: Color(0x59000000), blurRadius: 36, offset: Offset(0, 14)),
  ];
  static const List<BoxShadow> barShadow = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 22, offset: Offset(0, 9)),
  ];
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x2B000000), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> liftShadow = [
    BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 14)),
  ];

  // ---------------- text ----------------
  static const Color ink = Color(0xFF1C1C1E);
  static const Color ink2 = Color(0xFF3A3A3C);
  static const Color ink3 = Color(0xFF6B6B70);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color paper2 = Color(0xB3FFFFFF);
  static const Color paper3 = Color(0x8CFFFFFF);

  // ---------------- system accents (measured swatches) ----------------
  static const Color sysRed = Color(0xFFFF453A);
  static const Color sysOrange = Color(0xFFFF9F0A);
  static const Color sysYellow = Color(0xFFFFD60A);
  static const Color sysGreen = Color(0xFF30D158);
  static const Color sysMint = Color(0xFF63E6E2);
  static const Color sysTeal = Color(0xFF40C8E0);
  static const Color sysCyan = Color(0xFF64D2FF);
  static const Color sysBlue = Color(0xFF0A84FF);
  static const Color sysIndigo = Color(0xFF5E5CE6);
  static const Color sysPurple = Color(0xFFBF5AF2);
  static const Color sysPink = Color(0xFFFF375F);
}

/// A frosted glass panel with the signature white-gradient edge stroke.
///
/// Layering (matches the reference construction): gradient border shell,
/// clipped backdrop blur, gradient fill, content.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final Gradient fill;
  final Gradient border;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry padding;

  const GlassPanel({
    super.key,
    required this.child,
    this.radius = SGGlass.rWindow,
    this.blur = SGGlass.blurWindow,
    this.fill = SGGlass.darkFill,
    this.border = SGGlass.edgeStroke,
    this.shadows = SGGlass.windowShadow,
    this.padding = EdgeInsets.zero,
  });

  /// The dark floating window (Photos VR recipe).
  const GlassPanel.window({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  })  : radius = SGGlass.rWindow,
        blur = SGGlass.blurWindow,
        fill = SGGlass.darkFill,
        border = SGGlass.edgeStroke,
        shadows = SGGlass.windowShadow;

  /// A floating bar (toolbar / filter bar / rail) — deeper glass, bar blur.
  const GlassPanel.bar({
    super.key,
    required this.child,
    this.radius = SGGlass.rPill,
    this.padding = EdgeInsets.zero,
  })  : blur = SGGlass.blurBar,
        fill = SGGlass.deepFill,
        border = SGGlass.edgeStrokeSoft,
        shadows = SGGlass.barShadow;

  /// A light frosted card (Widgets Board recipe) — dark ink content.
  const GlassPanel.card({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  })  : radius = SGGlass.rCard,
        blur = SGGlass.blurCard,
        fill = SGGlass.lightFill,
        border = SGGlass.edgeStrokeSoft,
        shadows = SGGlass.cardShadow;

  /// A dark glass menu (context menu recipe).
  const GlassPanel.menu({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(6),
  })  : radius = SGGlass.rMenu,
        blur = SGGlass.blurMenu,
        fill = SGGlass.darkFill,
        border = SGGlass.edgeStrokeSoft,
        shadows = SGGlass.barShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: border,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows,
      ),
      padding: const EdgeInsets.all(1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              gradient: fill,
              borderRadius: BorderRadius.circular(radius - 1),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A pressable wrapper with physical press feedback — the kit's
/// replacement for VisionPressable inside Smart Gen. Scales down slightly
/// and dims while pressed, then springs back.
class GlassPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;

  const GlassPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.95,
  });

  @override
  State<GlassPressable> createState() => _GlassPressableState();
}

class _GlassPressableState extends State<GlassPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.75 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

/// An inline text field in the kit's material. [light] renders for the
/// light frosted card surface (dark ink); otherwise for dark glass.
class GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final bool autofocus;
  final TextInputType keyboardType;
  final int maxLines;
  final int minLines;
  final bool light;
  final TextStyle? style;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final ValueChanged<PointerDownEvent>? onTapOutside;

  const GlassField({
    super.key,
    required this.controller,
    this.hintText,
    this.autofocus = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.minLines = 1,
    this.light = false,
    this.style,
    this.onSubmitted,
    this.onChanged,
    this.onTapOutside,
  });

  @override
  Widget build(BuildContext context) {
    final ink = light ? SGGlass.ink : Colors.white;
    final hint = light ? SGGlass.ink3 : Colors.white38;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      style: style ??
          AppFonts.instrumentSans(fontSize: 13, color: ink, height: 1.35),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppFonts.instrumentSans(fontSize: 13, color: hint),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: light
            ? const Color(0x0A000000)
            : Colors.white.withValues(alpha: 0.07),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(
            color: light
                ? const Color(0x14000000)
                : Colors.white.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(
            color: light
                ? SGGlass.sysBlue.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      onTapOutside: onTapOutside,
    );
  }
}

/// filled when selected (Photos toolbar segment recipe).
/// A pill segment button for floating bars — outline pill by default,
/// filled when selected (Photos toolbar segment recipe).
class GlassSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  const GlassSegment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.24)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(SGGlass.rPill),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppFonts.instrumentSans(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: Colors.white,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
