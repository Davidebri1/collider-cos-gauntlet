import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A universal, physics-based interactive wrapper providing authentic Apple visionOS
/// tactile response: fluid spring-damped scaling, specular illumination flare,
/// and smooth resting recovery on every single interaction.
class VisionPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final double pressedScale;
  final double hoverScale;
  final BorderRadius? borderRadius;
  final Duration duration;

  const VisionPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.tooltip,
    this.pressedScale = 0.94,
    this.hoverScale = 1.02,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 140),
  });

  @override
  State<VisionPressable> createState() => _VisionPressableState();
}

class _VisionPressableState extends State<VisionPressable> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.pressedScale).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    setState(() => _isPressed = true);
    _animCtrl.forward();
    HapticFeedback.selectionClick();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    setState(() => _isPressed = false);
    _animCtrl.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _animCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    Widget core = MouseRegion(
      cursor: (widget.onTap != null || widget.onLongPress != null)
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            final effectiveScale = _isPressed
                ? _scaleAnimation.value
                : (_isHovered ? widget.hoverScale : 1.0);

            return Transform.scale(
              scale: effectiveScale,
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                foregroundDecoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  color: _isPressed
                      ? Colors.white.withOpacity(0.08)
                      : (_isHovered ? Colors.white.withOpacity(0.03) : Colors.transparent),
                ),
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      return Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        child: core,
      );
    }

    return core;
  }
}
