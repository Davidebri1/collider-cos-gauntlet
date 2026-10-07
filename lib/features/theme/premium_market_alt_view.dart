import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio/music_player.dart';
import '../../core/figma/figma_stage.dart';
import '../../core/media/theme_catalog.dart';
import '../../core/vision/vision_kit.dart';
import '../../models/theme_def.dart';
import 'live_cover_video.dart';
import 'premium_market_ambient.dart';
import 'theme_living_media.dart';
import 'theme_pack_store.dart';

/// Map row 4, v8.4: "Music widget and premium theme market alt", a straight
/// copy of visionOS Design System Community 417:1777 (frame 1920 x 1080):
/// the cover flow (Frame 160, 913 x 420 at 504,242), the Media Controls
/// and Play Bar (607 x 65 at 658,709) and the Home Controller (132 x 12 at
/// 896,792), laid out at the frame's size and scaled as one unit to the
/// device width (crop = the cover-flow group's own width, 913).
///
/// Real data: the covers are the runtime theme catalog (loops at both
/// ends); the focused theme's live wallpaper plays dimmed full-screen
/// behind (the market's ambient) and in the covers (centre and its two
/// neighbours stream, fully lit even when not owned); the play bar is the
/// one shared music queue. Shown in place of the phone market while the
/// music widget is switched on (it docks here as the frame's play bar).
class PremiumMarketAltView extends StatefulWidget {
  final WallpaperTheme currentTheme;
  final ValueChanged<WallpaperTheme> onApplyTheme;
  final ValueChanged<WallpaperTheme> onPreviewTheme;
  final VoidCallback onClose;
  final VoidCallback onOpenMusic;

  const PremiumMarketAltView({
    super.key,
    required this.currentTheme,
    required this.onApplyTheme,
    required this.onPreviewTheme,
    required this.onClose,
    required this.onOpenMusic,
  });

  @override
  State<PremiumMarketAltView> createState() => _PremiumMarketAltViewState();
}

class _PremiumMarketAltViewState extends State<PremiumMarketAltView> {
  static const Size _frame = Size(1920, 1080);
  static const double _crop = 913;
  static const Offset _center = Offset(960.5, 523);
  // Centre card (417:1968): 316 x 398 at 796,255 (frame coords).
  static const Rect _card = Rect.fromLTWH(796, 255, 316, 398);
  static const Rect _bar = Rect.fromLTWH(658, 709, 607, 65);

  final ThemePackStore _store = ThemePackStore.instance;
  final FocusNode _keys = FocusNode();
  List<WallpaperTheme> _themes = const [];
  int _index = 0;
  double _drag = 0;

  List<WallpaperTheme> get _catalog => [...WallpaperCatalog.premiumThemes, ...WallpaperCatalog.freeThemes];
  bool _owned(WallpaperTheme t) => !t.isPremium || _store.isUnlocked(t.id);
  WallpaperTheme? get _selected => _themes.isEmpty ? null : _themes[_index];

