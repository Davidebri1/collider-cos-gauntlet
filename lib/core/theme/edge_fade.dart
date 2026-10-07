import 'package:flutter/material.dart';

/// Vertical alpha gradient masking so scrollable content dissolves smoothly into
/// the living wallpaper at its edges instead of ending on a hard cut line.
///
/// Master Spec §4.2 "Faded Edge Masking" and §10 "Faded Gradient Edges".
/// This is a pure mask: it never adds a container, border, tint, or blur, so it
/// preserves the Law of Bounded Spatial Windows and single-pass optical glass.
class EdgeFade extends StatelessWidget {
  final Widget child;

  /// Height in logical pixels over which the mask ramps from transparent.
  final double fadeHeight;

  final bool fadeTop;
  final bool fadeBottom;

  const EdgeFade({
    super.key,
    required this.child,
    this.fadeHeight = 18.0,
    this.fadeTop = true,
    this.fadeBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!fadeTop && !fadeBottom) return child;

    final colors = <Color>[
      if (fadeTop) const Color(0x00FFFFFF) else const Color(0xFFFFFFFF),
      const Color(0xFFFFFFFF),
      const Color(0xFFFFFFFF),
      if (fadeBottom) const Color(0x00FFFFFF) else const Color(0xFFFFFFFF),
    ];

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect rect) {
        final double h = rect.height;
        if (h <= 0) {
          return const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
          ).createShader(rect);
        }
        // Cap the ramp so a very short viewport keeps a solid readable band.
        final double f = (fadeHeight / h).clamp(0.0, 0.42);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: <double>[0.0, f, 1.0 - f, 1.0],
        ).createShader(rect);
      },
      child: child,
    );
  }
}