import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/files/file_store.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/figma/figma_stage.dart';
import '../../../core/vision/vision_kit.dart';
import 'video_source.dart';

/// Video playback (map row 19, Figma YEuK4CL2uyECUhvGEcgCNS 417-8630): the
/// video in a rounded window over the dimmed room; a back circle top left
/// (closes), a volume capsule top right, and a playback capsule across the
/// window's bottom edge: back 15 s, play / pause, forward 15 s, scrub, ⋯.
/// v8.4: a straight copy of the frame, scaled as one unit (FigmaStage).
/// ⋯ opens the glass menu with the player's real options (Loop, Speed).
class VideoPlayerView extends StatefulWidget {
  final StoredFile file;
  final Uint8List bytes;
  const VideoPlayerView({super.key, required this.file, required this.bytes});

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  VideoSource? _src;
  bool _failed = false;
  double? _scrub; // 0..1 while dragging

  VideoPlayerController? get _c => _src?.controller;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final s = await VideoSource.open(widget.file.name, widget.bytes, FileStore.mimeFor(widget.file.name));
    if (!mounted) {
      await s?.release();
      return;
    }
    if (s == null) {
      setState(() => _failed = true);
      return;
    }
    _src = s;
    s.controller.addListener(_tick);
    try {
      await s.controller.initialize();
      if (!mounted) return;
      await s.controller.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
    if (mounted) setState(() {});
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _src?.controller.removeListener(_tick);
    unawaited(_src?.release());
    super.dispose();
  }