  @override
  void initState() {
    super.initState();
    ThemeCatalog.instance.addListener(_reload);
    _store.addListener(_reload);
    MusicPlayer.instance.addListener(_reload);
    _store.init();
    _themes = _catalog;
    final i = _themes.indexWhere((t) => t.id == widget.currentTheme.id);
    _index = i >= 0 ? i : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _preview());
  }

  @override
  void dispose() {
    ThemeCatalog.instance.removeListener(_reload);
    _store.removeListener(_reload);
    MusicPlayer.instance.removeListener(_reload);
    _keys.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    final keep = _selected?.id;
    setState(() {
      _themes = _catalog;
      final i = keep == null ? -1 : _themes.indexWhere((t) => t.id == keep);
      _index = _themes.isEmpty ? 0 : (i >= 0 ? i : _index.clamp(0, _themes.length - 1));
    });
    // The catalog (and its songs) can arrive after the first frame.
    final p = MusicPlayer.instance;
    if (p.current == null && !p.playing && MusicPlayer.library.isNotEmpty) _preview();
  }

  void _preview() {
    final s = _selected;
    if (s == null || !mounted) return;
    widget.onPreviewTheme(s);
    // The play bar follows the focused theme's songs while nothing plays.
    final p = MusicPlayer.instance;
    final tracks = MusicPlayer.themeTracks(s.id);
    if (!p.playing && tracks.isNotEmpty) {
      p.cue(tracks, 0, id: 'theme:${s.id}');
    } else if (p.current == null && MusicPlayer.library.isNotEmpty) {
      p.cue(MusicPlayer.library, 0);
    }
  }

  void _select(int i) {
    if (_themes.isEmpty) return;
    final n = _themes.length;
    final j = ((i % n) + n) % n;
    if (j == _index) return;
    setState(() => _index = j);
    _preview();
  }

  Future<void> _activate(WallpaperTheme t) async {
    if (_owned(t)) {
      widget.onApplyTheme(t);
      return;
    }
    final price = _store.priceLabelFor(t.id, catalogPrice: t.priceLabel);
    final i = await showVAlert(
      context,
      icon: Icons.diamond_outlined,
      title: _name(t),
      message: [t.creator, t.collection].where((s) => s.isNotEmpty).join(' · '),
      actions: [VAlertChoice('Buy · $price'), const VAlertChoice('Cancel')],
    );
    if (i != 0 || !mounted) return;
    if (!ThemePackStore.purchasesAvailable) {
      await showVAlert(context, icon: Icons.diamond_outlined, title: "Purchases aren't available on this link", actions: const [VAlertChoice('OK')]);
      return;
    }
    await _store.buyPack(t.id);
  }

  String _name(WallpaperTheme t) => t.name.replaceAll(RegExp(r'\s*4K$'), '').trim();

  String _line2(WallpaperTheme t) {
    final who = t.creator.isNotEmpty ? t.creator : t.collection;
    final state = _owned(t) ? 'Owned' : _store.priceLabelFor(t.id, catalogPrice: t.priceLabel);
    return [if (who.isNotEmpty) who, state].join(' · ');
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _select(_index - 1);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _select(_index + 1);
    } else if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.space) {
      final s = _selected;
      if (s != null) _activate(s);
    } else if (e.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selected;
    return Focus(
      focusNode: _keys,
      autofocus: true,
      onKeyEvent: _onKey,
      child: LayoutBuilder(builder: (context, box) {
        final screen = box.biggest;
        // Web: the ambient video is drawn under Flutter, so the glass blurs
        // are CSS elements at the screen rects of the card and the bar.
        final glass = <AmbientGlass>[
          AmbientGlass(FigmaStage.mapRect(screen, _crop, _center, _card), 28 * screen.width / _crop, 20 * screen.width / _crop),
          AmbientGlass(FigmaStage.mapRect(screen, _crop, _center, _bar), 32.5 * screen.width / _crop, 20 * screen.width / _crop),
        ];
        return Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: Colors.black),
          // The focused theme's live wallpaper, dimmed in place (row 4).
          if (sel != null) Positioned.fill(child: SimpleBackgroundVideoAmbient(theme: sel, owned: false, glass: kIsWeb ? glass : const [])),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (d) {
              _drag += d.delta.dx;
              final step = 90 * screen.width / 430;
              if (_drag.abs() > step) {
                _select(_index + (_drag < 0 ? 1 : -1));
                _drag = 0;
              }
            },
            onHorizontalDragEnd: (_) => _drag = 0,
            child: FigmaStage(
              frame: _frame,
              cropWidth: _crop,
              center: _center,
              clip: false,
              children: [
                ..._covers(),
                Positioned.fromRect(rect: _bar, child: const _PlayBarShell()),
                Positioned.fromRect(rect: _bar, child: _PlayBar(onOpenMusic: widget.onOpenMusic)),
                // Home Controller 417:1780: dot (close) + bar.
                Positioned(
                  left: 896,
                  top: 792,
                  child: Row(children: [
                    VPress(
                      onTap: widget.onClose,
                      tooltip: 'Close',
                      child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xCCFFFFFF), shape: BoxShape.circle)),
                    ),
                    const SizedBox(width: 12),
                    Container(width: 108, height: 12, decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(6))),
                  ]),
                ),
              ],
            ),
          ),
        ]);
      }),
    );
  }

  /// Poses from Frame 160: near covers centred 178 / 187 px out at 87.4 %
  /// (348 / 398), far covers 278 / 295 px out at 79.4 % (316 / 398), turned
  /// toward the centre.
  List<Widget> _covers() {
    final n = _themes.length;
    if (n == 0) return const [];
    final offsets = <int>[];
    for (final d in const [-2, 2, -1, 1, 0]) {
      if (n >= 5 || (d.abs() <= (n - 1) ~/ 2) || (n == 2 && d == 1) || (n == 4 && d == -2)) offsets.add(d);
    }
    return [
      for (final d in offsets) _cover(d, _themes[((_index + d) % n + n) % n]),
    ];
  }

  Widget _cover(int d, WallpaperTheme t) {
    const dx = {-2: -278.0, -1: -178.0, 0: 0.0, 1: 187.0, 2: 295.0};
    const sc = {-2: 0.794, -1: 0.874, 0: 1.0, 1: 0.874, 2: 0.794};
    // Turn measured from the frame's projected widths (near 232 of 276,
    // far 208 of 251 visible): about 35 / 38 degrees.
    const rot = {-2: 38.0, -1: 35.0, 0: 0.0, 1: -35.0, 2: -38.0};
    final m = Matrix4.identity()
      ..translate(dx[d]!)
      ..setEntry(3, 2, 0.0008)
      ..rotateY(rot[d]! * math.pi / 180)
      ..scale(sc[d]!, sc[d]!, 1);
    return Positioned.fromRect(
      key: ValueKey('cover-${t.id}'),
      rect: _card,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        transform: m,
        transformAlignment: Alignment.center,
        child: GestureDetector(
          onTap: () => d == 0 ? _activate(t) : _select(_index + d),
          child: _CoverCard(theme: t, title: _name(t), line2: _line2(t), live: d.abs() <= 1 && t.isLive, focused: d == 0),
        ),
      ),
    );
  }
}

