// Vertical song carousel on the theme screen (v8.2; v8.3 rows, D37).
// The selected song sits in the centre and titles fade with distance. Every
// row has its own play / pause button in a fixed 44 px column at the row's
// end, identical on every row and bound to that row's song; titles have their
// own column and fade out instead of ellipsizing, so nothing moves with the
// title's length. A flat snapping list (no 3D wheel), so a row's button is at
// the same x in every row and every scroll position. Skip sits in the
// mirrored start column at the carousel's vertical centre: fixed to the
// carousel, not to a title. Plays through the shared MusicPlayer queue.
import 'package:flutter/material.dart';

import '../../core/audio/music_player.dart';
import 'song_row_parts.dart';

class SongWheel extends StatefulWidget {
  final List<MusicTrack> tracks;
  /// MusicPlayer queue id this carousel drives, e.g. 'theme:<slug>'.
  final String queueId;
  final double itemExtent;
  final int maxVisible;
  final double width;
  final TextStyle centerStyle;
  final TextStyle sideStyle;

  const SongWheel({
    super.key,
    required this.tracks,
    required this.queueId,
    required this.centerStyle,
    required this.sideStyle,
    this.itemExtent = SongPlayButton.hit,
    this.maxVisible = 3,
    this.width = 300,
  });

  /// Slots shown for [n] songs: odd, at most [max], so a centred selection
  /// shows every song when they fit (no blank or repeated rows).
  static int slotsFor(int n, int max) {
    if (n <= 0) return 0;
    final s = n.isOdd ? n : n + 1;
    return s > max ? max : s;
  }

  static double heightFor(int n, {double itemExtent = SongPlayButton.hit, int maxVisible = 3}) =>
      slotsFor(n, maxVisible) * itemExtent;

  @override
  State<SongWheel> createState() => _SongWheelState();
}

class _SongWheelState extends State<SongWheel> {
  final MusicPlayer _p = MusicPlayer.instance;
  late ScrollController _ctrl;
  late int _sel;
  bool _userScroll = false;

  bool get _active => _p.queueId == widget.queueId && _p.index != null;

  int _initial() {
    if (_active && _p.index! < widget.tracks.length) return _p.index!;
    // Like the cover-flow (App.tsx fetchSongs), start centred on length ~/ 2.
    return widget.tracks.length ~/ 2;
  }

  @override
  void initState() {
    super.initState();
    _sel = _initial();
    _ctrl = ScrollController(initialScrollOffset: _sel * widget.itemExtent);
    _p.addListener(_onPlayer);
  }

  @override
  void didUpdateWidget(covariant SongWheel old) {
    super.didUpdateWidget(old);
    if (old.queueId != widget.queueId || old.tracks.length != widget.tracks.length) {
      _sel = _initial();
      if (_ctrl.hasClients) _ctrl.jumpTo(_sel * widget.itemExtent);
    }
  }

  @override
  void dispose() {
    _p.removeListener(_onPlayer);
    _ctrl.dispose();
    super.dispose();
  }

  void _centre(int i) {
    _sel = i;
    if (_ctrl.hasClients) {
      _ctrl.animateTo(i * widget.itemExtent, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    }
  }

  void _onPlayer() {
    if (!mounted) return;
    // Follow the player (skip, auto-advance, widget transport).
    if (_active && _p.index != _sel && _p.index! < widget.tracks.length && !_userScroll) _centre(_p.index!);
    setState(() {});
  }

  bool _playingRow(int i) => _active && _p.playing && _p.index == i;

  /// The row's own button: plays that row's song, or pauses it while it plays.
  void _tapRow(int i) {
    if (_active && _p.index == i) {
      _p.toggle();
    } else {
      _p.playQueue(widget.tracks, i, id: widget.queueId);
    }
    _centre(i);
  }

  void _skip() {
    if (_active) {
      _p.next();
    } else {
      _p.playQueue(widget.tracks, (_sel + 1) % widget.tracks.length, id: widget.queueId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.tracks.length;
    if (n == 0) return const SizedBox.shrink();
    final ext = widget.itemExtent;
    final h = SongWheel.heightFor(n, itemExtent: ext, maxVisible: widget.maxVisible);
    const col = SongPlayButton.hit;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: h,
        child: Stack(
          children: [
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: (s) {
                  if (s is ScrollStartNotification && s.dragDetails != null) _userScroll = true;
                  if (s is ScrollEndNotification) {
                    _userScroll = false;
                    final i = (_ctrl.offset / ext).round().clamp(0, n - 1);
                    if (i != _sel) setState(() => _sel = i);
                  }
                  return false;
                },
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false, overscroll: false),
                  child: ListView.builder(
                    controller: _ctrl,
                    physics: _SnapPhysics(ext, parent: const ClampingScrollPhysics()),
                    padding: EdgeInsets.symmetric(vertical: (h - ext) / 2),
                    itemExtent: ext,
                    itemCount: n,
                    itemBuilder: (_, i) => _row(i, col),
                  ),
                ),
              ),
            ),
            // Skip: the start column at the carousel's centre (fixed spot).
            Positioned(
              left: 0,
              top: (h - col) / 2,
              child: SongPlayButton(
                playing: false,
                icon: Icons.skip_next_rounded,
                tooltip: 'Skip',
                onTap: _skip,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(int i, double col) {
    final t = widget.tracks[i];
    final playing = _playingRow(i);
    return Row(
      children: [
        const SizedBox(width: SongPlayButton.hit), // mirrors the button column
        Expanded(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final off = _ctrl.hasClients ? _ctrl.offset : _sel * widget.itemExtent;
              final d = ((i * widget.itemExtent - off).abs() / widget.itemExtent).clamp(0.0, 2.0);
              final style = TextStyle.lerp(widget.centerStyle, widget.sideStyle, d.clamp(0.0, 1.0))!;
              // Distance falloff on the titles only; buttons stay identical.
              final opacity = d <= 1 ? 1 - 0.38 * d : 0.62 - 0.27 * (d - 1);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _centre(i),
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: FadeTitle(
                    t.title,
                    style: style,
                    align: Alignment.center,
                    semanticsLabel: playing ? '${t.title}, playing' : null,
                  ),
                ),
              );
            },
          ),
        ),
        SongPlayButton(playing: playing, onTap: () => _tapRow(i)),
      ],
    );
  }
}

/// Settles on a whole row, so a row always rests in the centre.
class _SnapPhysics extends ScrollPhysics {
  final double extent;
  const _SnapPhysics(this.extent, {super.parent});

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) => _SnapPhysics(extent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final base = super.createBallisticSimulation(position, velocity);
    final projected = base?.x(10) ?? position.pixels;
    final target = ((projected / extent).round() * extent).clamp(position.minScrollExtent, position.maxScrollExtent);
    final tol = toleranceFor(position);
    if ((target - position.pixels).abs() < tol.distance && velocity.abs() < tol.velocity) return null;
    return ScrollSpringSimulation(spring, position.pixels, target.toDouble(), velocity, tolerance: tol);
  }
}
