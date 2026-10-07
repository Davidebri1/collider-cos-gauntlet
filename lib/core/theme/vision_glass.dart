import 'dart:ui';
import 'package:flutter/material.dart';
import 'spatial_theme.dart';
import 'specular_border.dart';

class VisionGlass extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final SpatialDepthPlane plane;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final double? blurSigma;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const VisionGlass({
    super.key,
    required this.child,
    this.borderRadius = 22.0,
    this.plane = SpatialDepthPlane.resting,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.blurSigma,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBlur = blurSigma ?? SpatialTheme.blurSigma(plane);
    final effectiveBg = backgroundColor ?? SpatialTheme.glassBackground(plane);
    final effectiveBorder = borderColor ?? SpatialTheme.rimBorderColor(plane);
    final effectiveStroke = borderWidth ?? 0.6;
    final effectiveShadow = SpatialTheme.ambientShadow(plane);

    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: effectiveShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
          child: CustomPaint(
            foregroundPainter: SpecularRimPainter(
              borderRadius: borderRadius,
              strokeWidth: effectiveStroke,
              lightIntensity: plane == SpatialDepthPlane.modal ? 1.2 : 1.0,
            ),
            child: Container(
              padding: padding ?? const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: effectiveBg,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: effectiveBorder,
                  width: effectiveStroke,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}
