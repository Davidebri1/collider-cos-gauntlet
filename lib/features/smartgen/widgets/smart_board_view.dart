import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/smartgen_models.dart';
import '../state/smartgen_store.dart';
import 'sg_kanban.dart';
import 'sg_board_views.dart';
import 'smartgen_icons.dart';
import 'smart_card_widget.dart';
import 'smart_canvas_widget.dart';
import '../theme/smartgen_glass.dart';
import '../../../core/theme/app_fonts.dart';

/// The board work surface. Renders according to the board template's settings:
/// - Kanban boards: horizontal columns with drag-and-drop between statuses.
/// - Freeform boards (desk, whiteboard, table...): cards and canvases placed
///   at x/y coordinates, draggable with the pointer.
///
/// Cards dropped onto a canvas container are adopted by that canvas.
class SmartBoardView extends StatefulWidget {
  final SmartBoard board;
  final ComponentTemplate? template;
  final SmartGenStore store;
  final String searchQuery;
  final String cardFilter; // 'all' | 'active' | 'urgent'
  // Spec §12 multi-select, §13 search jump-to-card.
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggleSelect;
  final String? highlightCardId;

  const SmartBoardView({
    super.key,
    required this.board,
    required this.template,
    required this.store,
    this.searchQuery = '',
    this.cardFilter = 'all',
    this.selectMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.highlightCardId,
  });

  @override
  State<SmartBoardView> createState() => _SmartBoardViewState();
}

class _SmartBoardViewState extends State<SmartBoardView> {
  SmartBoard get board => widget.board;
  SmartGenStore get store => widget.store;

