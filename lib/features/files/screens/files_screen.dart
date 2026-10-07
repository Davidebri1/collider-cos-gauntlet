import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/files/file_blobs.dart';
import '../../../core/audio/music_player.dart';
import '../../../core/files/file_store.dart';
import '../../../core/media/theme_catalog.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/figma/figma_stage.dart';
import '../../music/song_row_parts.dart';
import '../../theme/theme_living_media.dart';
import '../widgets/video_player_view.dart';

/// Map row 7 — Files. v8.4: a straight copy of Vision Pro Spatial UI Kit
/// 71:7502 ("Albums", group 1336 x 835) at its own size, scaled as one unit
/// (FigmaStage). Sidebar 4253 (295 x 740), main panel 3004 (946 x 740) with
/// the 5-column 170 x 217 tile grid, segmented ornament 3231 and window
/// controls 2686 (dot = close). Only the user's real files (FileStore, kept
/// with their contents) and the catalog songs replace the sample albums.
class FilesScreen extends StatefulWidget {
  final VoidCallback onClose;
  /// Rail selection (source filter / 'music' / 'search').
  final String category;

  const FilesScreen({super.key, required this.onClose, this.category = 'all'});

  static const frame = Size(1336.4, 835.2);
  // The group's own width (rail at 0 .. main panel right 1336.4), no margin.
  static const cropWidth = 1336.4;
  static const center = Offset(668.2, 417.6);

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FileStore _store = FileStore.instance;
  String _q = '';
  // Sidebar type filter.
  String _type = 'All';
  // Segmented ornament (Years / Months / Days / All Photos -> time added).
  int _span = 3;
  static const _spans = ['Year', 'Month', 'Today', 'All Files'];

