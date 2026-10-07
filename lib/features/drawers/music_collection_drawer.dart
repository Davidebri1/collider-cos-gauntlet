import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/audio/music_player.dart';
import '../../core/figma/figma_stage.dart';
import '../../core/media/theme_catalog.dart';
import '../../core/vision/vision_kit.dart';
import '../../models/theme_def.dart';
import '../theme/theme_living_media.dart';

/// Files -> Music (map row 20, Figma YEuK4CL2uyECUhvGEcgCNS 417:6219
/// "Spotify", 1488 x 938). v8.4: a straight copy of the frame, laid out at
/// its own size and scaled as one unit (crop = the window, 1488 Figma px =
/// screen width). Real data replaces the sample content:
///   nav panel (47, 68) 524 x 136 .......... Home / Search
///   library panel (46, 214) 525 x 679 ..... "Your Library": chips filter
///     Playlists (theme packs with songs) / Songs; search; Recents / A-Z;
///     first row = all songs (Play all); + opens the theme market; -> plays all
///   main panel (582, 64) 867 x 829 ........ back / forward (view history),
///     search pill (searches songs), Upgrade (plans), people (settings),
///     person (account); greeting by time of day; 2 x 3 pack cards 389 x 80;
///     "Made For You" 3 tiles 254 (art 215) + Show all (every song)
///   dots (1413, 24) ........................ glass menu: Shuffle, Repeat, Close
class MusicCollectionDrawer extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onOpenMarket;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenSettings;
  const MusicCollectionDrawer({super.key, required this.onClose, this.onOpenMarket, this.onOpenAccount, this.onOpenSettings});

  static const frame = Size(1488, 938);
  static const double cropWidth = 1488;

  @override
  State<MusicCollectionDrawer> createState() => _MusicCollectionDrawerState();
}

class _Pack {
  final WallpaperTheme theme;
  final List<MusicTrack> songs;
  _Pack(this.theme, this.songs);
}

class _MusicCollectionDrawerState extends State<MusicCollectionDrawer> {
  // Main panel view: 'home' | 'all' | 'search' | 'pack:<id>'.
  String _view = 'home';
  final List<String> _back = [];
  final List<String> _fwd = [];
  bool _songsChip = false; // false = Playlists, true = Songs
  bool _az = false;
  bool _libSearch = false;
  final _q = TextEditingController();
  final _libQ = TextEditingController();
  final _qFocus = FocusNode();

  static const _white10 = Color(0x1AFFFFFF);
  static const _sub = Color(0xFFBDBDBD);

  List<_Pack> get _packs => [
        for (final t in ThemeCatalog.instance.allThemes)
          if (MusicPlayer.themeTracks(t.id).isNotEmpty) _Pack(t, MusicPlayer.themeTracks(t.id)),
      ];

