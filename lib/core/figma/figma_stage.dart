import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// v8.4 "scaled frame" method (David, Oct 5 3:49 PM): every screen is built at
/// its Figma frame's own logical size, with the frame's positions, sizes,
/// paddings, radii, font sizes and colours, and is then scaled as ONE unit so
/// [cropWidth] Figma px span the device width. Relative spacing is preserved
/// exactly; nothing is re-laid-out for "phone proportions".
///
/// The stage maps a phone-shaped crop of the Figma frame onto the screen:
/// scale s = screenWidth / cropWidth, crop height = screenHeight / s, crop
/// centred on [center] (Figma frame coordinates). Children are positioned in
/// frame coordinates (use [Positioned] with Figma x / y / w / h).
class FigmaStage extends StatelessWidget {
  const FigmaStage({
    super.key,
    required this.frame,
    required this.cropWidth,
    required this.center,
    required this.children,
    this.clip = true,
  });

  /// The Figma frame's size (for the layout box of the children).
  final Size frame;

  /// How many Figma px span the device width.
  final double cropWidth;

  /// Crop centre in frame coordinates.
  final Offset center;
  final List<Widget> children;
  final bool clip;

  static double scaleFor(Size screen, double cropWidth) => screen.width / cropWidth;

  /// Maps a Figma frame-coordinate rect to a screen rect for this stage.
  static Rect mapRect(Size screen, double cropWidth, Offset center, Rect r) {
    final s = screen.width / cropWidth;
    final ox = center.dx - cropWidth / 2;
    final oy = center.dy - screen.height / s / 2;
    return Rect.fromLTWH((r.left - ox) * s, (r.top - oy) * s, r.width * s, r.height * s);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final s = c.maxWidth / cropWidth;
      final ox = center.dx - cropWidth / 2;
      final oy = center.dy - c.maxHeight / s / 2;
      final m = Matrix4.identity()
        ..scale(s, s, 1)
        ..translate(-ox, -oy);
      Widget body = OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: 0,
        minHeight: 0,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Transform(
          transform: m,
          child: SizedBox(
            width: frame.width,
            height: frame.height,
            child: FigmaScale(
              scale: s,
              child: Stack(clipBehavior: Clip.none, children: children),
            ),
          ),
        ),
      );
      if (clip) body = ClipRect(child: body);
      return SizedBox(width: c.maxWidth, height: c.maxHeight, child: body);
    });
  }
}

/// A frame of fixed logical size scaled as one unit to the available width
/// (factor = available width / frame width). Used for overlays and sheets:
/// the parent anchors it (e.g. Align bottomCenter) like the Figma frame.
class FigmaBox extends StatelessWidget {
  const FigmaBox({super.key, required this.size, required this.child, this.widthFraction = 1});
  final Size size;
  final Widget child;

  /// Fraction of the available width the frame spans (Figma frame / Figma screen).
  final double widthFraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final s = c.maxWidth * widthFraction / size.width;
      return SizedBox(
        width: size.width * s,
        height: size.height * s,
        child: FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(size: size, child: FigmaScale(scale: s, child: child)),
        ),
      );
    });
  }
}

/// Publishes the current stage scale (so e.g. blur sigmas can be expressed in
/// Figma px and converted).
class FigmaScale extends InheritedWidget {
  const FigmaScale({super.key, required this.scale, required super.child});
  final double scale;
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FigmaScale>()?.scale ?? 1;
  @override
  bool updateShouldNotify(FigmaScale old) => old.scale != scale;
}

/// visionOS "Windows/Glass" material as exported by Figma:
/// fill rgba(128,128,128,0.3) (luminosity blend), background blur, optional
/// 1 px rgba(255,255,255,0.4) stroke. All values in Figma px.
class FGlass extends StatelessWidget {
  const FGlass({
    super.key,
    this.radius = BorderRadius.zero,
    this.fill = const Color(0x4D808080),
    this.blur = 50,
    this.stroke,
    this.strokeWidth = 1,
    this.gradient,
    this.shadow,
    this.padding,
    this.width,
    this.height,
    this.child,
  });
  final BorderRadius radius;
  final Color fill;
  final double blur;
  final Color? stroke;
  final double strokeWidth;
  final Gradient? gradient;
  final List<BoxShadow>? shadow;
  final EdgeInsets? padding;
  final double? width, height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final s = FigmaScale.of(context);
    // CSS backdrop-blur(Npx) ~ Gaussian sigma N/2 in Flutter terms; the
    // backdrop filter runs in device space, so convert from Figma px.
    final sigma = (blur / 2 * s).clamp(0.0, 60.0);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(borderRadius: radius, boxShadow: shadow),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: gradient == null ? fill : null,
              gradient: gradient,
              borderRadius: radius,
              border: stroke == null ? null : Border.all(color: stroke!, width: strokeWidth),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Text helper in Figma px (font size / line height / weight / opacity).
class FText extends StatelessWidget {
  const FText(this.text,
      {super.key,
      this.size = 16,
      this.height,
      this.weight = FontWeight.w400,
      this.color = Colors.white,
      this.opacity = 1,
      this.align,
      this.maxLines = 1,
      this.ellipsis = true,
      this.letterSpacing});
  final String text;
  final double size;
  final double? height;
  final FontWeight weight;
  final Color color;
  final double opacity;
  final TextAlign? align;
  final int? maxLines;
  final bool ellipsis;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      softWrap: maxLines != 1,
      overflow: ellipsis ? TextOverflow.ellipsis : TextOverflow.clip,
      textAlign: align,
      style: GoogleFonts.inter(
        fontSize: size,
        height: height == null ? null : height! / size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color.withOpacity(color.opacity * opacity),
        decoration: TextDecoration.none,
      ),
    );
  }
}

/// v8.4: lays [child] out at the Figma frame's own logical width [width]
/// (height = available height / scale) and scales it as one unit to the
/// available width, so every position, size, padding and font keeps the
/// frame's proportions on any phone (MediaQuery is rescaled to match).
class FigmaViewport extends StatelessWidget {
  const FigmaViewport({super.key, required this.width, required this.child});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final s = c.maxWidth / width;
      final h = c.maxHeight / s;
      final mq = MediaQuery.of(context);
      return SizedBox(
        width: c.maxWidth,
        height: c.maxHeight,
        child: FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: h,
            child: MediaQuery(
              data: mq.copyWith(size: Size(width, h), padding: mq.padding / s, viewPadding: mq.viewPadding / s, viewInsets: mq.viewInsets / s),
              child: FigmaScale(scale: s, child: child),
            ),
          ),
        ),
      );
    });
  }
}

/// The [FText] style as a TextStyle (for TextFields): Inter, Figma px.
class FTextStyle {
  static TextStyle of({double size = 16, FontWeight weight = FontWeight.w400, Color color = Colors.white, double? height, double? letterSpacing}) =>
      GoogleFonts.inter(
        fontSize: size,
        height: height == null ? null : height / size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color,
        decoration: TextDecoration.none,
      );
}