  @override
  void initState() {
    super.initState();
    _store.init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
      if (res == null || res.files.isEmpty) return;
      final note = await _store.addPicked(res.files, 'files');
      if (note != null && mounted) await _alert(note);
    } catch (_) {}
  }

  IconData _icon(String type) => switch (type) {
        'Image' => Icons.image_rounded,
        'Video' => Icons.movie_outlined,
        'Data' => Icons.table_chart_outlined,
        'Writing' => Icons.notes_rounded,
        _ => Icons.description_outlined,
      };

  bool _inSpan(StoredFile f) {
    final now = DateTime.now();
    final t = f.addedAt;
    return switch (_span) {
      0 => t.year == now.year,
      1 => t.year == now.year && t.month == now.month,
      2 => t.year == now.year && t.month == now.month && t.day == now.day,
      _ => true,
    };
  }

  static const _typeLabel = {'All': 'Recently Added', 'Image': 'Images', 'Video': 'Videos', 'Document': 'Documents', 'Writing': 'Text', 'Data': 'Data'};

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_store, ThemeCatalog.instance, MusicPlayer.instance]),
      builder: (context, _) {
        final cat = widget.category;
        final q = _q.toLowerCase();
        final all = _store.files.reversed.toList();
        final files = cat == 'music'
            ? const <StoredFile>[]
            : all
                .where((f) =>
                    (cat == 'all' || cat == 'search' || f.source == cat) &&
                    (_type == 'All' || f.type == _type) &&
                    _inSpan(f) &&
                    (q.isEmpty || f.name.toLowerCase().contains(q)))
                .toList();
        final title = cat == 'music' ? 'Music' : (_typeLabel[_type] ?? _type);
        return FigmaStage(
          frame: FilesScreen.frame,
          cropWidth: FilesScreen.cropWidth,
          center: FilesScreen.center,
          children: [
            // Sidebar 4253_frame at (95.4, 0), 295 x 740.
            Positioned(left: 95.4, top: 0, width: 295, height: 740, child: _sidebar(all)),
            // Main panel 3004_frame at (390.4, 0), 946 x 740.
            Positioned(left: 390.4, top: 0, width: 946, height: 740, child: _main(title, files, cat)),
            // Segmented ornament 3231_frame at (518.8, 721), 394.1 x 60.2.
            Positioned(left: 518.8, top: 721, width: 394.1, height: 60.2, child: _segments()),
            // Window controls 2686_frame at (625.4, 821.2): dot (close) + bar.
            Positioned(
              left: 625.4,
              top: 815,
              width: 181,
              height: 26,
              child: Row(children: [
                Semantics(
                  button: true,
                  label: 'Close',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onClose,
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      child: Container(width: 14, height: 14, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x99FFFFFF))),
                    ),
                  ),
                ),
                const SizedBox(width: 26),
                GestureDetector(
                  onVerticalDragEnd: (d) {
                    if ((d.primaryVelocity ?? 0) > 200) widget.onClose();
                  },
                  child: Container(width: 143, height: 12, decoration: BoxDecoration(color: const Color(0x99FFFFFF), borderRadius: BorderRadius.circular(6))),
                ),
              ]),
            ),
          ],
        );
      },
    );
  }

  Widget _sidebar(List<StoredFile> all) {
    Widget menuRow(String type, IconData icon, double top) {
      final on = _type == type;
      return Positioned(
        left: 13,
        top: 84 + top,
        child: Semantics(
          button: true,
          selected: on,
          label: _typeLabel[type],
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _type = type),
            child: Row(children: [
              Container(
                width: 42.24,
                height: 42.24,
                decoration: on ? const BoxDecoration(shape: BoxShape.circle, color: Color(0x33FFFFFF)) : null,
                child: Icon(icon, size: 21, color: const Color(0xFFDDDBD6)),
              ),
              const SizedBox(width: 11.52),
              FText(_typeLabel[type]!, size: 17.28, weight: FontWeight.w600, color: on ? Colors.white : const Color(0xFFDDDBD6)),
            ]),
          ),
        ),
      );
    }

    Widget section(String type, double top, {bool open = false}) {
      final on = _type == type;
      return Positioned(
        left: 21,
        top: 332 + top,
        width: 273,
        height: 28,
        child: Semantics(
          button: true,
          selected: on,
          label: _typeLabel[type],
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _type = type),
            child: Row(children: [
              FText(_typeLabel[type]!, size: 23.17, weight: FontWeight.w600, color: on ? Colors.white : const Color(0xE6FAF9F5)),
              const Spacer(),
              Icon(open ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded, size: 28, color: const Color(0xE6FAF9F5)),
              const SizedBox(width: 22),
            ]),
          ),
        ),
      );
    }

    // "All Albums" highlight + album rows -> the newest files.
    final recent = all.take(3).toList();
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(52.8), bottomLeft: Radius.circular(52.8)),
        boxShadow: [BoxShadow(color: Color(0x2E000000), offset: Offset(0, 0.85), blurRadius: 20.5)],
      ),
      child: FGlass(
        radius: const BorderRadius.only(topLeft: Radius.circular(52.8), bottomLeft: Radius.circular(52.8)),
        blur: 24.5,
        gradient: const LinearGradient(begin: Alignment(-0.9, -1), end: Alignment(0.9, 1), colors: [Color(0x99393939), Color(0x99616161)]),
        child: Stack(children: [
          const Positioned(left: 25, top: 23, child: FText('Files', size: 29.8, weight: FontWeight.w700, color: Color(0xFFFAF9F5))),
          menuRow('All', Icons.schedule_rounded, 0),
          menuRow('Image', Icons.image_outlined, 57.24),
          menuRow('Video', Icons.movie_outlined, 114.48),
          menuRow('Document', Icons.description_outlined, 171.72),
          section('Writing', 0),
          section('Data', 55),
          Positioned(
            left: 21,
            top: 442,
            width: 273,
            height: 28,
            child: Row(children: const [
              FText('Recent', size: 23.17, weight: FontWeight.w600, color: Color(0xE6FAF9F5)),
              Spacer(),
              Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: Color(0xE6FAF9F5)),
              SizedBox(width: 22),
            ]),
          ),
          if (recent.isNotEmpty)
            Positioned(
              left: 18,
              top: 484,
              width: 255,
              height: 54,
              child: GestureDetector(
                onTap: () => _open(recent.first),
                child: Container(
                  decoration: BoxDecoration(color: const Color(0x4DFFFFFF), borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    SizedBox(width: 47, height: 47, child: Icon(_icon(recent.first.type), size: 26, color: const Color(0xFFDDDBD6))),
                    const SizedBox(width: 1.84),
                    Expanded(child: FText(recent.first.name, size: 16.56, weight: FontWeight.w600, color: const Color(0xFFDDDBD6))),
                    const SizedBox(width: 12),
                  ]),
                ),
              ),
            ),
          for (var k = 1; k < recent.length; k++)
            Positioned(
              left: 29,
              top: 553 + 57.0 * (k - 1),
              width: 240,
              height: 32,
              child: GestureDetector(
                onTap: () => _open(recent[k]),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.035),
                    child: Container(
                      width: 34,
                      height: 32,
                      color: const Color(0x33FFFFFF),
                      child: FileStore.isImage(recent[k].name)
                          ? _Thumb(id: recent[k].id, fallback: _icon(recent[k].type))
                          : Icon(_icon(recent[k].type), size: 18, color: const Color(0xFFDDDBD6)),
                    ),
                  ),
                  const SizedBox(width: 17.48),
                  Expanded(child: FText(recent[k].name, size: 18, weight: FontWeight.w600, color: const Color(0xFFDDDBD6))),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _main(String title, List<StoredFile> files, String cat) {
    final lib = cat == 'music' || (cat == 'all' && _type == 'All') ? MusicPlayer.library : const <MusicTrack>[];
    final p = MusicPlayer.instance;
    final cur = p.current;
    return FGlass(
      radius: const BorderRadius.only(topRight: Radius.circular(52.8), bottomRight: Radius.circular(52.8)),
      blur: 24.5,
      gradient: const LinearGradient(begin: Alignment(-0.9, -1), end: Alignment(0.9, 1), colors: [Color(0x8C262626), Color(0x8C404040)]),
      child: Stack(children: [
        // Title 3120_text at (40, 22), 146 x 34 (search field when searching).
        Positioned(
          left: 40,
          top: 22,
          width: 760,
          height: 34,
          child: cat == 'search'
              ? TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: (v) => setState(() => _q = v.trim()),
                  cursorColor: Colors.white,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
                  decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true, hintText: 'Search', hintStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0x66FFFFFF))),
                )
              : FText(title, size: 28.6, weight: FontWeight.w700, color: const Color(0xFFFAF9F5)),
        ),
        // Adding files is the real storage path (D22/D32); Figma has no add
        // control, so it sits on the title row's end (v8.4 note in D22).
        Positioned(
          left: 862,
          top: 17,
          width: 44,
          height: 44,
          child: Semantics(
            button: true,
            label: 'Add files',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickFile,
              child: Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x4DFFFFFF)),
                child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
              ),
            ),
          ),
        ),
        // Grid 3011/3047/3083: rows at y 75 + 230 i, tiles 170 x 217, 174 apart.
        Positioned(
          left: 40,
          top: 75,
          width: 866,
          bottom: 0,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 13, crossAxisSpacing: 4, childAspectRatio: 170 / 217),
                delegate: SliverChildBuilderDelegate((_, i) => _tile(files[i]), childCount: files.length),
              ),
              if (lib.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.only(top: 13, bottom: 60),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((_, i) {
                      final t = lib[i];
                      final isCur = cur != null && cur.key == t.key && cur.themeId == t.themeId;
                      return LibrarySongRow(
                        art: ThemeImage(t.art, fit: BoxFit.cover),
                        title: t.title,
                        subtitle: t.subtitle,
                        current: isCur,
                        playing: isCur && p.playing,
                        onPlay: t.playable ? () => isCur ? p.toggle() : p.playQueue(lib, i, id: 'library') : null,
                      );
                    }, childCount: lib.length),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _segments() => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(765),
          boxShadow: const [BoxShadow(color: Color(0x2E000000), offset: Offset(0, 1.53), blurRadius: 36.7)],
        ),
        child: FGlass(
          radius: BorderRadius.circular(765),
          blur: 18.4,
          stroke: Colors.white,
          strokeWidth: 1.53,
          gradient: const LinearGradient(
            begin: Alignment(-0.3, -1),
            end: Alignment(0.3, 1),
            colors: [Color(0x80FFFFFF), Color(0x5EEBEBEB), Color(0x36D4D4D4), Color(0x24CACACA), Color(0x1AC4C4C4)],
          ),
          padding: const EdgeInsets.all(12.24 - 1.53),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < _spans.length; i++)
              Semantics(
                button: true,
                selected: _span == i,
                label: _spans[i],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _span = i),
                  child: Container(
                    height: 35.32,
                    padding: const EdgeInsets.symmetric(horizontal: 17.9),
                    alignment: Alignment.center,
                    decoration: _span == i ? BoxDecoration(color: const Color(0x4DFFFFFF), borderRadius: BorderRadius.circular(35.8)) : null,
                    child: FText(_spans[i], size: 17.9, height: 21.5, weight: FontWeight.w600),
                  ),
                ),
              ),
          ]),
        ),
      );

  Widget _tile(StoredFile f) {
    final meta = [FileStore.sizeLabel(f.sizeBytes), FileStore.ago(f.addedAt)].where((s) => s.isNotEmpty).join(' · ');
    return Semantics(
      button: true,
      label: f.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(f),
        onLongPress: () => _confirmRemove(f),
        onSecondaryTap: () => _confirmRemove(f),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.02),
              child: Container(
                width: 152,
                height: 153,
                color: const Color(0x33FFFFFF),
                child: FileStore.isImage(f.name)
                    ? _Thumb(id: f.id, fallback: _icon(f.type))
                    : Icon(_icon(f.type), size: 52, color: const Color(0xCCFFFFFF)),
              ),
            ),
            const SizedBox(height: 3),
            FText(f.name, size: 22, weight: FontWeight.w500),
            FText(meta, size: 16, opacity: 0.6, weight: FontWeight.w500),
          ]),
        ),
      ),
    );
  }

  // Map row 22: problems show in the centred alert (D49).
  Future<void> _alert(String text) =>
      showVAlert(context, icon: Icons.error_outline_rounded, title: text, actions: const [VAlertChoice('OK')]);

  Future<void> _confirmRemove(StoredFile f) async {
    final ok = await showVAlert(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Remove file?',
      message: f.name,
      actions: const [VAlertChoice('Remove', destructive: true), VAlertChoice('Cancel')],
    );
    if (ok == 0) await _store.remove(f.id);
  }

  Future<void> _open(StoredFile f) async {
    final bytes = await _store.bytesOf(f.id);
    if (!mounted) return;
    if (bytes == null) {
      await _alert('${f.name} could not be opened');
      return;
    }
    if (FileStore.isVideo(f.name)) {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Close',
        barrierColor: Colors.black.withValues(alpha: 0.55),
        pageBuilder: (context, _, __) => Material(type: MaterialType.transparency, child: VideoPlayerView(file: f, bytes: bytes)),
      );
      return;
    }
    if (FileStore.isImage(f.name) || FileStore.isText(f.name)) {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close',
        barrierColor: Colors.black54,
        pageBuilder: (context, _, __) => Material(type: MaterialType.transparency, child: _FileViewer(file: f, bytes: bytes)),
      );
      return;
    }
    // Web: PDF in a new tab, anything else downloaded under its own name.
    // iOS / Android: opened in the app the user has for that type.
    final mime = FileStore.mimeFor(f.name);
    final ok = await FileBlobs.openExternal(f.name, bytes, mime, newTab: mime == 'application/pdf');
    if (!ok && mounted) await _alert('${f.name} could not be opened');
  }
}