/// 417:1968 + Group 10: glass card 316 x 398, radius 28, 1 px black border,
/// blur 40, 117 deg grey gradient at 25 %; cover 300 x 300 at 10,8, title and
/// creator 24 px centred under it. Covers are fully lit (row 4).
class _CoverCard extends StatelessWidget {
  final WallpaperTheme theme;
  final String title, line2;
  final bool live, focused;
  const _CoverCard({required this.theme, required this.title, required this.line2, required this.live, required this.focused});


  @override
  Widget build(BuildContext context) {
    final s = FigmaScale.of(context);
    final glass = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.black, width: 1),
        gradient: const LinearGradient(
          begin: Alignment(-0.89, -0.45),
          end: Alignment(0.89, 0.45),
          colors: [Color(0x40B4B4B4), Color(0x404F4F4F), Color(0x40FFFFFF), Color(0x40AFAFAF)],
          stops: [0.017, 0.0175, 0.33, 0.97],
        ),
      ),
    );
    return SizedBox(
      width: 316,
      height: 398,
      child: Stack(children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            // Blur 40 on every card: the covers behind a card are Flutter
            // content, so they blur on the web too (the ambient video under
            // Flutter gets its blur from the ambient's CSS glass instead).
            child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 20 * s, sigmaY: 20 * s), child: glass),
          ),
        ),
        Positioned(
          left: 10,
          top: 8,
          width: 300,
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(fit: StackFit.expand, children: [
              ThemePosterImage(theme: theme, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
              if (live) LiveCoverVideo(key: ValueKey('alt-live-${theme.id}'), url: theme.videoUrl!),
            ]),
          ),
        ),
        Positioned(left: 8, right: 8, top: 318, child: FText(title, size: 24, weight: FontWeight.w500, align: TextAlign.center)),
        Positioned(left: 8, right: 8, top: 350, child: FText(line2, size: 24, opacity: 0.6, align: TextAlign.center)),
      ]),
    );
  }
}

