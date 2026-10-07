// Floating music widget host. Made by Claude.
// v8.3 (DEVIATIONS.md D38): exactly one widget, and only when the user has
// switched it on (Settings > Music widget; off by default, kept in
// SharedPreferences). It never appears by itself: playing a song does not
// show it. Once on, it can be dragged and pinned anywhere inside the safe
// area above the bottom bar, the theme screen included; it stays exactly
// where it is put, and the spot is kept in SharedPreferences. It overlays
// the app (own Stack layer), so nothing underneath moves, and its drag state
// is local: dragging does not rebuild the app shell or the market.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/music_player.dart';
import '../../core/media/theme_catalog.dart';
import '../theme/premium_market_ambient.dart' show AmbientGlass;
import 'music_widget.dart';
import 'music_zones.dart';

class FloatingMusic extends StatefulWidget {
  final VoidCallback onOpenCollection;
  /// Over the theme market (web): hand the widget's rect to the DOM ambient
  /// so the video behind it is blurred like the bar's glass.
  final bool overMarket;
  /// Full-screen focused surfaces (music drawer, consensus, theme detail,
  /// message zoom, local history) own the screen: no widget there.
  final bool hidden;
  const FloatingMusic({super.key, required this.onOpenCollection, this.overMarket = false, this.hidden = false});

  // PermanentNavBar: Positioned bottom 12 inside SafeArea, 56 tall.
  static const double barBottom = 12;
  static const double barHeight = 56;
  static const double gap = 8;
  static const String prefsKey = 'music_widget_pos_v1';
  static const String enabledKey = 'music_widget_on_v1';

  /// THE on / off switch (Settings > Music widget). Off by default.
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
  static Future<void>? _loading;

  static Future<void> loadEnabled() => _loading ??= () async {
        try {
          enabled.value = (await SharedPreferences.getInstance()).getBool(enabledKey) ?? false;
        } catch (_) {}
      }();

  static Future<void> setEnabled(bool on) async {
    enabled.value = on;
    try {
      await (await SharedPreferences.getInstance()).setBool(enabledKey, on);
    } catch (_) {}
  }

  /// Default (first switch-on): centred near the top, under the theme
  /// screen's search field (top 48-98 at 430 px) and clear of the bottom
  /// composer and bar. The user moves it anywhere from there.
  static Offset dock(Size screen, EdgeInsets pad, Size s) => Offset((screen.width - s.width) / 2, pad.top + 108);

  /// [want] clamped into the safe area, above the bar's zone. Null when a
  /// widget of size [s] does not fit on this screen at all.
  static Rect? place(Size screen, EdgeInsets pad, Size s, Offset want) {
    final minX = pad.left + gap, minY = pad.top + gap;
    final maxX = screen.width - pad.right - gap - s.width;
    final maxY = screen.height - pad.bottom - barBottom - barHeight - gap - s.height;
    if (maxX < minX || maxY < minY) return null;
    return Offset(want.dx.clamp(minX, maxX), want.dy.clamp(minY, maxY)) & s;
  }

  @override
  State<FloatingMusic> createState() => _FloatingMusicState();
}

class _FloatingMusicState extends State<FloatingMusic> {
  Offset? _want; // where the user pinned it (top-left of the collapsed widget)
  bool _expanded = false;
  Rect? _published;

  @override
  void initState() {
    super.initState();
    FloatingMusic.loadEnabled();
    FloatingMusic.enabled.addListener(_onEnabled);
    _load();
  }

  @override
  void dispose() {
    FloatingMusic.enabled.removeListener(_onEnabled);
    if (_published != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => MusicZones.widgetGlass.value = null);
    }
    super.dispose();
  }

  void _onEnabled() {
    // Switched on with nothing loaded: the library's first song, ready.
    final p = MusicPlayer.instance;
    if (FloatingMusic.enabled.value && p.index == null) p.cue(MusicPlayer.library, 0);
    if (!FloatingMusic.enabled.value) _expanded = false;
  }

  Future<void> _load() async {
    try {
      final s = (await SharedPreferences.getInstance()).getString(FloatingMusic.prefsKey);
      final parts = s?.split(',');
      if (parts != null && parts.length == 2 && mounted) {
        final x = double.tryParse(parts[0]), y = double.tryParse(parts[1]);
        if (x != null && y != null) setState(() => _want = Offset(x, y));
      }
    } catch (_) {}
    _onEnabled();
  }

  Future<void> _save(Offset o) async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(FloatingMusic.prefsKey, '${o.dx.toStringAsFixed(1)},${o.dy.toStringAsFixed(1)}');
    } catch (_) {}
  }

  void _publish(Rect? r, double radius) {
    final g = r == null ? null : AmbientGlass(r, radius, 28);
    if (MusicZones.widgetGlass.value == g) return;
    _published = r;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) MusicZones.widgetGlass.value = g;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screen = mq.size;
    final pad = mq.padding;
    return ListenableBuilder(
      listenable: Listenable.merge([MusicPlayer.instance, FloatingMusic.enabled, ThemeCatalog.instance]),
      builder: (context, _) {
        // No songs in the catalog: no widget at all (v8.3, D46).
        final visible = FloatingMusic.enabled.value && !widget.hidden && MusicPlayer.library.isNotEmpty;
        // On with nothing loaded (e.g. the catalog arrived after switch-on).
        if (FloatingMusic.enabled.value && MusicPlayer.instance.index == null && MusicPlayer.library.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onEnabled());
        }
        const cs = MusicWidget.collapsedSize;
        final want = _want ?? FloatingMusic.dock(screen, pad, cs);
        final collapsed = visible ? FloatingMusic.place(screen, pad, cs, want) : null;
        // Expanded: grows from the pinned spot, slid back inside the screen.
        final expanded = collapsed == null || MusicPlayer.instance.current == null
            ? null
            : FloatingMusic.place(screen, pad, MusicWidget.expandedSize, collapsed.topLeft);
        final showExpanded = _expanded && expanded != null;
        final rect = showExpanded ? expanded : collapsed;
        _publish(rect != null && widget.overMarket ? rect : null,
            showExpanded ? MusicWidget.expandedRadius : cs.height / 2);
        if (rect == null) return const SizedBox.shrink();
        return Stack(
          children: [
            Positioned(
              left: rect.left,
              top: rect.top,
              child: GestureDetector(
                onPanUpdate: (d) => setState(() {
                  // Follows the finger; dragging the open panel moves its pin.
                  final from = showExpanded ? expanded.topLeft : collapsed!.topLeft;
                  _want = FloatingMusic.place(screen, pad, cs, from + d.delta)?.topLeft ?? from;
                }),
                onPanEnd: (_) {
                  final o = _want ?? want;
                  _save(o);
                },
                child: MusicWidget(
                  onOpenCollection: widget.onOpenCollection,
                  expanded: showExpanded,
                  canExpand: expanded != null,
                  onToggleExpanded: () => setState(() => _expanded = !_expanded),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
