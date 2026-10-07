import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../../models/theme_def.dart';
import 'premium_market_ambient.dart' show AmbientGlass;
import 'theme_living_media.dart';

/// Native: the live wallpaper renders to a texture, so Flutter filters apply.
/// SimpleBackgroundVideo.tsx:70-71, CSS order blur(20px) -> brightness(0.5)
/// -> contrast(1.2), then opacity 0.7 (0.3 while loading is not tracked here).
/// Owned themes lift to brightness 1 / opacity 1 (DEVIATIONS.md D5).
/// Native glass ([glass]) is Flutter BackdropFilter in the market view.
class AmbientMedia extends StatelessWidget {
  final WallpaperTheme theme;
  final bool owned;
  final Size viewport;
  final List<AmbientGlass> glass;

  const AmbientMedia({
    super.key,
    required this.theme,
    this.owned = false,
    this.viewport = Size.zero,
    this.glass = const [],
  });

  static ColorFilter _brightness(double b) => ColorFilter.matrix(<double>[
        b, 0, 0, 0, 0,
        0, b, 0, 0, 0,
        0, 0, b, 0, 0,
        0, 0, 0, 1, 0,
      ]);

  // contrast(1.2): c*x + (0.5 - 0.5*c)  ->  offset -0.1 * 255 = -25.5
  static const ColorFilter _contrast = ColorFilter.matrix(<double>[
    1.2, 0, 0, 0, -25.5,
    0, 1.2, 0, 0, -25.5,
    0, 0, 1.2, 0, -25.5,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: owned ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      child: ImageFiltered(
        imageFilter:
            ImageFilter.blur(sigmaX: 20, sigmaY: 20, tileMode: TileMode.clamp),
        child: ThemeLivingBackdrop(theme: theme, preferVideo: true),
      ),
      builder: (context, t, child) => Opacity(
        opacity: 0.7 + 0.3 * t,
        child: ColorFiltered(
          colorFilter: _contrast,
          child: ColorFiltered(colorFilter: _brightness(0.5 + 0.5 * t), child: child),
        ),
      ),
    );
  }
}