/// 417:1264 shell: 607 x 65, radius 63, white 1 px border, blur 40,
/// rgba(79,79,79,.1) / white .1 gradient, shadow 4,-5,32 black 25 %.
class _PlayBarShell extends StatelessWidget {
  const _PlayBarShell();
  @override
  Widget build(BuildContext context) {
    final s = FigmaScale.of(context);
    final fill = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(63),
        border: Border.all(color: Colors.white, width: 1),
        gradient: const LinearGradient(
          begin: Alignment(-0.16, -0.99),
          end: Alignment(0.16, 0.99),
          colors: [Color(0x1A4F4F4F), Color(0x1A4F4F4F), Color(0x1AFFFFFF), Color(0x1A4F4F4F)],
          stops: [0.017, 0.0175, 0.33, 0.97],
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(63),
        boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(4, -5), blurRadius: 32)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(63),
        child: kIsWeb ? fill : BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 20 * s, sigmaY: 20 * s), child: fill),
      ),
    );
  }
}

/// 417:1264 contents (bar-local px): back 16 / pause 78 / forward 128 at
/// top 12 (40 tall); now-playing well 225 x 45 at 190,9 (black 25 %, r10):
/// art 35 at 195,14 (r5), title Medium 12 at 238 (centre y 25), subtitle 10
/// #C9C9C9 (centre y 39), repeat 15 at 365, ellipsis at 392; quote.bubble
/// 446 / list.bullet 498 / speaker 550 (20 px).
class _PlayBar extends StatelessWidget {
  final VoidCallback onOpenMusic;
  const _PlayBar({required this.onOpenMusic});

  @override
  Widget build(BuildContext context) {
    final p = MusicPlayer.instance;
    final t = p.current;
    Widget btn(double left, double top, double w, double h, IconData icon, double size, String tip, VoidCallback? onTap) => Positioned(
          left: left,
          top: top,
          width: w,
          height: h,
          child: VPress(onTap: onTap, tooltip: tip, child: Center(child: Icon(icon, size: size, color: Colors.white.withValues(alpha: onTap == null ? 0.4 : 1)))),
        );
    return Stack(children: [
      btn(16, 12, 54, 40, Icons.fast_rewind_rounded, 26, 'Previous', t == null ? null : p.previous),
      btn(78, 12, 42, 40, p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, 24, p.playing ? 'Pause' : 'Play', t == null ? null : p.toggle),
      btn(128, 12, 54, 40, Icons.fast_forward_rounded, 26, 'Next', t == null ? null : p.next),
      Positioned(
        left: 190,
        top: 9,
        width: 225,
        height: 45,
        child: VPress(
          onTap: onOpenMusic,
          tooltip: 'Open Music',
          child: Container(decoration: BoxDecoration(color: const Color(0x40000000), borderRadius: BorderRadius.circular(10))),
        ),
      ),
      Positioned(
        left: 195,
        top: 14,
        width: 35,
        height: 35,
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: t == null || t.art.isEmpty
                ? const ColoredBox(color: Color(0x33FFFFFF), child: Icon(Icons.music_note_rounded, size: 18, color: Colors.white))
                : Image.network(t.art, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0x33FFFFFF))),
          ),
        ),
      ),
      Positioned(left: 238, top: 18, width: 112, child: IgnorePointer(child: FText(t?.title ?? 'No song', size: 12, weight: FontWeight.w500))),
      Positioned(left: 238, top: 33, width: 112, child: IgnorePointer(child: FText(t?.subtitle.isNotEmpty == true ? t!.subtitle : 'Music', size: 10, weight: FontWeight.w500, color: const Color(0xFFC9C9C9)))),
      btn(358, 20, 28, 24, p.repeat == MusicRepeat.one ? Icons.repeat_one_rounded : Icons.repeat_rounded, 15, 'Repeat', p.cycleRepeat),
      btn(386, 20, 26, 24, Icons.more_horiz_rounded, 16, 'Shuffle', p.toggleShuffle),
      btn(436, 16, 40, 32, Icons.format_quote_outlined, 20, 'Songs in this theme', onOpenMusic),
      btn(488, 16, 40, 32, Icons.format_list_bulleted_rounded, 20, 'Queue', onOpenMusic),
      btn(540, 16, 40, 32, Icons.volume_up_rounded, 20, 'Stop music', t == null ? null : p.close),
    ]);
  }
}
