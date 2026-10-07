// Music player state. Made by Claude.
// v8.2: one shared queue for the theme-screen song carousel, the floating
// widget, the Files > Music tab and the music drawer. Songs come only from the
// runtime catalog (theme tracks + ambientTracks); there are no placeholders.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import '../media/theme_catalog.dart';
// Audio: HTMLAudioElement on web, just_audio on iOS / Android (v8.3, D25).
import 'audio_engine_native.dart' if (dart.library.js_interop) 'audio_engine_web.dart';

class MusicTrack {
  final String title;
  final String art;
  final String file; // streamable URL or bundled asset path; '' = title only
  final String subtitle; // theme name for pack songs
  final String? themeId; // the pack this row belongs to; null = ambient
  const MusicTrack(this.title, this.art, this.file, {this.subtitle = '', this.themeId});

  /// Identity used to dedupe the library: the audio file, else the title.
  String get key => file.isNotEmpty ? file : 'title:${title.toLowerCase()}';
  bool get playable => file.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is MusicTrack && other.key == key && other.title == title && other.themeId == themeId;
  @override
  int get hashCode => Object.hash(key, title, themeId);
}

enum MusicRepeat { off, all, one }

class MusicPlayer extends ChangeNotifier {
  MusicPlayer._() {
    _engine.onEnded = _onEnded;
  }
  static final MusicPlayer instance = MusicPlayer._();

  /// THE theme -> songs mapping (single source of truth, D24): a theme's real
  /// songs (blank titles dropped, repeats within the pack dropped), in
  /// catalog order, each tagged with that theme's id, name and poster. The
  /// theme carousel, the widget queue, Files > Music and the Music drawer
  /// all read this.
  static List<MusicTrack> themeTracks(String slug) {
    final t = ThemeCatalog.instance.bySlug(slug);
    if (t == null) return const [];
    final seen = <String>{};
    final out = <MusicTrack>[];
    for (final s in t.tracks) {
      if (s.title.trim().isEmpty) continue;
      final m = MusicTrack(s.title.trim(), t.posterUrl, s.audioUrl ?? '', subtitle: _clean(t.name), themeId: t.id);
      if (seen.add(m.key)) out.add(m);
    }
    return out;
  }

  /// Every song in the catalog, grouped by theme in catalog order: each
  /// theme's [themeTracks] exactly (a song that genuinely belongs to two
  /// packs is listed under both), then the ambientTracks that are not
  /// already a pack song. No cross-theme dedupe, so no song is ever moved
  /// to another theme's name or art (the v8.2 H5 bug).
  static List<MusicTrack> get library {
    final out = <MusicTrack>[];
    final inPacks = <String>{};
    for (final t in ThemeCatalog.instance.allThemes) {
      for (final m in themeTracks(t.id)) {
        out.add(m);
        inPacks.add(m.key);
      }
    }
    final seen = <String>{};
    for (final a in ThemeCatalog.instance.ambientTracks) {
      if (a.title.trim().isEmpty) continue;
      final m = MusicTrack(a.title.trim(), a.artUrl, a.audioUrl);
      if (!inPacks.contains(m.key) && seen.add(m.key)) out.add(m);
    }
    return out;
  }

  static String _clean(String n) => n.replaceAll(RegExp(r'\s*4K$'), '').trim();

  /// The current queue, or the whole library when nothing was queued.
  static List<MusicTrack> get tracks => instance._queue ?? library;

  final AudioEngine _engine = AudioEngine();
  final math.Random _rng = math.Random();
  List<MusicTrack>? _queue;
  String _queueId = 'library';
  int? index; // null = nothing loaded
  bool playing = false;
  bool shuffle = false;
  MusicRepeat repeat = MusicRepeat.off;

  /// 'library' or 'theme:<slug>'.
  String get queueId => _queueId;
  List<MusicTrack> get queue => tracks;

  MusicTrack? get current {
    final t = tracks;
    return index == null || index! >= t.length ? null : t[index!];
  }

  /// Plays [i] of [q] and makes [q] the queue (the carousel / Files tab).
  void playQueue(List<MusicTrack> q, int i, {String id = 'library'}) {
    if (q.isEmpty) return;
    _queue = List.unmodifiable(q);
    _queueId = id;
    play(i);
  }

  /// Loads [i] of [q] as the queue without playing (the widget, switched on
  /// with nothing loaded, shows the library's first song ready to play).
  void cue(List<MusicTrack> q, int i, {String id = 'library'}) {
    if (q.isEmpty) return;
    _queue = List.unmodifiable(q);
    _queueId = id;
    index = i.clamp(0, q.length - 1);
    playing = false;
    notifyListeners();
  }

  void play(int i) {
    final t = tracks;
    if (t.isEmpty) return;
    index = i.clamp(0, t.length - 1);
    final f = t[index!].file;
    if (f.isEmpty) {
      // Title-only pack song: selectable, nothing to stream.
      _engine.pause();
      playing = false;
    } else {
      // Remote tracks stream directly; bundled assets live under /assets/<path> on web.
      _engine.play(f.startsWith('http') ? f : 'assets/$f');
      playing = true;
    }
    notifyListeners();
  }

  void toggle() {
    if (tracks.isEmpty) return;
    if (index == null) return play(0);
    if (playing) {
      _engine.pause();
      playing = false;
      notifyListeners();
    } else {
      play(index!);
    }
  }

  int _step(int dir) {
    final n = tracks.length;
    final i = index ?? (dir > 0 ? -1 : 0);
    if (shuffle && n > 1) {
      var j = _rng.nextInt(n - 1);
      if (j >= i) j++;
      return j;
    }
    return (i + dir + n) % n;
  }

  void next() {
    if (tracks.isNotEmpty) play(_step(1));
  }

  void previous() {
    if (tracks.isNotEmpty) play(_step(-1));
  }

  void _onEnded() {
    if (tracks.isEmpty || index == null) return;
    if (repeat == MusicRepeat.one) return play(index!);
    final last = index! >= tracks.length - 1;
    if (last && repeat == MusicRepeat.off && !shuffle) {
      playing = false;
      notifyListeners();
      return;
    }
    next();
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    notifyListeners();
  }

  void cycleRepeat() {
    repeat = MusicRepeat.values[(repeat.index + 1) % MusicRepeat.values.length];
    notifyListeners();
  }

  void close() {
    _engine.stop();
    index = null;
    playing = false;
    _queue = null;
    _queueId = 'library';
    notifyListeners();
  }
}
