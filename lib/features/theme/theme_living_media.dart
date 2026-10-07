import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/media/theme_catalog.dart';
import '../../models/theme_def.dart';

/// Media source helpers. A media string is either an absolute URL (streamed
/// from the collider-media host) or a bundled asset path.
class ThemeMedia {
  ThemeMedia._();

  static bool isNetwork(String? src) =>
      src != null && (src.startsWith('https://') || src.startsWith('http://'));

  /// Image provider for a poster/still. Network sources are cached
  /// (memory + browser HTTP cache on web, disk cache on mobile).
  static ImageProvider<Object> provider(String src) {
    if (isNetwork(src)) return CachedNetworkImageProvider(src);
    return AssetImage(src);
  }

  static final ImageProvider offlineWallpaper =
      const AssetImage(ThemeCatalog.offlineWallpaperAsset);
}

/// Warms the image cache for posters the user is about to see.
class ThemeMediaPrefetch {
  ThemeMediaPrefetch._();

  /// Precache posters within [radius] of [index] in [ordered] (the order the
  /// carousel shows). The focused poster itself is included.
  static void precacheAround(BuildContext context, List<WallpaperTheme> ordered, int index, {int radius = 2}) {
    if (ordered.isEmpty) return;
    for (var d = -radius; d <= radius; d++) {
      final i = index + d;
      if (i < 0 || i >= ordered.length) continue;
      final src = ordered[i].posterUrl;
      precacheImage(ThemeMedia.provider(src), context, onError: (_, __) {});
    }
  }

  /// Same as [precacheAround] but locates [focused] by slug.
  static void precacheNeighbors(BuildContext context, List<WallpaperTheme> ordered, WallpaperTheme focused, {int radius = 2}) {
    final i = ordered.indexWhere((t) => t.id == focused.id);
    if (i >= 0) precacheAround(context, ordered, i, radius: radius);
  }
}

/// Any theme image by source string (URL or asset). Shows the tiny bundled
/// wallpaper while loading and on failure, so there is never an empty box.
class ThemeImage extends StatelessWidget {
  final String src;
  final BoxFit fit;
  final double? width;
  final double? height;
  final FilterQuality filterQuality;
  final Alignment alignment;

  const ThemeImage(
    this.src, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.filterQuality = FilterQuality.medium,
    this.alignment = Alignment.center,
  });

  Widget _fallback() => Image.asset(
        ThemeCatalog.offlineWallpaperAsset,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1A1B22)),
      );

  @override
  Widget build(BuildContext context) {
    if (ThemeMedia.isNetwork(src)) {
      return CachedNetworkImage(
        imageUrl: src,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        filterQuality: filterQuality,
        fadeInDuration: const Duration(milliseconds: 180),
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        placeholder: (_, __) => _fallback(),
        errorWidget: (_, __, ___) => _fallback(),
      );
    }
    return Image.asset(
      src,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      filterQuality: filterQuality,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }
}

/// Still poster for CoverFlow thumbs (lightweight).
class ThemePosterImage extends StatelessWidget {
  final WallpaperTheme theme;
  final BoxFit fit;
  final FilterQuality filterQuality;

  /// Use the higher resolution still (full-bleed wallpaper) when available.
  final bool fullBleed;

  const ThemePosterImage({
    super.key,
    required this.theme,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.high,
    this.fullBleed = false,
  });

  @override
  Widget build(BuildContext context) {
    return ThemeImage(
      fullBleed ? theme.wallpaperStill : theme.posterUrl,
      fit: fit,
      filterQuality: filterQuality,
    );
  }
}

/// Premium market ambient treatment: tint only (no blur), so the living
/// wallpaper stays sharp behind the UI (quality standard H6).
class BuilderAmbientFilter {
  BuilderAmbientFilter._();

  /// Kept for API compatibility; blur is intentionally not applied.
  static const double blurSigma = 0.0;
  static const double layerOpacity = 0.85;
  static const Color darkOverlay = Color(0x59000000); // rgba(0,0,0,0.35)