  /// Canvas navigator (spec: up to 10 canvases per board). Null = board
  /// overview (all canvases as containers); otherwise the focused canvas
  /// is shown full-bleed with swipe + numbered-chip navigation.
  String? _focusedCanvasId;
  late final PageController _pageCtrl = PageController();

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _focusCanvas(String? id, List<SmartCanvas> canvases) {
    final wasFocused = _focusedCanvasId != null;
    setState(() => _focusedCanvasId = id);
    if (id != null) {
      final i = canvases.indexWhere((c) => c.id == id);
      if (i >= 0) {
        // Post-frame: the pager may not exist yet on first entry.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_pageCtrl.hasClients) return;
          final cur = (_pageCtrl.page ?? 0).round();
          if (cur == i) return;
          if (wasFocused) {
            _pageCtrl.animateToPage(i,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut);
          } else {
            _pageCtrl.jumpToPage(i);
          }
        });
      }
    }
  }

  bool get _isKanban {
    final s = widget.template?.settings ?? {};
    return s['freeform'] != true;
  }

  bool _matchesSearch(SmartCard c) {
    final q = widget.searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return c.title.toLowerCase().contains(q) ||
        c.values.values
            .any((v) => (v?.toString() ?? '').toLowerCase().contains(q));
  }

  bool _matchesFilter(SmartCard c) {
    switch (widget.cardFilter) {
      case 'active':
        return c.status.toLowerCase() != 'done';
      case 'urgent':
        return c.urgent;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Spec §6: the board template's `view` setting selects the surface.
    switch (widget.template?.settings['view'] as String?) {
      case 'calendar':
        return SGCalendarView(
          board: board,
          store: store,
          searchQuery: widget.searchQuery,
          cardFilter: widget.cardFilter,
          selectMode: widget.selectMode,
          selectedIds: widget.selectedIds,
          onToggleSelect: widget.onToggleSelect,
          highlightCardId: widget.highlightCardId,
        );
      case 'notebook':
        return SGNotebookView(
          board: board,
          store: store,
          searchQuery: widget.searchQuery,
          cardFilter: widget.cardFilter,
          selectMode: widget.selectMode,
          selectedIds: widget.selectedIds,
          onToggleSelect: widget.onToggleSelect,
          highlightCardId: widget.highlightCardId,
        );
      case 'album':
        return SGAlbumView(
          board: board,
          store: store,
          searchQuery: widget.searchQuery,
          cardFilter: widget.cardFilter,
          selectMode: widget.selectMode,
          selectedIds: widget.selectedIds,
          onToggleSelect: widget.onToggleSelect,
          highlightCardId: widget.highlightCardId,
        );
      case 'storyboard':
        return SGStoryboardView(
          board: board,
          store: store,
          searchQuery: widget.searchQuery,
          cardFilter: widget.cardFilter,
          selectMode: widget.selectMode,
          selectedIds: widget.selectedIds,
          onToggleSelect: widget.onToggleSelect,
          highlightCardId: widget.highlightCardId,
        );
      case 'vision':
        return SGVisionBoardView(
          board: board,
          store: store,
          searchQuery: widget.searchQuery,
          cardFilter: widget.cardFilter,
          selectMode: widget.selectMode,
          selectedIds: widget.selectedIds,
          onToggleSelect: widget.onToggleSelect,
          highlightCardId: widget.highlightCardId,
        );
      case 'swimlane':
        return SGSwimlaneView(
          board: board,
          store: store,
          searchQuery: widget.searchQuery,
          cardFilter: widget.cardFilter,
          selectMode: widget.selectMode,
          selectedIds: widget.selectedIds,
          onToggleSelect: widget.onToggleSelect,
          highlightCardId: widget.highlightCardId,
        );
      case 'files':
        return SGFilesView(
          board: board,
          store: store,
          searchQuery: widget.searchQuery,
          cardFilter: widget.cardFilter,
          selectMode: widget.selectMode,
          selectedIds: widget.selectedIds,
          onToggleSelect: widget.onToggleSelect,
          highlightCardId: widget.highlightCardId,
        );
      case 'us_map':
        return SGMapView(
          board: board,
          store: store,
          searchQuery: widget.searchQuery,
          cardFilter: widget.cardFilter,
          selectMode: widget.selectMode,
          selectedIds: widget.selectedIds,
          onToggleSelect: widget.onToggleSelect,
          highlightCardId: widget.highlightCardId,
        );
      case 'world_map':
        return SGMapView(
          board: board,
          store: store,
          world: true,
          searchQuery: widget.searchQuery,
          cardFilter: widget.cardFilter,
          selectMode: widget.selectMode,
          selectedIds: widget.selectedIds,
          onToggleSelect: widget.onToggleSelect,
          highlightCardId: widget.highlightCardId,
        );
    }
    if (widget.template?.settings['swimlanes'] == true) {
      return SGSwimlaneView(
        board: board,
        store: store,
        searchQuery: widget.searchQuery,
        cardFilter: widget.cardFilter,
        selectMode: widget.selectMode,
        selectedIds: widget.selectedIds,
        onToggleSelect: widget.onToggleSelect,
        highlightCardId: widget.highlightCardId,
      );
    }
    return _isKanban ? _buildKanban() : _buildFreeform();
  }

  // ---------------- kanban ----------------
  // Native Trello-derived drag mechanics in the visionOS glass skin.
  // See sg_kanban.dart.

  Widget _buildKanban() {
    return SGKanbanBoard(
      board: board,
      template: widget.template,
      store: store,
      searchQuery: widget.searchQuery,
      cardFilter: widget.cardFilter,
      selectMode: widget.selectMode,
      selectedIds: widget.selectedIds,
      onToggleSelect: widget.onToggleSelect,
      highlightCardId: widget.highlightCardId,
    );
  }

  // ---------------- freeform ----------------

  Widget _buildFreeform() {
    final canvases = store.boardCanvases(board.id);
    // Drop a stale focus (e.g. the canvas was deleted).
    if (_focusedCanvasId != null &&
        canvases.every((c) => c.id != _focusedCanvasId)) {
      _focusedCanvasId = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Always show the navigator: when empty it holds the Board chip
        // and the add-canvas button, making first-canvas creation
        // discoverable without a modal or hidden gesture.
        _buildCanvasNavigator(canvases),
        Expanded(
          child: _focusedCanvasId == null
              ? _buildFreeformOverview(canvases)
              : _buildCanvasPager(canvases),
        ),
      ],
    );
  }

  /// Canvas navigator strip: numbered chips with each canvas's icon and
  /// name, an overview chip, and an add-canvas button (10-canvas cap).
  Widget _buildCanvasNavigator(List<SmartCanvas> canvases) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: canvases.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _navChip(
              key: const ValueKey('nav-overview'),
              icon: Icons.grid_view_rounded,
              label: 'Board',
              selected: _focusedCanvasId == null,
              onTap: () => _focusCanvas(null, canvases),
            );
          }
          if (i == canvases.length + 1) {
            if (canvases.length >= SmartGenStore.maxCanvasesPerBoard) {
              return const SizedBox.shrink();
            }
            return _navChip(
              icon: Icons.add_rounded,
              label: 'Canvas',
              onTap: _addCanvas,
            );
          }
          final cv = canvases[i - 1];
          final tpl = store.template(cv.templateId);
          return _navChip(
            key: ValueKey('nav-canvas-${cv.id}'),
            number: i,
            icon: smartGenIcon(tpl?.iconName ?? 'widgets_rounded'),
            label: cv.title,
            selected: _focusedCanvasId == cv.id,
            onTap: () => _focusCanvas(cv.id, canvases),
          );
        },
      ),
    );
  }

  Widget _navChip({
    Key? key,
    int? number,
    required IconData icon,
    required String label,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? SGGlass.ink : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFFE0E0E0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (number != null) ...[
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : SGGlass.ink.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text('$number',
                      style: AppFonts.instrumentSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : SGGlass.ink2)),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(icon, size: 14, color: selected ? Colors.white : SGGlass.ink2),
            const SizedBox(width: 5),
            Text(label,
                style: AppFonts.instrumentSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : SGGlass.ink2)),
          ],
        ),
      ),
    );
  }

  void _addCanvas() {
    final tpl = store.templatesOf(ComponentKind.canvas).firstOrNull;
    if (tpl == null) return;
    // Cascade new canvases so they don't land exactly on top of the last one.
    final n = store.boardCanvases(board.id).length;
    final cv = store.instantiateCanvas(tpl.id,
        boardId: board.id, x: 40.0 + (n % 5) * 28, y: 40.0 + (n % 5) * 28);
    if (cv == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'This board already holds 10 canvases — the Smart Gen limit.')),
      );
    }
  }

  String? _renamingCanvasId;

  void _saveCanvasTitle(SmartCanvas cv, String title) {
    final t = title.trim();
    if (t.isNotEmpty && t != cv.title) {
      cv.title = t;
      store.updateCanvas(cv);
    }
    setState(() => _renamingCanvasId = null);
  }

  /// Focused canvas mode: swipe between canvases, one full-bleed page
  /// each, with the numbered navigator strip staying in sync.
  Widget _buildCanvasPager(List<SmartCanvas> canvases) {
    return PageView.builder(
      controller: _pageCtrl,
      itemCount: canvases.length,
      onPageChanged: (i) {
        if (_focusedCanvasId != canvases[i].id) {
          setState(() => _focusedCanvasId = canvases[i].id);
        }
      },
      itemBuilder: (context, i) => _buildCanvasPage(canvases[i], i),
    );
  }

  Widget _buildCanvasPage(SmartCanvas cv, int index) {
    final tpl = store.template(cv.templateId);
    final cards = store
        .canvasCards(cv.id)
        .where((c) => _matchesSearch(c) && _matchesFilter(c))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: SGGlass.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text('${index + 1}',
                      style: AppFonts.instrumentSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              Icon(smartGenIcon(tpl?.iconName ?? 'widgets_rounded'),
                  size: 18, color: SGGlass.ink2),
              const SizedBox(width: 8),
              Expanded(
                child: _renamingCanvasId == cv.id
                    ? _CanvasTitleField(
                        initial: cv.title,
                        onCancel: () =>
                            setState(() => _renamingCanvasId = null),
                        onSubmit: (t) => _saveCanvasTitle(cv, t),
                      )
                    : GestureDetector(
                        onTap: () => setState(() => _renamingCanvasId = cv.id),
                        behavior: HitTestBehavior.opaque,
                        child: Text(cv.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.instrumentSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: SGGlass.ink)),
                      ),
              ),
              Text('${cards.length} card${cards.length == 1 ? '' : 's'}',
                  style: AppFonts.instrumentSans(
                      fontSize: 12, color: SGGlass.ink3)),
            ],
          ),
        ),
        Expanded(
          child: cards.isEmpty
              ? Center(
                  child: Text('No cards here yet.',
                      style: AppFonts.instrumentSans(
                          fontSize: 13, color: SGGlass.ink3)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: cards.length,
                  itemBuilder: (context, i) {
                    final c = cards[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SelectableCardWrap(
                        selected: widget.selectedIds.contains(c.id),
                        highlighted: widget.highlightCardId == c.id,
                        selectMode: widget.selectMode,
                        onToggleSelect: widget.onToggleSelect == null
                            ? null
                            : () => widget.onToggleSelect!(c.id),
                        child: SmartCardWidget(
                          card: c,
                          template: store.template(c.templateId),
                          store: store,
                          kanbanMode: false,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// The board template's physical surface material, if any.
  String? get _surfaceKind => widget.template?.settings['surface'] as String?;

  Widget _buildFreeformOverview(List<SmartCanvas> canvases) {
    final cards = store
        .boardCards(board.id)
        .where(
            (c) => c.canvasId == null && _matchesSearch(c) && _matchesFilter(c))
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            // Physical surface: the board template's `surface` setting
            // (wood / metal) paints a real-material backdrop; anything
            // else keeps the clean neutral board.
            Positioned.fill(child: _SurfaceBackdrop(kind: _surfaceKind)),
            // Cards on the bare board surface.
            for (final card in cards)
              Positioned(
                left: card.x.clamp(0.0, size.width - 80),
                top: card.y.clamp(0.0, size.height - 60),
                child: _SelectableCardWrap(
                  selected: widget.selectedIds.contains(card.id),
                  highlighted: widget.highlightCardId == card.id,
                  selectMode: widget.selectMode,
                  onToggleSelect: widget.onToggleSelect == null
                      ? null
                      : () => widget.onToggleSelect!(card.id),
                  child: Draggable<String>(
                    data: 'card:${card.id}',
                    feedback: Material(
                      color: Colors.transparent,
                      child: Opacity(
                        opacity: 0.92,
                        child: SmartCardWidget(
                          card: card,
                          template: store.template(card.templateId),
                          store: store,
                          kanbanMode: false,
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.25,
                      child: SmartCardWidget(
                        card: card,
                        template: store.template(card.templateId),
                        store: store,
                        kanbanMode: false,
                      ),
                    ),
                    onDragEnd: (details) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box == null) return;
                      final local = box.globalToLocal(details.offset);
                      // Adopt into a canvas if dropped inside one.
                      for (final cv in canvases) {
                        if (local.dx >= cv.x &&
                            local.dx <= cv.x + cv.width &&
                            local.dy >= cv.y &&
                            local.dy <= cv.y + cv.height) {
                          store.moveCard(card.id,
                              canvasId: cv.id,
                              x: (local.dx - cv.x).clamp(0.0, cv.width - 80),
                              y: (local.dy - cv.y).clamp(0.0, cv.height - 60));
                          return;
                        }
                      }
                      store.moveCard(card.id,
                          x: local.dx.clamp(0.0, size.width - 80),
                          y: local.dy.clamp(0.0, size.height - 60));
                    },
                    child: SmartCardWidget(
                      card: card,
                      template: store.template(card.templateId),
                      store: store,
                      kanbanMode: false,
                    ),
                  ),
                ),
              ),
            // Canvas containers.
            for (final cv in canvases)
              Positioned(
                left: cv.x,
                top: cv.y,
                child: SmartCanvasWidget(
                  canvas: cv,
                  template: store.template(cv.templateId),
                  store: store,
                  searchQuery: widget.searchQuery,
                  boardSize: size,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Wraps a freeform card for spec §12 multi-select and §13 search highlight:
/// in select mode the card is not draggable — a tap toggles selection and
/// selected cards get a blue outline.
class _SelectableCardWrap extends StatelessWidget {
  final Widget child;
  final bool selectMode;
  final bool selected;
  final bool highlighted;
  final VoidCallback? onToggleSelect;

  const _SelectableCardWrap({
    required this.child,
    this.selectMode = false,
    this.selected = false,
    this.highlighted = false,
    this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    Widget w = highlighted ? SGHighlightPulse(child: child) : child;
    if (!selectMode) return w;
    return Stack(
      children: [
        AbsorbPointer(absorbing: true, child: w),
        Positioned.fill(
          child: GestureDetector(
            onTap: onToggleSelect,
            behavior: HitTestBehavior.opaque,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      selected ? const Color(0xFF0A84FF) : Colors.transparent,
                  width: 2.5,
                ),
                color: selected
                    ? const Color(0xFF0A84FF).withValues(alpha: 0.08)
                    : Colors.transparent,
              ),
              child: selected
                  ? const Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.check_circle_rounded,
                            size: 20, color: Color(0xFF0A84FF)),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints the board's physical surface material behind freeform cards.
///
/// Wood and brushed metal are derived from their real-world counterparts:
/// wood gets long grain streaks with a gentle wave and a few knots over a
/// warm oak base; metal gets fine horizontal brushing over cool steel with
/// a soft diagonal sheen. Both are seeded so repaints are stable.
class _SurfaceBackdrop extends StatelessWidget {
  final String? kind;

  const _SurfaceBackdrop({required this.kind});

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case 'wood':
        return CustomPaint(
            key: const ValueKey('surface-wood'), painter: _WoodPainter());
      case 'metal':
        return CustomPaint(
            key: const ValueKey('surface-metal'), painter: _MetalPainter());
      default:
        return Container(
            key: const ValueKey('surface-neutral'),
            color: const Color(0xFFF4F2EC));
    }
  }
}

class _WoodPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9A6B3D), Color(0xFF7C5228), Color(0xFF8A5F33)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    // Seeded pseudo-random so the grain never flickers between repaints.
    var seed = 0x2F6E2B1;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      return seed / 0x7FFFFFFF;
    }

    // Long grain streaks with a gentle wave, like sawn oak planks.
    for (var i = 0; i < 46; i++) {
      final y0 = rnd() * size.height;
      final amp = 2 + rnd() * 7;
      final phase = rnd() * 6.28;
      final dark = rnd() > 0.35;
      final paint = Paint()
        ..color = (dark ? const Color(0xFF5E3D1E) : const Color(0xFFB98A52))
            .withValues(alpha: 0.10 + rnd() * 0.12)
        ..strokeWidth = 0.8 + rnd() * 1.8
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(-10, y0);
      for (var x = -10.0; x <= size.width + 10; x += 18) {
        path.lineTo(x, y0 + amp * math.sin(0.6 * (x / 90 + phase)));
      }
      canvas.drawPath(path, paint);
    }

    // A few knots: concentric soft ellipses.
    for (var k = 0; k < 3; k++) {
      final cx = rnd() * size.width;
      final cy = rnd() * size.height;
      for (var r = 16.0; r > 3; r -= 3.5) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: r * 1.7, height: r),
          Paint()
            ..color = const Color(0xFF5E3D1E)
                .withValues(alpha: 0.10 + (16 - r) * 0.008)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }

    // Soft top light, like a desk under a window.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.12),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MetalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFC3C8CF), Color(0xFFA9B0B9), Color(0xFFB7BDC5)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    var seed = 0x5BD1E995;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      return seed / 0x7FFFFFFF;
    }

    // Fine horizontal brushing, alternating light and dark at low alpha.
    for (var i = 0; i < 130; i++) {
      final y = rnd() * size.height;
      final light = rnd() > 0.5;
      canvas.drawLine(
        Offset(-8, y),
        Offset(size.width + 8, y + (rnd() - 0.5) * 3),
        Paint()
          ..color = (light ? Colors.white : const Color(0xFF6E747D))
              .withValues(alpha: 0.05 + rnd() * 0.06)
          ..strokeWidth = 0.7,
      );
    }

    // Soft diagonal sheen, like brushed steel catching the light.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.10),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Inline canvas title editor.
class _CanvasTitleField extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;
  const _CanvasTitleField(
      {required this.initial, required this.onSubmit, required this.onCancel});

  @override
  State<_CanvasTitleField> createState() => _CanvasTitleFieldState();
}

class _CanvasTitleFieldState extends State<_CanvasTitleField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            style: AppFonts.instrumentSans(
                fontSize: 15, fontWeight: FontWeight.w700, color: SGGlass.ink),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            onSubmitted: widget.onSubmit,
          ),
        ),
        GestureDetector(
          onTap: () => widget.onSubmit(_ctrl.text),
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.check_rounded, size: 18, color: SGGlass.ink2),
          ),
        ),
        GestureDetector(
          onTap: widget.onCancel,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close_rounded, size: 18, color: SGGlass.ink3),
          ),
        ),
      ],
    );
  }
}
