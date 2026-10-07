// Floating music widget. Made by Claude.
// One instance, switched on and off in Settings (v8.3, D38). Collapsed: song,
// play / pause, next, songs. Expanded: a port of the Figma music widget
// (file YEuK4CL2uyECUhvGEcgCNS, node 4461:2197 "Recently Played", 338 x 354
// plus the transport): current song with its art, previous / play-pause /
// next, then the queue as rows (48 px cover, title, subtitle, and each row's
// own play / pause button in a fixed column, D37). Positioned by FloatingMusic.
import 'package:flutter/material.dart';
import '../../core/audio/music_player.dart';
import '../../core/vision/vision_kit.dart';
import '../theme/theme_living_media.dart';
import 'song_row_parts.dart';

class MusicWidget extends StatelessWidget {
  final VoidCallback onOpenCollection;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  /// False when this screen has no room for the expanded panel.
  final bool canExpand;
  const MusicWidget({
    super.key,
    required this.onOpenCollection,
    this.expanded = false,
    required this.onToggleExpanded,
    this.canExpand = true,
  });

  /// Fixed footprints so FloatingMusic can clamp before layout.
  static const double titleWidth = 96;
  static const Size collapsedSize = Size(5 + 34 + 8 + titleWidth + 4 + 34 + 30 + 30 + 6, 44);
  // Figma 4461:2197: current track 142, list section pad 15 + header 28 +
  // gap 12 + 3 rows (48, gap 8) + pad 15.
  static const int listRows = 3;
  static const double rowHeight = 48, rowGap = 8;
  static const Size expandedSize = Size(338, 142 + 15 + 28 + 12 + listRows * rowHeight + (listRows - 1) * rowGap + 15);
  static const double expandedRadius = 27;

  static TextStyle _sf(double size, FontWeight w, {double opacity = 1}) =>
      VType.callout(weight: w, color: Color.fromRGBO(255, 255, 255, opacity)).copyWith(fontSize: size, height: 16 / size);