  void _go(String v) {
    if (v == _view) return;
    setState(() {
      _back.add(_view);
      _fwd.clear();
      _view = v;
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');
  }

  void _playList(List<MusicTrack> q, int i, String id) {
    final p = MusicPlayer.instance;
    if (p.queueId == id && p.index == i) {
      p.toggle();
    } else {
      p.playQueue(q, i, id: id);
    }
  }

  @override
  void dispose() {
    _q.dispose();
    _libQ.dispose();
    _qFocus.dispose();
    super.dispose();
  }

  // ── small parts (Figma px) ─────────────────────────────────────────────
  // Figma panel fill: black 30 % over white 10 % (main panel adds a
  // rgba(0,163,255,.2) -> transparent vertical gradient on top), radius 10,
  // inset specular -1 / 1 white 35 %.
  Widget _panel({required Widget child, bool blueTint = false}) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: Color(0x1AFFFFFF)),
          const ColoredBox(color: Color(0x4D000000)),
          if (blueTint)
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x3300A3FF), Color(0x0000A3FF)]))),
          const DecoratedBox(decoration: BoxDecoration(border: Border(top: BorderSide(color: Color(0x59FFFFFF), width: 1), right: BorderSide(color: Color(0x59FFFFFF), width: 1)))),
          child,
        ]),
      );

  Widget _tap(String label, VoidCallback? onTap, Widget child) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
      );

  Widget _circle(IconData i, String label, VoidCallback? onTap) => _tap(
        label,
        onTap,
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x66000000)),
          child: Icon(i, size: 24, color: onTap == null ? Colors.white38 : Colors.white),
        ),
      );

  Widget _art(String src, double size, {double radius = 5, bool circle = false}) => ClipRRect(
        borderRadius: BorderRadius.circular(circle ? size / 2 : radius),
        child: SizedBox(width: size, height: size, child: ThemeImage(src, fit: BoxFit.cover, width: size, height: size)),
      );

  Widget _chip(String t, bool on, VoidCallback onTap) => _tap(
        t,
        onTap,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: on ? Colors.white : const Color(0x66000000), borderRadius: BorderRadius.circular(30)),
          child: FText(t, size: 18, height: 25, weight: FontWeight.w500, color: on ? Colors.black : Colors.white),
        ),
      );

  Widget _row({required Widget art, required String title, required String sub, required bool current, required VoidCallback? onTap, bool bold = false}) => _tap(
        title,
        onTap,
        SizedBox(
          height: 64,
          child: Row(children: [
            art,
            const SizedBox(width: 14),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                FText(title, size: 20, height: 28, weight: bold ? FontWeight.w500 : FontWeight.w400, color: current ? const Color(0xFF1ED760) : Colors.white),
                const SizedBox(height: 7),
                FText(sub, size: 18, height: 25, color: _sub),
              ]),
            ),
          ]),
        ),
      );

  // ── library panel (46, 214) 525 x 679 ───────────────────────────────────
  Widget _library(MusicPlayer p) {
    final packs = _packs;
    final lib = MusicPlayer.library;
    final q = _libQ.text.trim().toLowerCase();
    var packRows = packs.where((e) => q.isEmpty || e.theme.name.toLowerCase().contains(q)).toList();
    var songRows = [for (var i = 0; i < lib.length; i++) i].where((i) => q.isEmpty || lib[i].title.toLowerCase().contains(q)).toList();
    if (_az) {
      packRows.sort((a, b) => a.theme.name.toLowerCase().compareTo(b.theme.name.toLowerCase()));
      songRows.sort((a, b) => lib[a].title.toLowerCase().compareTo(lib[b].title.toLowerCase()));
    }
    final libActive = p.queueId == 'library' && p.index != null;
    final cur = p.current;
    return _panel(
      child: Stack(children: [
        Positioned(
          left: 48,
          top: 42,
          child: Row(children: [
            const Icon(Icons.library_music_rounded, size: 28, color: Colors.white),
            const SizedBox(width: 16),
            const FText('Your Library', size: 20, height: 28, weight: FontWeight.w700),
          ]),
        ),
        if (widget.onOpenMarket != null)
          Positioned(left: 439, top: 43, child: _tap('Get more music', widget.onOpenMarket, const SizedBox(width: 26, height: 26, child: Icon(Icons.add_rounded, size: 26, color: Color(0xFFB3B3B3))))),
        Positioned(left: 489, top: 43, child: _tap('Play all', () => _playList(lib, 0, 'library'), const SizedBox(width: 26, height: 26, child: Icon(Icons.arrow_forward_rounded, size: 24, color: Color(0xFFB3B3B3))))),
        Positioned(left: 35, top: 98, child: Row(children: [_chip('Playlists', !_songsChip, () => setState(() => _songsChip = false)), const SizedBox(width: 6), _chip('Songs', _songsChip, () => setState(() => _songsChip = true))])),
        Positioned(
          left: 45,
          top: 162,
          width: 330,
          height: 24,
          child: Row(children: [
            _tap('Search your library', () => setState(() => _libSearch = !_libSearch), const Icon(Icons.search_rounded, size: 24, color: Colors.white)),
            if (_libSearch) ...[
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _libQ,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero, hintText: 'Search', hintStyle: TextStyle(color: Color(0x99FFFFFF), fontSize: 18)),
                ),
              ),
            ],
          ]),
        ),
        Positioned(
          left: 402,
          top: 152,
          child: _tap(
            _az ? 'Sort: A-Z' : 'Sort: Recents',
            () => setState(() => _az = !_az),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                FText(_az ? 'A-Z' : 'Recents', size: 18, height: 25, weight: FontWeight.w500, color: const Color(0xFFB8B8B8)),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_drop_down_rounded, size: 22, color: Color(0xFFB8B8B8)),
              ]),
            ),
          ),
        ),
        // Rows from y 209 (Figma 188 + 21), pitch 82.
        Positioned(
          left: 34,
          right: 16,
          top: 209,
          bottom: 0,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _row(
                art: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFC900DB), Color(0xFF02738C)]),
                  ),
                  child: Icon(libActive && p.playing ? Icons.pause_rounded : Icons.music_note_rounded, size: 24, color: Colors.white),
                ),
                title: 'All Songs',
                sub: 'Playlist . ${lib.length} songs',
                bold: true,
                current: libActive,
                onTap: () => libActive ? p.toggle() : _playList(lib, 0, 'library'),
              ),
              const SizedBox(height: 18),
              if (!_songsChip)
                for (final e in packRows) ...[
                  _row(
                    art: _art(e.theme.posterUrl, 64),
                    title: e.theme.name,
                    sub: 'Playlist . ${e.songs.length} ${e.songs.length == 1 ? 'song' : 'songs'}',
                    current: p.queueId == 'pack:${e.theme.id}',
                    onTap: () => _go('pack:${e.theme.id}'),
                  ),
                  const SizedBox(height: 18),
                ]
              else
                for (final i in songRows) ...[
                  _row(
                    art: _art(lib[i].art, 64),
                    title: lib[i].title,
                    sub: lib[i].subtitle.isEmpty ? 'Song' : 'Song . ${lib[i].subtitle}',
                    current: cur != null && cur.key == lib[i].key && libActive && p.index == i,
                    onTap: lib[i].playable ? () => _playList(lib, i, 'library') : null,
                  ),
                  const SizedBox(height: 18),
                ],
            ],
          ),
        ),
      ]),
    );
  }

  // ── main panel content (frame coords) ───────────────────────────────────
  List<Widget> _home(MusicPlayer p) {
    final packs = _packs;
    final cards = packs.take(6).toList();
    final made = packs.skip(6).take(3).toList();
    final madeList = made.isEmpty ? packs.take(3).toList() : made;
    const cardPos = [Offset(611, 241), Offset(1030, 241), Offset(611, 336), Offset(1030, 336), Offset(611, 431), Offset(1030, 431)];
    const tileX = [611.0, 889.0, 1167.0];
    return [
      Positioned(left: 613, top: 167, height: 51, child: Align(alignment: Alignment.centerLeft, child: FText(_greeting, size: 36, weight: FontWeight.w700))),
      for (var i = 0; i < cards.length; i++)
        Positioned(
          left: cardPos[i].dx,
          top: cardPos[i].dy,
          width: 389,
          height: 80,
          child: _tap(
            cards[i].theme.name,
            () => _go('pack:${cards[i].theme.id}'),
            Container(
              decoration: BoxDecoration(color: _white10, borderRadius: BorderRadius.circular(5)),
              child: Row(children: [
                _art(cards[i].theme.posterUrl, 80),
                const SizedBox(width: 19),
                Expanded(child: FText(cards[i].theme.name, size: 20, height: 28, weight: FontWeight.w700)),
                const SizedBox(width: 12),
              ]),
            ),
          ),
        ),
      if (madeList.isNotEmpty) ...[
        const Positioned(left: 611, top: 553, height: 45, child: Align(alignment: Alignment.centerLeft, child: FText('Made For You', size: 32, weight: FontWeight.w700))),
        Positioned(
          left: 1349,
          top: 566,
          width: 70,
          height: 25,
          child: _tap('Show all', () => _go('all'), const Center(child: FText('Show all', size: 18, weight: FontWeight.w500, opacity: 0.65))),
        ),
        for (var i = 0; i < madeList.length; i++)
          Positioned(
            left: tileX[i],
            top: 623,
            width: 254,
            height: 254,
            child: _tap(
              madeList[i].theme.name,
              () => _go('pack:${madeList[i].theme.id}'),
              Container(
                decoration: BoxDecoration(color: const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(5)),
                padding: const EdgeInsets.fromLTRB(20, 17, 19, 22),
                child: _art(madeList[i].theme.posterUrl, 215),
              ),
            ),
          ),
      ],
    ];
  }

  List<Widget> _list(MusicPlayer p, String title, List<MusicTrack> songs, String queueId, {String? art}) {
    final cur = p.current;
    return [
      Positioned(left: 613, top: 167, height: 51, width: 800, child: Align(alignment: Alignment.centerLeft, child: FText(title, size: 36, weight: FontWeight.w700))),
      Positioned(
        left: 611,
        top: 241,
        width: 808,
        height: 636,
        child: songs.isEmpty
            ? const Align(alignment: Alignment.topLeft, child: FText('No songs found', size: 20, color: _sub))
            : ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: songs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 18),
                itemBuilder: (_, i) {
                  final on = p.queueId == queueId && p.index == i;
                  return Row(children: [
                    Expanded(
                      child: _row(
                        art: _art(art ?? songs[i].art, 64),
                        title: songs[i].title,
                        sub: songs[i].subtitle.isEmpty ? 'Song' : songs[i].subtitle,
                        current: on && cur != null,
                        onTap: songs[i].playable ? () => _playList(songs, i, queueId) : null,
                      ),
                    ),
                    if (songs[i].playable)
                      _tap(
                        on && p.playing ? 'Pause' : 'Play',
                        () => _playList(songs, i, queueId),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x1AFFFFFF)),
                          child: Icon(on && p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 26, color: Colors.white),
                        ),
                      ),
                  ]);
                },
              ),
      ),
    ];
  }

  List<Widget> _mainView(MusicPlayer p) {
    final lib = MusicPlayer.library;
    if (_view == 'all') return _list(p, 'All Songs', lib, 'library');
    if (_view == 'search') {
      final q = _q.text.trim().toLowerCase();
      final hits = q.isEmpty ? <MusicTrack>[] : lib.where((t) => t.title.toLowerCase().contains(q) || t.subtitle.toLowerCase().contains(q)).toList();
      return _list(p, q.isEmpty ? 'Search' : 'Results', hits, 'search:$q');
    }
    if (_view.startsWith('pack:')) {
      final id = _view.substring(5);
      final pk = _packs.where((e) => e.theme.id == id).toList();
      if (pk.isNotEmpty) return _list(p, pk.first.theme.name, pk.first.songs, 'pack:$id', art: pk.first.theme.posterUrl);
    }
    return _home(p);
  }

  void _menu() {
    final p = MusicPlayer.instance;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, _, __) => AnimatedBuilder(
        animation: p,
        builder: (ctx, _) => Stack(children: [
          Positioned.fill(child: GestureDetector(onTap: () => Navigator.of(ctx).pop())),
          Center(
            child: Material(
              type: MaterialType.transparency,
              child: GlassMenu(rows: [
                GlassMenuRow(icon: Icons.shuffle_rounded, label: 'Shuffle', on: p.shuffle, onTap: p.toggleShuffle),
                GlassMenuRow(icon: p.repeat == MusicRepeat.one ? Icons.repeat_one_rounded : Icons.repeat_rounded, label: switch (p.repeat) { MusicRepeat.off => 'Repeat off', MusicRepeat.all => 'Repeat all', MusicRepeat.one => 'Repeat one' }, on: p.repeat != MusicRepeat.off, onTap: p.cycleRepeat),
                GlassMenuRow(icon: Icons.close_rounded, label: 'Close', toggle: false, onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onClose();
                }),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = MusicPlayer.instance;
    final size = MediaQuery.sizeOf(context);
    final k = size.width / MusicCollectionDrawer.cropWidth;
    return Stack(fit: StackFit.expand, children: [
      // Tap outside the window closes it (no scrim: the frame has none).
      GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onClose),
      FigmaStage(
        frame: MusicCollectionDrawer.frame,
        cropWidth: MusicCollectionDrawer.cropWidth,
        center: const Offset(744, 469),
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: 1488,
            height: 938,
            child: GestureDetector(
              onTap: () {},
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: (98 / 2 * k).clamp(0.0, 40.0), sigmaY: (98 / 2 * k).clamp(0.0, 40.0)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0x0DFFFFFF),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white, width: 1),
                      boxShadow: const [BoxShadow(color: Color(0x0D000000), offset: Offset(0, 24), blurRadius: 30)],
                    ),
                    child: AnimatedBuilder(
                      animation: p,
                      builder: (context, _) => Stack(children: [
                        // App mark (sample "Spotify" logo -> the app's Music mark).
                        const Positioned(
                          left: 46,
                          top: 23,
                          height: 29,
                          child: Row(children: [
                            Icon(Icons.graphic_eq_rounded, size: 29, color: Color(0xFF1ED760)),
                            SizedBox(width: 6),
                            FText('Music', size: 22, weight: FontWeight.w700),
                          ]),
                        ),
                        Positioned(left: 1413, top: 24, child: _tap('More', _menu, const SizedBox(width: 36, height: 36, child: Icon(Icons.more_horiz_rounded, size: 36, color: Colors.white)))),
                        // Nav panel.
                        Positioned(
                          left: 47,
                          top: 68,
                          width: 524,
                          height: 136,
                          child: _panel(
                            child: Stack(children: [
                              Positioned(
                                left: 30,
                                top: 24,
                                child: _tap('Home', () => _go('home'), Row(children: [Icon(Icons.home_filled, size: 28, color: Colors.white.withValues(alpha: _view == 'home' ? 1 : 0.7)), const SizedBox(width: 24), FText('Home', size: 20, height: 28, weight: FontWeight.w700, opacity: _view == 'home' ? 1 : 0.7)])),
                              ),
                              Positioned(
                                left: 30,
                                top: 84,
                                child: _tap('Search', () {
                                  _go('search');
                                  _qFocus.requestFocus();
                                }, Row(children: [Icon(Icons.search_rounded, size: 28, color: Colors.white.withValues(alpha: _view == 'search' ? 1 : 0.7)), const SizedBox(width: 24), FText('Search', size: 20, height: 28, opacity: _view == 'search' ? 1 : 0.7)])),
                              ),
                            ]),
                          ),
                        ),
                        Positioned(left: 46, top: 214, width: 525, height: 679, child: _library(p)),
                        // Main panel.
                        Positioned(
                          left: 582,
                          top: 64,
                          width: 867,
                          height: 829,
                          child: _panel(blueTint: true, child: const SizedBox.expand()),
                        ),
                        // Main header (frame coords).
                        Positioned(left: 609, top: 83, child: _circle(Icons.chevron_left_rounded, 'Back', _back.isEmpty ? null : () => setState(() {
                              _fwd.add(_view);
                              _view = _back.removeLast();
                            }))),
                        Positioned(left: 661, top: 83, child: _circle(Icons.chevron_right_rounded, 'Forward', _fwd.isEmpty ? null : () => setState(() {
                              _back.add(_view);
                              _view = _fwd.removeLast();
                            }))),
                        Positioned(
                          left: 738,
                          top: 80,
                          width: 425,
                          height: 48,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(16)),
                            child: Row(children: [
                              const Icon(Icons.search_rounded, size: 24, color: Colors.white),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _q,
                                  focusNode: _qFocus,
                                  onTap: () => _go('search'),
                                  onChanged: (_) => setState(() => _view = 'search'),
                                  style: const TextStyle(fontSize: 20, color: Colors.white, letterSpacing: 0.6),
                                  cursorColor: Colors.white,
                                  decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero, hintText: 'Search songs', hintStyle: TextStyle(fontSize: 20, color: Color(0x99FFFFFF), letterSpacing: 0.6)),
                                ),
                              ),
                            ]),
                          ),
                        ),
                        if (widget.onOpenAccount != null)
                          Positioned(
                            left: 1198,
                            top: 84,
                            child: _tap('Upgrade', widget.onOpenAccount, Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                              child: const FText('Upgrade', size: 18, height: 25, weight: FontWeight.w500, color: Colors.black),
                            )),
                          ),
                        Positioned(left: 1317, top: 83, child: _circle(Icons.group_rounded, 'Settings', widget.onOpenSettings)),
                        Positioned(left: 1369, top: 83, child: _circle(Icons.person_outline_rounded, 'Account', widget.onOpenAccount)),
                        ..._mainView(p),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ]);
  }
}
