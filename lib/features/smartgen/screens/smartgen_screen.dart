import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/figma/figma_stage.dart';
import '../../../core/files/file_blobs.dart';
import '../../../core/vision/vision_kit.dart';
import '../kanban_store.dart';

/// REQ-10 Smart Gen (map rows 23-25), v8.4: a straight copy of the Vision
/// Pro UI Kit Keynote window (BLoCtbUcCpX32i0Fh7Y0ld 30:75, frame 1640 x
/// 1060, window 1191 x 642 at 225,158, Menu Tabs 608 x 56 at 516,780) laid
/// out at the frame's own size and scaled as one unit to the device width
/// (crop = the window's own width, 1191).
///
/// Real data replaces Keynote's sample deck (D54): the slide list is the
/// board (one group per column, chevron to fold, the column's cards as its
/// slides), the slide canvas holds the cards. Cards and panel are Nimo
/// Spatial OS 2012:201531's Windows widget cards (300 x 144 units, gap 16,
/// pastel fills sampled from the frame, collapsed = one unit tall). Inline
/// editing is Spatial UI UX 59:170 / 30:2439: the inspector panel (263 x
/// 560, #8D8579, radius 18) beside the card and the Undo / Redo pills.
class SmartGenScreen extends StatefulWidget {
  final VoidCallback onClose;

  const SmartGenScreen({super.key, required this.onClose});

  @override
  State<SmartGenScreen> createState() => _SmartGenScreenState();
}

/// Nimo widget card fills sampled from 2012:201531 (pink, sand, blue, mist,
/// and the weather card's deep blue) with the header mark accent.
const List<Color> kCardFill = [Color(0xFFF8E5E8), Color(0xFFEEE7C9), Color(0xFFE2EBF4), Color(0xFFDDE8ED), Color(0xFF1A4587)];
const List<Color> kCardAccent = [Color(0xFFD9466F), Color(0xFFB8860B), Color(0xFF2F6FE4), Color(0xFF1F8A8A), Color(0xFFF2C94C)];
const List<IconData> kColIcons = [Icons.radio_button_unchecked_rounded, Icons.timelapse_rounded, Icons.check_circle_outline_rounded];
const Color kPanelFill = Color(0xE69DC3DD); // Nimo widgets panel, sampled
const double kCardW = 288; // Nimo 300-unit card fitted 3-across the 929 canvas
const double kUnit = 138; // Nimo 144 grid unit at the same factor
const double kGap = 16;

enum _View { board, column, table }

class _SmartGenScreenState extends State<SmartGenScreen> {
  final KanbanStore _store = KanbanStore.instance;
  _View _view = _View.board;
  int _col = 0;
  String? _sel; // selected card
  String? _editingId; // inline editing (row 25)
  bool _notesFirst = false;
  bool _sidebar = true;
  bool _present = false;
  bool _selectMode = false;
  final Set<String> _multi = {};
  final Set<int> _folded = {};
  int _zoomIx = 0;
  int _notesFocusTick = 0; // inspector "Notes +": focus the note field
  bool _shared = false;
  final FocusNode _keys = FocusNode();
  // The card being edited keeps its text here, so it survives the card
  // moving between columns (inspector) or being rebuilt.
  final TextEditingController _t = TextEditingController();
  final TextEditingController _n = TextEditingController();

  static const List<double> _zooms = [1, 0.75, 0.5];

  @override
  void initState() {
    super.initState();
    _store.init();
  }

  @override
  void dispose() {
    _commitEdit(rebuild: false);
    _keys.dispose();
    _t.dispose();
    _n.dispose();
    super.dispose();
  }

  void _startEdit(KanbanCard c, {bool notes = false}) {
    if (_editingId != null && _editingId != c.id) _commitEdit(rebuild: false);
    if (_editingId != c.id) {
      _t.text = c.title;
      _n.text = c.notes;
    }
    _notesFirst = notes;
    _sel = c.id;
    _editingId = c.id;
  }

  /// Saves the edited card (an empty one is dropped) and leaves editing.
  void _commitEdit({bool rebuild = true}) {
    final c = _store.byId(_editingId);
    _editingId = null;
    if (c != null) _store.edit(c, title: _t.text, notes: _n.text);
    if (rebuild && mounted) setState(() {});
  }

  KanbanCard? get _selected => _store.byId(_sel);

  /// Cards an action applies to: the multi-selection, else the selected card.
  List<KanbanCard> get _targets {
    if (_selectMode && _multi.isNotEmpty) return _multi.map(_store.byId).whereType<KanbanCard>().toList();
    final s = _selected;
    return s == null ? const [] : [s];
  }

  List<KanbanCard> get _visibleCards => _view == _View.column
      ? _store.inColumn(_col)
      : [for (var i = 0; i < KanbanStore.columns.length; i++) ..._store.inColumn(i)];

  void _newCard({int? column}) {
    if (_editingId != null) _commitEdit(rebuild: false);
    final c = _store.add(column ?? (_view == _View.column ? _col : 0));
    setState(() {
      _startEdit(c);
      _present = false;
      _selectMode = false;
    });
  }

  void _tapCard(KanbanCard c) {
    setState(() {
      if (_selectMode) {
        _multi.contains(c.id) ? _multi.remove(c.id) : _multi.add(c.id);
        return;
      }
      _startEdit(c);
    });
  }

