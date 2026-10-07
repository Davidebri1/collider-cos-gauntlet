import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A living visionOS ambient stardust particle overlay that floats gently in Plane 0
/// above the wallpaper and behind the content glass windows.
class LivingStardustOverlay extends StatefulWidget {
  final int particleCount;
  final Color? tintColor;

  const LivingStardustOverlay({
    super.key,
    this.particleCount = 22,
    this.tintColor,
  });

  @override
  State<LivingStardustOverlay> createState() => _LivingStardustOverlayState();
}

class _LivingStardustOverlayState extends State<LivingStardustOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _driftCtrl;
  final List<_StardustMote> _motes = [];

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    for (int i = 0; i < widget.particleCount; i++) {
      _motes.add(_StardustMote(
        xRatio: rng.nextDouble(),
        yRatio: rng.nextDouble(),
        radius: 1.5 + rng.nextDouble() * 3.5,
        baseOpacity: 0.04 + rng.nextDouble() * 0.14,
        speedX: 0.008 + rng.nextDouble() * 0.016,
        speedY: 0.006 + rng.nextDouble() * 0.014,
        phase: rng.nextDouble() * math.pi * 2,
      ));
    }

    _driftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _driftCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _driftCtrl,
        builder: (context, _) {
          return CustomPaint(
            painter: _StardustPainter(
              motes: _motes,
              progress: _driftCtrl.value,
              tintColor: widget.tintColor ?? Colors.white,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _StardustMote {
  final double xRatio;
  final double yRatio;
  final double radius;
  final double baseOpacity;
  final double speedX;
  final double speedY;
  final double phase;

  _StardustMote({
    required this.xRatio,
    required this.yRatio,
    required this.radius,
    required this.baseOpacity,
    required this.speedX,
    required this.speedY,
    required this.phase,
  });
}

class _StardustPainter extends CustomPainter {
  final List<_StardustMote> motes;
  final double progress;
  final Color tintColor;

  _StardustPainter({
    required this.motes,
    required this.progress,
    required this.tintColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final mote in motes) {
      final t = progress * math.pi * 2 + mote.phase;
      // Gentle sinusoidal drifting oscillation
      final currentX = (mote.xRatio * size.width + math.sin(t * 0.8) * 24.0) % size.width;
      final currentY = (mote.yRatio * size.height + math.cos(t * 0.6) * 20.0) % size.height;
      
      // Breathing opacity
      final breathingOpacity = (mote.baseOpacity * (0.8 + 0.4 * math.sin(t))).clamp(0.02, 0.25);
      paint.color = tintColor.withOpacity(breathingOpacity);

      // Soft glow center
      canvas.drawCircle(Offset(currentX, currentY), mote.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StardustPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.tintColor != tintColor;
  }
}