  void _toggle() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (c.value.position >= c.value.duration) c.seekTo(Duration.zero);
      c.play();
    }
  }

  void _skip(int s) {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    var t = c.value.position + Duration(seconds: s);
    if (t < Duration.zero) t = Duration.zero;
    if (t > c.value.duration) t = c.value.duration;
    c.seekTo(t);
  }

  // ignore: unused_element
  static String _fmt(Duration d) {
    final s = d.inSeconds;
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, ss = s % 60;
    final two = ss.toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$two' : '$m:$two';
  }

  // ── Figma 417:8630 geometry (frame 1920 x 1080) ────────────────────────
  // Movie 1180 x 762 at (370, 109), radius 44, inner image radius 40.
  // Back button (24, 24) 44 x 44; volume pill right 24 / top 24 (p 12 / 8,
  // bar 210 x 8, gap 16, 28 px speaker glyph 19). Player 672 x 68 at
  // (624, 851): p 16 / 12, gap 16, three 44 buttons (gap 16), bar 400 x 8,
  // ellipsis 44. Window bar (884, 949): dot 12 + 120 x 10 at x 32.
  // The stage crops the frame to the window group (x 370..1550, y 109..961)
  // and scales it as one unit to the screen width.
  static const _frame = Size(1920, 1080);
  static const double _crop = 1180;
  static const Offset _center = Offset(960, 535);

  Widget _glass({required Widget child, required double radius, Color fill = const Color(0x66B4B4B4), bool border = true, double blur = 80}) {
    final k = FigmaScale.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: (blur / 2 * k).clamp(0.0, 40.0), sigmaY: (blur / 2 * k).clamp(0.0, 40.0)),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius),
            border: border ? Border.all(color: const Color(0x33DEDEDE), width: 1) : null,
            boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 12)],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _bar(double frac, double w, {ValueChanged<double>? onDrag, ValueChanged<double>? onEnd}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: onDrag == null ? null : (d) => onDrag((d.localPosition.dx / w).clamp(0.0, 1.0)),
      onHorizontalDragEnd: onEnd == null ? null : (_) => onEnd(frac),
      onTapUp: onEnd == null ? null : (d) => onEnd((d.localPosition.dx / w).clamp(0.0, 1.0)),
      child: SizedBox(
        width: w,
        height: 44,
        child: Center(
          child: Container(
            width: w,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0x8C4F504D),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [BoxShadow(color: Color(0x4DFFFFFF), offset: Offset(0, 1), blurRadius: 1)],
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
            child: FractionallySizedBox(
              widthFactor: frac.clamp(0.0, 1.0),
              child: Container(decoration: BoxDecoration(color: const Color(0xFFEDEDF2), borderRadius: BorderRadius.circular(3))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _btn(Widget glyph, String tip, VoidCallback onTap) => Semantics(
        button: true,
        label: tip,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: SizedBox(width: 44, height: 44, child: Center(child: glyph))),
      );

  Widget _skipGlyph(bool fwd) => SizedBox(
        width: 24,
        height: 24,
        child: Stack(alignment: Alignment.center, children: [
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(fwd ? -1.0 : 1.0, 1.0, 1.0),
            child: const Icon(Icons.replay, size: 24, color: Colors.white),
          ),
          Padding(padding: const EdgeInsets.only(top: 2), child: Text('15', style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.white, decoration: TextDecoration.none))),
        ]),
      );

  void _menu() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, _, __) => StatefulBuilder(builder: (ctx, set) {
        final speed = c.value.playbackSpeed;
        return Stack(children: [
          Positioned.fill(child: GestureDetector(onTap: () => Navigator.of(ctx).pop())),
          Center(
            child: Material(
              type: MaterialType.transparency,
              child: GlassMenu(rows: [
                GlassMenuRow(icon: Icons.repeat_rounded, label: 'Loop', on: c.value.isLooping, onTap: () async {
                  await c.setLooping(!c.value.isLooping);
                  set(() {});
                }),
                for (final v in const [1.0, 1.5, 2.0])
                  GlassMenuRow(icon: Icons.speed_rounded, label: 'Speed ${v == 1.0 ? '1' : v}x', on: speed == v, onTap: () async {
                    await c.setPlaybackSpeed(v);
                    set(() {});
                  }),
              ]),
            ),
          ),
        ]);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    final dur = ready ? c.value.duration : Duration.zero;
    final pos = ready ? c.value.position : Duration.zero;
    final frac = _scrub ?? (dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0);
    final vsize = ready ? c.value.size : const Size(16, 9);

    final Widget picture = _failed
        ? const Center(child: Icon(Icons.videocam_off_outlined, size: 80, color: VColors.textTertiary))
        : ready
            ? GestureDetector(
                onTap: _toggle,
                child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: vsize.width, height: vsize.height, child: VideoPlayer(c))),
              )
            : const Center(child: SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 5, color: Colors.white70)));

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _toggle,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _skip(-15),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _skip(15),
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: FigmaStage(frame: _frame, cropWidth: _crop, center: _center, children: [
          // Movie window.
          Positioned(
            left: 370,
            top: 109,
            width: 1180,
            height: 762,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(44),
                border: Border.all(color: const Color(0x33DEDEDE), width: 1),
                boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 12)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Stack(fit: StackFit.expand, children: [
                  ColoredBox(color: Colors.black, child: picture),
                  // Back (closes).
                  Positioned(
                    left: 24,
                    top: 24,
                    child: _glass(
                      radius: 22,
                      fill: const Color(0x33E7E7E7),
                      border: false,
                      blur: 60,
                      child: _btn(const Icon(Icons.chevron_left_rounded, size: 26, color: Colors.white), 'Close', () => Navigator.of(context).pop()),
                    ),
                  ),
                  // Volume pill.
                  Positioned(
                    right: 24,
                    top: 24,
                    child: _glass(
                      radius: 40,
                      border: false,
                      blur: 60,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          height: 44,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            _bar(ready ? c.value.volume : 1, 210, onDrag: ready ? (v) => c.setVolume(v) : null, onEnd: ready ? (v) => c.setVolume(v) : null),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: ready ? () => c.setVolume(c.value.volume == 0 ? 1 : 0) : null,
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: Icon(ready && c.value.volume == 0 ? Icons.volume_off_outlined : Icons.volume_up_outlined, size: 22, color: const Color(0xCCEBEBF5)),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          // Player ornament.
          Positioned(
            left: 624,
            top: 851,
            width: 672,
            height: 68,
            child: _glass(
              radius: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  _btn(_skipGlyph(false), 'Back 15 seconds', () => _skip(-15)),
                  const SizedBox(width: 16),
                  _btn(Icon(ready && c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 40, color: Colors.white), ready && c.value.isPlaying ? 'Pause' : 'Play', _toggle),
                  const SizedBox(width: 16),
                  _btn(_skipGlyph(true), 'Forward 15 seconds', () => _skip(15)),
                  const SizedBox(width: 16),
                  _bar(frac, 400,
                      onDrag: ready ? (v) => setState(() => _scrub = v) : null,
                      onEnd: ready
                          ? (v) {
                              c.seekTo(Duration(milliseconds: (dur.inMilliseconds * v).round()));
                              setState(() => _scrub = null);
                            }
                          : null),
                  const SizedBox(width: 16),
                  _btn(const Icon(Icons.more_horiz_rounded, size: 26, color: Colors.white), 'More', _menu),
                ]),
              ),
            ),
          ),
          // Window bar (884, 949): dot closes, bar swipes down to close.
          Positioned(
            left: 884,
            top: 949,
            width: 152,
            height: 12,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: -16,
                top: -16,
                width: 44,
                height: 44,
                child: Semantics(
                  button: true,
                  label: 'Close',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Center(child: Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x99FFFFFF)))),
                  ),
                ),
              ),
              Positioned(
                left: 32,
                top: 1,
                width: 120,
                height: 10,
                child: GestureDetector(
                  onVerticalDragEnd: (d) {
                    if ((d.primaryVelocity ?? 0) > 200) Navigator.of(context).pop();
                  },
                  child: Container(decoration: BoxDecoration(color: const Color(0x99FFFFFF), borderRadius: BorderRadius.circular(5))),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