  void _endEdit() {
    if (_editingId == null && _sel == null) return;
    _commitEdit(rebuild: false);
    setState(() => _sel = null);
  }

  Future<void> _pickCover() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final bytes = r?.files.firstOrNull?.bytes;
    if (bytes == null || !mounted) return;
    var c = _selected;
    if (c == null) {
      c = _store.add(_view == _View.column ? _col : 0);
      setState(() => _startEdit(c!));
    }
    await _store.setImage(c, bytes);
  }

  Future<void> _share() async {
    await Clipboard.setData(ClipboardData(text: _store.toMarkdown()));
    if (!mounted) return;
    setState(() => _shared = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _shared = false);
    });
  }

  Future<void> _progress() async {
    final n = [for (var i = 0; i < 3; i++) _store.count(i)];
    final total = n.fold<int>(0, (a, b) => a + b);
    await showVAlert(
      context,
      icon: Icons.pie_chart_outline_rounded,
      title: total == 0 ? 'No cards yet' : '${(n[2] * 100 / total).round()}% done',
      message: 'To Do ${n[0]} · Doing ${n[1]} · Done ${n[2]}',
      actions: const [VAlertChoice('OK')],
    );
  }

  Future<void> _confirmDelete(List<KanbanCard> cards) async {
    if (cards.isEmpty) return;
    final i = await showVAlert(
      context,
      icon: Icons.delete_outline_rounded,
      title: cards.length == 1 ? 'Delete card?' : 'Delete ${cards.length} cards?',
      message: cards.length == 1 && cards.first.title.isNotEmpty ? cards.first.title : null,
      actions: const [VAlertChoice('Delete', destructive: true), VAlertChoice('Cancel')],
    );
    if (i != 0) return;
    if (cards.any((c) => c.id == _editingId)) _editingId = null;
    for (final c in cards) {
      await _store.remove(c);
    }
    if (!mounted) return;
    setState(() {
      _multi.clear();
      _editingId = null;
      _sel = null;
    });
  }

  /// Glass menu anchored under [key]'s button.
  Future<void> _menu(GlobalKey key, List<GlassMenuRow> Function(NavigatorState nav) rows) async {
    final b = key.currentContext?.findRenderObject() as RenderBox?;
    if (b == null) return;
    final anchor = b.localToGlobal(Offset.zero) & b.size;
    final screen = MediaQuery.sizeOf(context);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      transitionBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      pageBuilder: (ctx, _, __) {
        final w = 240 * GlassMenu.scaleFor(ctx);
        final left = (anchor.center.dx - w / 2).clamp(8.0, screen.width - w - 8);
        return Stack(children: [
          Positioned.fill(child: GestureDetector(onTap: () => Navigator.of(ctx).pop())),
          Positioned(
            left: left,
            top: anchor.bottom + 6,
            child: Material(type: MaterialType.transparency, child: GlassMenu(rows: rows(Navigator.of(ctx)))),
          ),
        ]);
      },
    );
  }

  final GlobalKey _titleKey = GlobalKey();
  final GlobalKey _moreKey = GlobalKey();

  void _titleMenu() => _menu(_titleKey, (nav) => [
        GlassMenuRow(icon: Icons.view_week_outlined, label: 'Board', on: _view == _View.board, onTap: () {
          nav.pop();
          setState(() => _view = _View.board);
        }),
        for (var i = 0; i < 3; i++)
          GlassMenuRow(icon: kColIcons[i], label: KanbanStore.columns[i], on: _view == _View.column && _col == i, onTap: () {
            nav.pop();
            setState(() {
              _view = _View.column;
              _col = i;
            });
          }),
        GlassMenuRow(icon: Icons.table_rows_outlined, label: 'Table', on: _view == _View.table, onTap: () {
          nav.pop();
          setState(() => _view = _View.table);
        }),
      ]);

  void _moreMenu() {
    final t = _targets;
    _menu(_moreKey, (nav) {
      void run(Future<void> Function() f) {
        nav.pop();
        f();
      }

      if (t.isEmpty) {
        final anyOpen = _store.all.any((c) => !c.collapsed);
        return [
          GlassMenuRow(icon: Icons.add_rounded, label: 'New card', toggle: false, onTap: () => run(() async => _newCard())),
          GlassMenuRow(icon: anyOpen ? Icons.unfold_less_rounded : Icons.unfold_more_rounded, label: anyOpen ? 'Collapse all' : 'Expand all', toggle: false,
              onTap: () => run(() => _store.setCollapsed(_store.all, anyOpen))),
          GlassMenuRow(icon: Icons.ios_share_rounded, label: 'Copy board', toggle: false, onTap: () => run(_share)),
        ];
      }
      return [
        if (t.length == 1) GlassMenuRow(icon: Icons.copy_rounded, label: 'Duplicate', toggle: false, onTap: () => run(() async {
              final d = await _store.duplicate(t.first);
              if (mounted) setState(() => _sel = d.id);
            })),
        for (var i = 0; i < 3; i++)
          if (t.any((c) => c.column != i))
            GlassMenuRow(icon: kColIcons[i], label: 'Move to ${KanbanStore.columns[i]}', toggle: false, onTap: () => run(() async {
                  for (final c in t) {
                    await _store.move(c, i);
                  }
                })),
        GlassMenuRow(icon: Icons.delete_outline_rounded, label: 'Delete', toggle: false, onTap: () => run(() => _confirmDelete(t))),
      ];
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      if (_present) {
        setState(() => _present = false);
      } else if (_editingId != null || _sel != null) {
        _endEdit();
      } else {
        widget.onClose();
      }
      return KeyEventResult.handled;
    }
    if (_present && (e.logicalKey == LogicalKeyboardKey.arrowRight || e.logicalKey == LogicalKeyboardKey.arrowLeft)) {
      _step(e.logicalKey == LogicalKeyboardKey.arrowRight ? 1 : -1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _step(int d) {
    final l = _visibleCards;
    if (l.isEmpty) return;
    final i = l.indexWhere((c) => c.id == _sel);
    setState(() => _sel = l[((i < 0 ? 0 : i + d) % l.length + l.length) % l.length].id);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _keys,
      autofocus: true,
      onKeyEvent: _onKey,
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final editing = _store.byId(_editingId);
          return FigmaStage(
            frame: const Size(1640, 1060),
            cropWidth: 1191,
            center: const Offset(820.5, 497),
            children: [
              Positioned(left: 225, top: 158, width: 1191, height: 642, child: _window(editing)),
              Positioned(left: 516, top: 780, width: 608, height: 56, child: TextFieldTapRegion(child: _ornament())),
              // Row 25 30:2608: Undo / Redo pills while a card is being edited.
              if (editing != null)
                Positioned(
                  left: 225 + 595.5 - 78,
                  top: 158 + 557,
                  child: TextFieldTapRegion(child: Opacity(
                    opacity: 0.7,
                    child: Row(children: [
                      _pill('Undo', _store.canUndo ? _store.undo : null),
                      const SizedBox(width: 16),
                      _pill('Redo', _store.canRedo ? _store.redo : null),
                    ]),
                  )),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _pill(String label, VoidCallback? onTap) => VPress(
        onTap: onTap,
        tooltip: label,
        child: Container(
          width: 70,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE5E5E5))),
          child: FText(label, size: 16, weight: FontWeight.w500, color: const Color(0xFF232323), opacity: onTap == null ? 0.4 : 1),
        ),
      );

  // ---------------------------------------------------------------- window

  Widget _window(KanbanCard? editing) {
    final s = FigmaScale.of(context);
    final canvasLeft = _sidebar ? 234.0 : 24.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), offset: Offset(0, 17.5), blurRadius: 11)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: (35.8 * s).clamp(0, 40), sigmaY: (35.8 * s).clamp(0, 40)),
          child: Stack(children: [
            const Positioned.fill(child: ColoredBox(color: Color(0x1AFFFFFF))),
            const Positioned.fill(child: _Specular(radius: 32)),
            if (_sidebar) Positioned(left: 0, top: 0, width: 206, height: 642, child: _sidebarView()),
            // Canvas (30:1733, 929 x 526 at 234,84, radius 14).
            AnimatedPositioned(
              duration: VMotion.fast,
              left: canvasLeft,
              top: 84,
              width: 1163 - canvasLeft,
              height: 526,
              child: _canvas(),
            ),
            // Toolbar (30:1759 / 30:1740 / 30:1742 / 30:1747 / 30:1748).
            Positioned(left: 230, top: 24, child: Row(children: [
              _circle(Icons.chevron_left_rounded, 'Close', widget.onClose),
              const SizedBox(width: 16),
              _circle(Icons.view_sidebar_outlined, _sidebar ? 'Hide board list' : 'Show board list', () => setState(() => _sidebar = !_sidebar), on: _sidebar),
            ])),
            Positioned(
              left: 338,
              top: 29,
              child: VPress(
                key: _titleKey,
                onTap: _titleMenu,
                tooltip: 'View',
                child: Row(children: [
                  FText(_title, size: 17, weight: FontWeight.w700, letterSpacing: -0.442),
                  const SizedBox(width: 10),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: Color(0x1AFFFFFF), shape: BoxShape.circle),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.white),
                  ),
                ]),
              ),
            ),
            Positioned(left: 655, top: 24, child: Row(children: [
              _circle(_present ? Icons.stop_rounded : Icons.play_arrow_rounded, _present ? 'Stop' : 'Present', () {
                setState(() {
                  _present = !_present;
                  if (_editingId != null) _commitEdit(rebuild: false);
                  if (_present && _sel == null && _visibleCards.isNotEmpty) _sel = _visibleCards.first.id;
                });
              }, on: _present),
              const SizedBox(width: 16),
              _circle(Icons.panorama_wide_angle_outlined, 'Board', () => setState(() => _view = _view == _View.board ? _View.column : _View.board), on: _view == _View.board),
            ])),
            Positioned(right: 24, top: 24, child: TextFieldTapRegion(child: Row(children: [
              _circle(Icons.how_to_reg_outlined, 'Mark done', _targets.isEmpty ? null : () async {
                for (final c in _targets) {
                  await _store.move(c, 2);
                }
              }),
              const SizedBox(width: 16),
              _circle(_shared ? Icons.check_rounded : Icons.ios_share_rounded, 'Copy board', _share),
              const SizedBox(width: 16),
              _circle(Icons.brush_outlined, 'Colour', _targets.isEmpty ? null : () async {
                for (final c in _targets) {
                  await _store.recolor(c, c.color + 1);
                }
              }),
              const SizedBox(width: 16),
              KeyedSubtree(key: _moreKey, child: _circle(Icons.more_horiz_rounded, 'More', _moreMenu)),
              const SizedBox(width: 16),
              _circle(Icons.sticky_note_2_outlined, 'Notes', _selected == null ? null : () => setState(() => _startEdit(_selected!, notes: true))),
            ]))),
            // Row 25 inspector beside the card being edited.
            if (editing != null && !_present) Positioned(left: 887, top: 61, width: 263, height: 560, child: TextFieldTapRegion(child: _inspector(editing))),
          ]),
        ),
      ),
    );
  }

  String get _title => switch (_view) {
        _View.board => 'Smart Gen',
        _View.column => KanbanStore.columns[_col],
        _View.table => 'All cards',
      };

  /// 36 px toolbar circle: white 10 %, inset specular, 14 px symbol.
  Widget _circle(IconData icon, String tip, VoidCallback? onTap, {bool on = false}) => VPress(
        onTap: onTap,
        tooltip: tip,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: on ? const Color(0x33FFFFFF) : const Color(0x1AFFFFFF), shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: Colors.white),
          ),
        ),
      );

  // --------------------------------------------------------------- sidebar

  Widget _sidebarView() {
    final items = <Widget>[];
    var n = 0;
    for (var i = 0; i < 3; i++) {
      n++;
      final folded = _folded.contains(i);
      final cards = _store.inColumn(i);
      final selHeader = _sel == null && (_view == _View.column ? _col == i : false);
      items.add(DragTarget<KanbanCard>(
        onWillAcceptWithDetails: (d) => d.data.column != i,
        onAcceptWithDetails: (d) => _store.move(d.data, i),
        builder: (context, cand, _) => SizedBox(
          height: 81,
          child: Stack(clipBehavior: Clip.none, children: [
            if (selHeader || cand.isNotEmpty)
              Positioned(left: 10, top: -6, width: 182, height: 93, child: Container(decoration: BoxDecoration(color: Color(cand.isNotEmpty ? 0x40FFFFFF : 0x26FFFFFF), borderRadius: BorderRadius.circular(13)))),
            Positioned(
              left: 12,
              top: 25,
              child: VPress(
                onTap: () => setState(() => folded ? _folded.remove(i) : _folded.add(i)),
                tooltip: folded ? 'Expand' : 'Collapse',
                child: SizedBox(width: 28, height: 28, child: Icon(folded ? Icons.chevron_right_rounded : Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white)),
              ),
            ),
            Positioned(left: 28, top: 67, child: FText('$n', size: 12)),
            Positioned(
              left: 42,
              top: 0,
              width: 144,
              height: 81,
              child: VPress(
                onTap: () => setState(() {
                  _view = _View.column;
                  _col = i;
                  _sel = null;
                  if (_editingId != null) _commitEdit(rebuild: false);
                }),
                tooltip: KanbanStore.columns[i],
                child: _columnThumb(i, cards),
              ),
            ),
          ]),
        ),
      ));
      items.add(const SizedBox(height: 24));
      if (folded) continue;
      for (final c in cards) {
        n++;
        final sel = c.id == _sel || _multi.contains(c.id);
        items.add(SizedBox(
          height: 72,
          child: Stack(clipBehavior: Clip.none, children: [
            if (sel) Positioned(left: 10, top: -6, width: 182, height: 84, child: Container(decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(13)))),
            Positioned(left: 43, top: 58, child: FText('$n', size: 12)),
            Positioned(
              left: 58,
              top: 0,
              width: 128,
              height: 72,
              child: VPress(
                onTap: () {
                  if (_view == _View.column && _col != c.column) _col = c.column;
                  _tapCard(c);
                },
                tooltip: c.title.isEmpty ? 'Card' : c.title,
                child: _cardThumb(c),
              ),
            ),
          ]),
        ));
        items.add(const SizedBox(height: 24));
      }
    }
    return Stack(children: [
      // 30:1732: black 30 %.
      const Positioned.fill(child: ColoredBox(color: Color(0x4D000000))),
      Positioned.fill(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 24, bottom: 90),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
          ),
        ),
      ),
      // 30:1784 bottom blur strip and 30:1780 plus.rectangle (new card).
      Positioned(
        left: 0,
        top: 564,
        width: 206,
        height: 78,
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 4 * FigmaScale.of(context), sigmaY: 4 * FigmaScale.of(context)),
            child: const ColoredBox(color: Color(0x03FFFFFF)),
          ),
        ),
      ),
      Positioned(
        left: 24,
        top: 582,
        child: VPress(
          onTap: () => _newCard(),
          tooltip: 'New card',
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
            child: const Icon(Icons.add_box_outlined, size: 17, color: Colors.white),
          ),
        ),
      ),
    ]);
  }

  /// Group slide (144 x 81): the column as a mini Nimo panel.
  Widget _columnThumb(int i, List<KanbanCard> cards) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: kPanelFill,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: FText(KanbanStore.columns[i], size: 13, weight: FontWeight.w700, color: const Color(0xFF1C1C1E))),
              FText('${cards.length}', size: 12, weight: FontWeight.w600, color: const Color(0xFF3C3C43)),
            ]),
            const SizedBox(height: 6),
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var k = 0; k < 3; k++) ...[
                  if (k > 0) const SizedBox(width: 5),
                  Expanded(
                    child: k < cards.length
                        ? Container(decoration: BoxDecoration(color: kCardFill[cards[k].color % kCardFill.length], borderRadius: BorderRadius.circular(4)))
                        : Container(decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(4))),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      );

  /// Slide (128 x 72): the card in miniature.
  Widget _cardThumb(KanbanCard c) {
    final fill = kCardFill[c.color % kCardFill.length];
    final ink = c.color % kCardFill.length == 4 ? Colors.white : const Color(0xFF1C1C1E);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: fill,
        child: Stack(fit: StackFit.expand, children: [
          if (c.image.isNotEmpty) Opacity(opacity: 0.85, child: _BlobImage(id: c.image)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
            child: FText(c.title.isEmpty ? 'New card' : c.title, size: 11, weight: FontWeight.w600, color: c.image.isNotEmpty ? Colors.white : ink, maxLines: 3),
          ),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------- canvas

  Widget _canvas() {
    final z = _zooms[_zoomIx];
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: kPanelFill,
        child: !_store.loaded
            ? const SizedBox.shrink()
            : LayoutBuilder(builder: (context, box) {
                if (_present) return _presentView(box.biggest);
                final w = box.maxWidth / z;
                Widget content = switch (_view) {
                  _View.board => _boardView(w),
                  _View.column => _columnView(w),
                  _View.table => _tableView(w),
                };
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _endEdit,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      child: Transform.scale(
                        scale: z,
                        alignment: Alignment.topLeft,
                        child: SizedBox(width: w, child: content),
                      ),
                    ),
                  ),
                );
              }),
      ),
    );
  }

  Widget _boardView(double w) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: kGap),
            SizedBox(
              width: kCardW,
              child: DragTarget<KanbanCard>(
                onWillAcceptWithDetails: (d) => d.data.column != i,
                onAcceptWithDetails: (d) => _store.move(d.data, i),
                builder: (context, cand, _) => Container(
                  decoration: BoxDecoration(color: cand.isNotEmpty ? const Color(0x33FFFFFF) : null, borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _colHeader(i),
                    for (final c in _store.inColumn(i)) ...[_card(c), const SizedBox(height: kGap)],
                    if (_store.count(i) == 0) _AddTile(onTap: () => _newCard(column: i)),
                  ]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Nimo panel heading ("Widgets   +"): column name, count, add.
  Widget _colHeader(int i) => SizedBox(
        height: 34,
        child: Row(children: [
          const SizedBox(width: 2),
          FText(KanbanStore.columns[i], size: 14, weight: FontWeight.w600, color: const Color(0xFF1C1C1E)),
          const SizedBox(width: 6),
          FText('${_store.count(i)}', size: 13, color: const Color(0xFF3C3C43)),
          const Spacer(),
          VPress(
            onTap: () => _newCard(column: i),
            tooltip: 'New card',
            child: const SizedBox(width: 28, height: 28, child: Icon(Icons.add_rounded, size: 18, color: Color(0xFF3C3C43))),
          ),
        ]),
      );

  Widget _columnView(double w) {
    final cards = _store.inColumn(_col);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _colHeader(_col),
        Wrap(spacing: kGap, runSpacing: kGap, children: [
          for (final c in cards) SizedBox(width: kCardW, child: _card(c)),
          if (cards.isEmpty) SizedBox(width: kCardW, child: _AddTile(onTap: () => _newCard(column: _col))),
        ]),
      ]),
    );
  }

  Widget _tableView(double w) {
    final rows = [for (var i = 0; i < 3; i++) ..._store.inColumn(i)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (rows.isEmpty) _AddTile(onTap: () => _newCard()),
        for (final c in rows)
          VPress(
            onTap: () => _tapCard(c),
            tooltip: c.title,
            child: Container(
              height: 44,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: kCardFill[c.color % kCardFill.length],
                borderRadius: BorderRadius.circular(8),
                border: c.id == _sel ? Border.all(color: Colors.white, width: 2) : null,
              ),
              child: Row(children: [
                Icon(kColIcons[c.column], size: 16, color: kCardAccent[c.color % kCardAccent.length]),
                const SizedBox(width: 10),
                Expanded(child: FText(c.title.isEmpty ? 'New card' : c.title, size: 14, weight: FontWeight.w600, color: _ink(c))),
                FText(KanbanStore.columns[c.column], size: 12, color: _ink2(c)),
                const SizedBox(width: 16),
                SizedBox(width: 40, child: FText(_age(c), size: 12, color: _ink2(c), align: TextAlign.right)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _presentView(Size size) {
    final l = _visibleCards;
    final c = _store.byId(_sel) ?? (l.isEmpty ? null : l.first);
    if (c == null) return Center(child: FText('No cards to present', size: 17, color: const Color(0xFF1C1C1E)));
    return Stack(children: [
      Center(
        child: SizedBox(
          width: kCardW,
          child: Transform.scale(scale: 1.6, child: _card(c, interactive: false)),
        ),
      ),
      Positioned(left: 16, top: 0, bottom: 0, child: Center(child: _circleDark(Icons.chevron_left_rounded, 'Previous', () => _step(-1)))),
      Positioned(right: 16, top: 0, bottom: 0, child: Center(child: _circleDark(Icons.chevron_right_rounded, 'Next', () => _step(1)))),
    ]);
  }

  Widget _circleDark(IconData icon, String tip, VoidCallback onTap) => VPress(
        onTap: onTap,
        tooltip: tip,
        child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0x33000000), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 24)),
      );

  Color _ink(KanbanCard c) => c.color % kCardFill.length == 4 ? Colors.white : const Color(0xFF1C1C1E);
  Color _ink2(KanbanCard c) => c.color % kCardFill.length == 4 ? const Color(0xCCFFFFFF) : const Color(0xFF5B5B60);

  String _age(KanbanCard c) {
    final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(c.updatedMs));
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Widget _card(KanbanCard c, {bool interactive = true}) {
    final editing = interactive && _editingId == c.id;
    final view = _NimoCard(
      key: ValueKey('card-${c.id}'),
      card: c,
      fill: kCardFill[c.color % kCardFill.length],
      accent: kCardAccent[c.color % kCardAccent.length],
      ink: _ink(c),
      ink2: _ink2(c),
      age: _age(c),
      selected: interactive && (c.id == _sel || _multi.contains(c.id)),
      title: editing ? _t : null,
      notes: editing ? _n : null,
      notesFirst: _notesFirst,
      notesTick: _notesFocusTick,
      onFocused: () => _notesFirst = false,
      onTap: interactive ? () => _tapCard(c) : null,
      onFocusLost: () {
        if (mounted && _editingId == c.id) _commitEdit();
      },
      onMove: interactive ? (d) => _store.move(c, (c.column + d).clamp(0, 2)) : null,
    );
    if (!interactive || editing) return view;
    return LayoutBuilder(
      builder: (context, box) => LongPressDraggable<KanbanCard>(
        data: c,
        feedback: Material(
          type: MaterialType.transparency,
          child: FigmaScale(
            scale: FigmaScale.of(context),
            child: Transform.scale(
              scale: FigmaScale.of(context),
              alignment: Alignment.topLeft,
              child: SizedBox(width: kCardW, child: Opacity(opacity: 0.92, child: view)),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: view),
        child: view,
      ),
    );
  }

  // ------------------------------------------------------------- inspector

  /// Spatial UI UX 30:2439 inspector (263 x 560, #8D8579, white 10 % border,
  /// radius 18; sections at x 18): Column (Position), Layer (front / back /
  /// delete), Colour (Add Images), Notes + (Effects), Card size (Layer /
  /// Transparency).
  Widget _inspector(KanbanCard c) {
    const ink = Color(0xFF232323);
    Widget seg(List<(IconData, String, bool, VoidCallback)> cells, {double h = 34}) => Container(
          height: h,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(5.66), border: Border.all(color: const Color(0xFFE4E7EC))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5.66),
            child: Row(children: [
              for (var k = 0; k < cells.length; k++) ...[
                if (k > 0) Container(width: 1, color: const Color(0xFFE4E7EC)),
                Expanded(
                  child: VPress(
                    onTap: cells[k].$4,
                    tooltip: cells[k].$2,
                    child: Container(
                      color: cells[k].$3 ? Colors.white : const Color(0xCCFFFFFF),
                      alignment: Alignment.center,
                      child: Icon(cells[k].$1, size: 17, color: cells[k].$3 ? kCardAccent[2] : const Color(0xFF344054)),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        );
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF8D8579), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x1AFFFFFF))),
      padding: const EdgeInsets.fromLTRB(18, 40, 17, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FText('Column', size: 16, weight: FontWeight.w700),
        const SizedBox(height: 16),
        SizedBox(
          width: 228,
          child: seg([
            for (var i = 0; i < 3; i++) (kColIcons[i], 'Move to ${KanbanStore.columns[i]}', c.column == i, () => _store.move(c, i)),
          ]),
        ),
        const SizedBox(height: 36),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FText('Layer', size: 16, weight: FontWeight.w700),
            const SizedBox(height: 15),
            SizedBox(
              width: 118,
              height: 40,
              child: seg([
                (Icons.flip_to_front_rounded, 'Bring to front', false, () => _store.toFront(c)),
                (Icons.flip_to_back_rounded, 'Send to back', false, () => _store.toBack(c)),
              ], h: 40),
            ),
          ]),
          const Spacer(),
          VPress(
            onTap: () => _confirmDelete([c]),
            tooltip: 'Delete',
            child: Container(
              width: 46,
              height: 40,
              decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE4E7EC))),
              child: const Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFF344054)),
            ),
          ),
        ]),
        const SizedBox(height: 30),
        FText('Colour', size: 14, weight: FontWeight.w700),
        const SizedBox(height: 15),
        SizedBox(
          width: 228,
          height: 37,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (var k = 0; k < kCardFill.length; k++)
              VPress(
                onTap: () => _store.recolor(c, k),
                tooltip: 'Colour ${k + 1}',
                child: Container(
                  width: 37,
                  height: 37,
                  decoration: BoxDecoration(
                    color: kCardFill[k],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.color % kCardFill.length == k ? Colors.white : const Color(0xFFE5E5E5), width: c.color % kCardFill.length == k ? 3 : 1),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 22),
        VPress(
          onTap: () => setState(() => _notesFocusTick++),
          tooltip: 'Edit notes',
          child: Container(
            width: 228,
            height: 38,
            padding: const EdgeInsets.only(left: 15, right: 9),
            decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Expanded(child: FText(c.notes.isEmpty ? 'Notes' : 'Notes · ${c.notes.split(RegExp(r'\s+')).length} words', size: 16, color: ink)),
              const Icon(Icons.add_rounded, size: 16, color: ink),
            ]),
          ),
        ),
        const SizedBox(height: 25),
        Container(
          width: 228,
          height: 81,
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 0),
          decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FText('Card', size: 14, color: ink),
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.crop_square_rounded, size: 14, color: ink),
              const SizedBox(width: 9),
              FText('Size', size: 12, color: ink),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 12, color: ink),
              const SizedBox(width: 12),
              Expanded(child: FText(c.collapsed ? 'Collapsed' : 'Full', size: 12, color: ink)),
              VPress(
                onTap: () => _store.setCollapsed([c], !c.collapsed),
                tooltip: c.collapsed ? 'Show full card' : 'Collapse card',
                child: Icon(c.collapsed ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16, color: ink),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  // -------------------------------------------------------------- ornament

  /// Menu Tabs 30:132: 608 x 56, white 10 % + blur 50, radius 100, pl 8
  /// pr 16 py 8, nine equal tabs and two 36 px separators.
  Widget _ornament() {
    final s = FigmaScale.of(context);
    final anyOpen = _store.all.any((c) => !c.collapsed);
    Widget tab(Widget child, String tip, VoidCallback? onTap, {bool on = false}) => Expanded(
          child: VPress(
            onTap: onTap,
            tooltip: tip,
            child: Container(
              height: 40,
              decoration: BoxDecoration(color: on ? const Color(0x26FFFFFF) : Colors.transparent, borderRadius: BorderRadius.circular(100)),
              alignment: Alignment.center,
              child: Opacity(opacity: onTap == null ? 0.4 : 1, child: child),
            ),
          ),
        );
    Icon ic(IconData d) => Icon(d, size: 19, color: Colors.white);
    Widget sep() => Container(width: 1, height: 36, color: const Color(0x4DFFFFFF));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), offset: Offset(0, 8), blurRadius: 6)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: (25 * s).clamp(0, 40), sigmaY: (25 * s).clamp(0, 40)),
          child: Container(
            color: const Color(0x1AFFFFFF),
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Row(children: [
              tab(ic(Icons.undo_rounded), 'Undo', _store.canUndo ? _store.undo : null),
              tab(ic(Icons.redo_rounded), 'Redo', _store.canRedo ? _store.redo : null),
              tab(FText('${(_zooms[_zoomIx] * 100).round()}%', size: 15, weight: FontWeight.w500, letterSpacing: -0.24), 'Zoom',
                  () => setState(() => _zoomIx = (_zoomIx + 1) % _zooms.length)),
              sep(),
              tab(ic(Icons.table_chart_outlined), 'Table', () => setState(() => _view = _view == _View.table ? _View.board : _View.table), on: _view == _View.table),
              tab(ic(Icons.pie_chart_outline_rounded), 'Progress', _progress),
              tab(ic(Icons.text_fields_rounded), 'New card', () => _newCard()),
              tab(ic(anyOpen ? Icons.unfold_less_rounded : Icons.unfold_more_rounded), anyOpen ? 'Collapse all' : 'Expand all',
                  _store.all.isEmpty ? null : () => _store.setCollapsed(_store.all, anyOpen)),
              tab(ic(Icons.add_photo_alternate_outlined), 'Cover photo', _pickCover),
              sep(),
              tab(ic(Icons.highlight_alt_rounded), _selectMode ? 'Done selecting' : 'Select', () => setState(() {
                    _selectMode = !_selectMode;
                    _multi.clear();
                    if (_editingId != null) _commitEdit(rebuild: false);
                  }), on: _selectMode),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Inset specular edge (inset -0.73 0.73 0.73 white 35 %).
class _Specular extends StatelessWidget {
  final double radius;
  const _Specular({required this.radius});
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: const Border(top: BorderSide(color: Color(0x59FFFFFF), width: 0.73), right: BorderSide(color: Color(0x59FFFFFF), width: 0.73)),
          ),
        ),
      );
}