  @override
  Widget build(BuildContext context) {
    final p = MusicPlayer.instance;
    return AnimatedBuilder(
      animation: p,
      builder: (_, __) {
        final t = p.current;
        return AnimatedSwitcher(
          duration: VMotion.base,
          transitionBuilder: (c, a) => ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(a),
            alignment: Alignment.topLeft,
            child: FadeTransition(opacity: a, child: c),
          ),
          child: t != null && expanded && canExpand ? _expanded(p, t) : _collapsed(p, t),
        );
      },
    );
  }

  Widget _art(MusicTrack t, double s, {double? radius}) => VPress(
        onTap: onOpenCollection,
        child: radius == null
            ? ClipOval(child: ThemeImage(t.art, width: s, height: s, fit: BoxFit.cover))
            : ClipRRect(borderRadius: BorderRadius.circular(radius), child: ThemeImage(t.art, width: s, height: s, fit: BoxFit.cover)),
      );

  Widget _playPause(MusicPlayer p, double size) => VCircleButton(
        icon: p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: size,
        selected: true,
        tooltip: p.playing ? 'Pause' : 'Play',
        onTap: p.toggle,
      );

  /// Collapsed pill. [t] null: the catalog has no songs yet, said plainly.
  Widget _collapsed(MusicPlayer p, MusicTrack? t) => SizedBox.fromSize(
        key: ValueKey('collapsed-${t == null}'),
        size: canExpand && t != null ? collapsedSize : Size(collapsedSize.width - 30, collapsedSize.height),
        child: VGlass(
          material: VMaterial.elevated,
          radius: VRadius.full,
          padding: const EdgeInsets.fromLTRB(5, 5, 6, 5),
          child: Row(
            children: [
              if (t != null)
                _art(t, 34)
              else
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: VColors.fillCell),
                  child: const Icon(Icons.music_note_rounded, size: 18, color: VColors.textTertiary),
                ),
              const SizedBox(width: 8),
              SizedBox(
                width: titleWidth,
                child: FadeTitle(
                  t?.title ?? '',
                  style: VType.callout(weight: FontWeight.w600, color: t == null ? VColors.textTertiary : VColors.textPrimary),
                ),
              ),
              const SizedBox(width: 4),
              if (t != null) _playPause(p, 34) else const VCircleButton(icon: Icons.play_arrow_rounded, size: 34),
              VCircleButton(icon: Icons.skip_next_rounded, size: 30, tooltip: 'Next', onTap: t == null ? null : p.next),
              if (canExpand && t != null)
                VCircleButton(icon: Icons.queue_music_rounded, size: 30, tooltip: 'Songs', onTap: onToggleExpanded),
            ],
          ),
        ),
      );

  Widget _expanded(MusicPlayer p, MusicTrack t) {
    final q = p.queue;
    final cur = p.index ?? 0;
    final queueName = p.queueId.startsWith('theme:') && t.subtitle.isNotEmpty ? t.subtitle : 'Library';
    return SizedBox.fromSize(
      key: const ValueKey('expanded'),
      size: expandedSize,
      child: VGlass(
        material: VMaterial.elevated,
        radius: expandedRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Track (4461:2203): 142 tall, padding 17, gap 15, white 6 % lift.
            Container(
              height: 142,
              color: const Color(0x0FFFFFFF),
              padding: const EdgeInsets.all(17),
              child: Row(
                children: [
                  _art(t, 108, radius: 7),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Where Figma has the app glyph: hide the song list.
                        Positioned(
                          right: -8,
                          top: -8,
                          child: SongPlayButton(
                            playing: true,
                            icon: Icons.queue_music_rounded,
                            tooltip: 'Hide songs',
                            onTap: onToggleExpanded,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 30,
                          top: 29,
                          child: FadeTitle(t.title, style: _sf(15, FontWeight.w600)),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 29 + 24,
                          child: FadeTitle(t.subtitle.isEmpty ? queueName : t.subtitle, style: _sf(15, FontWeight.w400, opacity: 0.6)),
                        ),
                        // Playback (4461:2213) plus previous / next.
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: Row(
                            children: [
                              VCircleButton(icon: Icons.skip_previous_rounded, size: 28, tooltip: 'Previous', onTap: p.previous),
                              const SizedBox(width: 6),
                              VPress(
                                onTap: p.toggle,
                                tooltip: p.playing ? 'Pause' : 'Play',
                                // Fixed width: Play / Pause never moves Next.
                                child: Container(
                                  height: 28,
                                  width: 86,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0x1AFFFFFF),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(color: VColors.borderLight, width: 0.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(p.playing ? 'Pause' : 'Play', style: _sf(14, FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              VCircleButton(icon: Icons.skip_next_rounded, size: 28, tooltip: 'Next', onTap: p.next),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Recently Played (4461:2217): padding 17 / 13 / 15, gap 12. The
            // right padding is 5 so the 44 px hit column ends 8 px past the
            // 28 px circle, which sits where Figma puts it.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(17, 15, 5, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 28,
                      child: Row(
                        children: [
                          Expanded(child: FadeTitle(queueName.toUpperCase(), style: _sf(11, FontWeight.w600, opacity: 0.6))),
                          VCircleButton(
                            icon: Icons.shuffle_rounded,
                            size: 28,
                            selected: p.shuffle,
                            tooltip: p.shuffle ? 'Shuffle on' : 'Shuffle off',
                            onTap: p.toggleShuffle,
                          ),
                          const SizedBox(width: 6),
                          VCircleButton(
                            icon: p.repeat == MusicRepeat.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                            size: 28,
                            selected: p.repeat != MusicRepeat.off,
                            tooltip: switch (p.repeat) {
                              MusicRepeat.off => 'Repeat off',
                              MusicRepeat.all => 'Repeat all',
                              MusicRepeat.one => 'Repeat one',
                            },
                            onTap: p.cycleRepeat,
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _QueueList(tracks: q, current: cur, playing: p.playing, onTap: (i) {
                        if (i == cur) {
                          p.toggle();
                        } else {
                          p.play(i);
                        }
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The queue as Figma album rows; opens scrolled to the current song.
class _QueueList extends StatefulWidget {
  final List<MusicTrack> tracks;
  final int current;
  final bool playing;
  final ValueChanged<int> onTap;
  const _QueueList({required this.tracks, required this.current, required this.playing, required this.onTap});

  @override
  State<_QueueList> createState() => _QueueListState();
}

class _QueueListState extends State<_QueueList> {
  static const double _pitch = MusicWidget.rowHeight + MusicWidget.rowGap;
  late final ScrollController _ctrl = ScrollController(initialScrollOffset: widget.current * _pitch);

  @override
  void didUpdateWidget(covariant _QueueList old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current && _ctrl.hasClients) {
      final target = (widget.current * _pitch).clamp(0.0, _ctrl.position.maxScrollExtent);
      _ctrl.animateTo(target, duration: const Duration(milliseconds: 360), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        controller: _ctrl,
        padding: EdgeInsets.zero,
        itemExtent: _pitch,
        itemCount: widget.tracks.length,
        itemBuilder: (_, i) {
          final t = widget.tracks[i];
          final playing = widget.playing && i == widget.current;
          return Padding(
            padding: const EdgeInsets.only(bottom: MusicWidget.rowGap),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: ThemeImage(t.art, width: 48, height: 48, fit: BoxFit.cover),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 16,
                        child: FadeTitle(t.title, style: MusicWidget._sf(15, FontWeight.w600)),
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        height: 16,
                        child: FadeTitle(t.subtitle.isEmpty ? 'Library' : t.subtitle, style: MusicWidget._sf(15, FontWeight.w400, opacity: 0.6)),
                      ),
                    ],
                  ),
                ),
                SongPlayButton(playing: playing, onTap: () => widget.onTap(i)),
              ],
            ),
          );
        },
      ),
    );
  }
}
