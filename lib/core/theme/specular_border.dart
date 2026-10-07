import 'package:flutter/material.dart';

/// A custom painter that renders an authentic Apple visionOS 0.5px-0.6px specular light bevel.
/// The rim simulates directional illumination from the top-left, fading to subtle occlusion shadow on bottom-right.
class SpecularRimPainter extends CustomPainter {
  final double borderRadius;
  final double strokeWidth;
  final double lightIntensity;

  const SpecularRimPainter({
    this.borderRadius = 22.0,
    this.strokeWidth = 0.5,
    this.lightIntensity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity((0.42 * lightIntensity).clamp(0.0, 1.0)),
          Colors.white.withOpacity((0.15 * lightIntensity).clamp(0.0, 1.0)),
          Colors.white.withOpacity((0.04 * lightIntensity).clamp(0.0, 1.0)),
          Colors.black.withOpacity(0.08), // Subtle occlusion shadow on bottom-right per Master Spec §2.2
        ],
        stops: const [0.0, 0.40, 0.75, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant SpecularRimPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.lightIntensity != lightIntensity;
  }
}