  // Mild dim + slight desaturation. Colour matrices only; no ImageFilter.
  static const ColorFilter _tint = ColorFilter.matrix(<double>[
    0.62, 0.10, 0.01, 0, 0,
    0.04, 0.68, 0.01, 0, 0,
    0.04, 0.10, 0.59, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  static Widget wrap(Widget child) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: Opacity(
            opacity: layerOpacity,
            child: ColorFiltered(colorFilter: _tint, child: child),
          ),
        ),
        const ColoredBox(color: darkOverlay),
      ],
    );
  }
}

/// Full-bleed living wallpaper. The poster shows immediately; the loop
/// streams in over it (network source) and fades in once playing. Only the
/// active theme owns a controller; it is disposed when the theme changes or
/// the widget leaves the tree.
class ThemeLivingBackdrop extends StatefulWidget {
  final WallpaperTheme theme;
  /// When false, always show poster.
  final bool preferVideo;
  /// Premium market ambient tint (no blur).
  final bool builderAmbient;

  const ThemeLivingBackdrop({
    super.key,
    required this.theme,
    this.preferVideo = true,
    this.builderAmbient = false,
  });

  @override
  State<ThemeLivingBackdrop> createState() => _ThemeLivingBackdropState();
}

class _ThemeLivingBackdropState extends State<ThemeLivingBackdrop> {
  VideoPlayerController? _controller;
  bool _ready = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void didUpdateWidget(covariant ThemeLivingBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme.id != widget.theme.id ||
        oldWidget.theme.videoPath != widget.theme.videoPath ||
        oldWidget.preferVideo != widget.preferVideo) {
      _disposeController();
      _ready = false;
      _boot();
    }
  }

  Future<void> _boot() async {
    final gen = ++_generation;
    final path = widget.theme.videoPath;
    if (!widget.preferVideo || path == null || path.isEmpty) return;
    final c = ThemeMedia.isNetwork(path)
        ? VideoPlayerController.networkUrl(
            Uri.parse(path),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          )
        : VideoPlayerController.asset(path, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _controller = c;
    try {
      await c.setVolume(0);
      await c.initialize();
      if (gen != _generation || !mounted) {
        c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      if (gen != _generation || !mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      debugPrint('ThemeLivingBackdrop: video unavailable, poster only: $e');
      if (identical(_controller, c)) _disposeController();
    }
  }

  void _disposeController() {
    _generation++;
    final c = _controller;
    _controller = null;
    c?.dispose();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final showVideo = _ready && c != null && c.value.isInitialized;
    final media = Stack(
      fit: StackFit.expand,
      children: [
        ThemePosterImage(theme: widget.theme, fullBleed: true, filterQuality: FilterQuality.high),
        if (c != null)
          AnimatedOpacity(
            opacity: showVideo ? 1 : 0,
            duration: const Duration(milliseconds: 350),
            child: showVideo
                ? FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: c.value.size.width,
                      height: c.value.size.height,
                      child: VideoPlayer(c),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
    if (widget.builderAmbient) return BuilderAmbientFilter.wrap(media);
    return media;
  }
}

/// Cover media: poster by default; optional video for the focused cover.
/// Only pass playVideo: true for the single focused cover so at most one
/// extra stream is open.
class ThemeCoverMedia extends StatelessWidget {
  final WallpaperTheme theme;
  final bool playVideo;

  const ThemeCoverMedia({
    super.key,
    required this.theme,
    this.playVideo = false,
  });

  @override
  Widget build(BuildContext context) {
    final useVideo = playVideo && theme.isLive && !kIsWeb;
    if (useVideo) {
      return ThemeLivingBackdrop(
        key: ValueKey('cover-vid-${theme.id}'),
        theme: theme,
        preferVideo: true,
      );
    }
    return ThemePosterImage(theme: theme);
  }
}