/// Image tile thumbnail from the stored bytes.
class _Thumb extends StatefulWidget {
  final String id;
  final IconData fallback;
  const _Thumb({required this.id, required this.fallback});

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  static final Map<String, Uint8List> _cache = {};
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _cache[widget.id];
    if (_bytes == null) {
      FileStore.instance.bytesOf(widget.id).then((b) {
        if (b == null || !mounted) return;
        _cache[widget.id] = b;
        setState(() => _bytes = b);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    if (b == null) return Center(child: Icon(widget.fallback, size: 34, color: VColors.textSecondary));
    return Image.memory(b, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 360,
        errorBuilder: (_, __, ___) => Center(child: Icon(widget.fallback, size: 34, color: VColors.textSecondary)));
  }
}

/// In-app viewer for a stored image or text file.
class _FileViewer extends StatelessWidget {
  final StoredFile file;
  final Uint8List bytes;
  const _FileViewer({required this.file, required this.bytes});

  static const int _maxChars = 200000;

  @override
  Widget build(BuildContext context) {
    final close = VCircleButton(icon: Icons.close_rounded, tooltip: 'Close', onTap: () => Navigator.of(context).pop());
    final Widget content;
    if (FileStore.isImage(file.name)) {
      content = InteractiveViewer(
        maxScale: 6,
        child: Center(
          child: Image.memory(bytes, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 40, color: VColors.textTertiary)),
        ),
      );
    } else {
      var text = utf8.decode(bytes, allowMalformed: true);
      final cut = text.length > _maxChars;
      if (cut) text = text.substring(0, _maxChars);
      content = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.xs, VSpace.md, VSpace.md),
        child: SelectableText(
          cut ? '$text\n…' : text,
          style: VType.callout(weight: FontWeight.w400).copyWith(fontFamily: 'monospace', fontSize: 13, height: 1.45),
        ),
      );
    }
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(VSpace.md, 40, VSpace.md, 96),
          child: VWindow(
            title: file.name,
            centerTitle: true,
            maxWidth: VOverlay.toolWidth(context),
            maxHeight: VOverlay.toolMaxHeight(context),
            leading: close,
            child: content,
          ),
        ),
      ),
    );
  }
}
