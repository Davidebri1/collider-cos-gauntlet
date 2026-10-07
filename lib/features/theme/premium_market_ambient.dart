import 'package:flutter/widgets.dart';

import '../../models/theme_def.dart';
import 'premium_market_ambient_io.dart'
    if (dart.library.js_interop) 'premium_market_ambient_web.dart' as impl;

/// One export backdrop-blur element (header `backdrop-blur-md`, search input
/// `backdrop-blur-sm`) in viewport coordinates.
@immutable
class AmbientGlass {
  final Rect rect;
  final double radius;
  final double sigma;
  const AmbientGlass(this.rect, this.radius, this.sigma);

  @override
  bool operator ==(Object other) =>
      other is AmbientGlass &&
      other.rect == rect &&
      other.radius == radius &&
      other.sigma == sigma;

  @override
  int get hashCode => Object.hash(rect, radius, sigma);
}

/// Port of Builder export `src/app/components/SimpleBackgroundVideo.tsx`
/// (the background Player.tsx:100 mounts), only the source swapped
/// (YouTube embed -> the selected theme's live wallpaper loop).
///
///   container (:39-50)  position fixed, 100vw x 100vh, z-index -10,
///                       overflow hidden, pointer-events none
///   media     (:52-74)  200vw x 200vh, centred (translate(-50%, -50%)),
///                       filter: blur(20px) brightness(0.5) contrast(1.2),
///                       opacity: isLoading ? 0.3 : 0.7,
///                       transition: opacity 1s ease-in-out
///   overlay   (:93-103) background: rgba(0, 0, 0, 0.2)
///
/// Ownership (DEVIATIONS.md D5): the brightness(0.5) / opacity 0.7 dim is the
/// "not owned" state; an owned theme's preview lifts to brightness 1 /
/// opacity 1. The 0.2 black overlay stays on every preview (the universal
/// cinematic tint).
///
/// Web renders the blurred loop through one WebGL canvas at quarter
/// resolution (same blur radius on screen) and hosts the export's
/// backdrop-blur elements in the same DOM container, so the whole ambient is a
/// single platform view (see premium_market_ambient_web.dart).
class SimpleBackgroundVideoAmbient extends StatelessWidget {
  final WallpaperTheme theme;
  final bool owned;
  final List<AmbientGlass> glass;

  const SimpleBackgroundVideoAmbient({
    super.key,
    required this.theme,
    this.owned = false,
    this.glass = const [],
  });

  /// :100 subtle overlay rgba(0, 0, 0, 0.2).
  static const Color overlay = Color.fromRGBO(0, 0, 0, 0.2);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        return Stack(
          clipBehavior: Clip.hardEdge, // overflow: hidden
          children: [
            // 200vw x 200vh, top/left 50% + translate(-50%, -50%)
            Positioned(
              left: -w / 2,
              top: -h / 2,
              width: w * 2,
              height: h * 2,
              child: impl.AmbientMedia(
                key: ValueKey('simple-video-${theme.id}-${theme.videoPath ?? theme.assetPath}'),
                theme: theme,
                owned: owned,
                viewport: Size(w, h),
                glass: glass,
              ),
            ),
            const Positioned.fill(child: ColoredBox(color: overlay)),
          ],
        );
      }),
    );
  }
}