/// A cover photo stored in FileBlobs.
class _BlobImage extends StatefulWidget {
  final String id;
  const _BlobImage({required this.id});
  static final Map<String, Uint8List> _cache = {};
  @override
  State<_BlobImage> createState() => _BlobImageState();
}

class _BlobImageState extends State<_BlobImage> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _BlobImage old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _load();
  }

  Future<void> _load() async {
    if (_BlobImage._cache.containsKey(widget.id)) return;
    final b = await FileBlobs.get(widget.id);
    if (b != null && mounted) setState(() => _BlobImage._cache[widget.id] = b);
  }

  @override
  Widget build(BuildContext context) {
    final b = _BlobImage._cache[widget.id];
    if (b == null) return const SizedBox.shrink();
    return Image.memory(b, fit: BoxFit.cover, gaplessPlayback: true);
  }
}

/// The empty column's one affordance: a dashed add tile (one Nimo unit).
class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return VPress(
      onTap: onTap,
      tooltip: 'New card',
      child: CustomPaint(
        painter: _DashedRRect(),
        child: const SizedBox(height: kUnit, child: Center(child: Icon(Icons.add_rounded, size: 28, color: Color(0xFF3C3C43)))),
      ),
    );
  }
}

class _DashedRRect extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x803C3C43)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, (d + 5).clamp(0, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A Nimo widget card (2012:201531): radius 8, padding 12; header = source
/// mark 16 + "Column · age" 12; bold 16 title; full cards add the cover
/// photo, the note and the reaction row (here ‹ › = move to the previous /
/// next column). Collapsed = one grid unit tall, title only. Title and note
/// edit in place (row 25) with the screen's controllers.
class _NimoCard extends StatefulWidget {
  final KanbanCard card;
  final Color fill, accent, ink, ink2;
  final String age;
  final bool selected, notesFirst;
  final int notesTick;
  final TextEditingController? title, notes; // non-null while editing
  final VoidCallback onFocused;
  final VoidCallback? onTap;
  final VoidCallback onFocusLost;
  final ValueChanged<int>? onMove;

  const _NimoCard({
    super.key,
    required this.card,
    required this.fill,
    required this.accent,
    required this.ink,
    required this.ink2,
    required this.age,
    required this.selected,
    required this.title,
    required this.notes,
    required this.notesFirst,
    required this.notesTick,
    required this.onFocused,
    required this.onTap,
    required this.onFocusLost,
    required this.onMove,
  });

  bool get editing => title != null;

  @override
  State<_NimoCard> createState() => _NimoCardState();
}

class _NimoCardState extends State<_NimoCard> {
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_focusChanged);
    _notesFocus.addListener(_focusChanged);
    if (widget.editing) _focusSoon(widget.notesFirst);
  }

  @override
  void didUpdateWidget(covariant _NimoCard old) {
    super.didUpdateWidget(old);
    if (widget.editing && !old.editing) _focusSoon(widget.notesFirst);
    if (widget.editing && widget.notesTick != old.notesTick) _focusSoon(true);
  }

  void _focusSoon(bool notes) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.editing) return;
        (notes ? _notesFocus : _titleFocus).requestFocus();
        widget.onFocused();
      });

  // Editing ends when focus leaves both fields (taps on the inspector, the
  // pills, the toolbar and the ornament keep it: TextFieldTapRegion).
  void _focusChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.editing) return;
      if (!_titleFocus.hasFocus && !_notesFocus.hasFocus) widget.onFocusLost();
    });
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  TextStyle get _titleStyle => FTextStyle.of(size: 16, weight: FontWeight.w600, color: widget.ink, height: 21);
  TextStyle get _noteStyle => FTextStyle.of(size: 13, weight: FontWeight.w400, color: widget.ink2, height: 18);

  Widget _field(TextEditingController c, FocusNode f, TextStyle style, {int? maxLines, TextInputAction action = TextInputAction.next, VoidCallback? onDone, String hint = ''}) =>
      TextField(
        controller: c,
        focusNode: f,
        style: style,
        maxLines: maxLines,
        minLines: 1,
        cursorColor: widget.accent,
        textInputAction: action,
        onSubmitted: (_) => onDone?.call(),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: hint,
          hintStyle: style.copyWith(color: style.color?.withValues(alpha: 0.45)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    final full = !c.collapsed || widget.editing;
    final body = <Widget>[
      SizedBox(
        height: 24,
        child: Row(children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: widget.accent, borderRadius: BorderRadius.circular(4)),
            child: Icon(kColIcons[c.column], size: 11, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(child: FText('${KanbanStore.columns[c.column]} · ${widget.age}', size: 12, color: widget.ink2)),
        ]),
      ),
      const SizedBox(height: 8),
      if (widget.editing) ...[
        _field(widget.title!, _titleFocus, _titleStyle, maxLines: 3, hint: 'Title', onDone: () => _notesFocus.requestFocus()),
        const SizedBox(height: 6),
        _field(widget.notes!, _notesFocus, _noteStyle, maxLines: 8, hint: 'Notes', action: TextInputAction.done, onDone: () => FocusScope.of(context).unfocus()),
      ] else ...[
        Text(c.title.isEmpty ? 'New card' : c.title, maxLines: full ? 4 : 3, overflow: TextOverflow.ellipsis, style: _titleStyle),
        if (full && c.notes.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(c.notes, maxLines: 6, overflow: TextOverflow.ellipsis, style: _noteStyle),
        ],
      ],
    ];
    final card = Container(
      constraints: BoxConstraints(minHeight: kUnit, maxHeight: full ? double.infinity : kUnit),
      decoration: BoxDecoration(
        color: widget.fill,
        borderRadius: BorderRadius.circular(8),
        border: widget.selected ? Border.all(color: Colors.white, width: 2) : null,
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (full && c.image.isNotEmpty) SizedBox(height: 144, child: _BlobImage(id: c.image)),
          Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body)),
          if (full) const SizedBox(height: 44),
        ]),
        if (full && widget.onMove != null)
          Positioned(
            left: 8,
            bottom: 8,
            child: Row(children: [
              _react(Icons.chevron_left_rounded, 'Move back', c.column > 0 ? () => widget.onMove!(-1) : null),
              _react(Icons.chevron_right_rounded, 'Move on', c.column < 2 ? () => widget.onMove!(1) : null),
            ]),
          ),
      ]),
    );
    if (widget.onTap == null || widget.editing) return card;
    return GestureDetector(onTap: widget.onTap, child: card);
  }

  Widget _react(IconData icon, String tip, VoidCallback? onTap) => VPress(
        onTap: onTap,
        tooltip: tip,
        child: SizedBox(width: 28, height: 28, child: Icon(icon, size: 18, color: widget.ink2.withValues(alpha: onTap == null ? 0.3 : 1))),
      );
}
