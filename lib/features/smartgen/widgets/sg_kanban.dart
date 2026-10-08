import 'dart:async';
import 'package:flutter/material.dart';
import 'package:collider_flutter/core/theme/app_fonts.dart';
import '../models/smartgen_models.dart';
import '../state/smartgen_store.dart';
import '../theme/smartgen_glass.dart';
import 'sg_card_face.dart';
import 'sg_menu.dart';

/// Drag payload for kanban cards. The source column is read from the store
/// at drop time so it can never go stale mid-drag.
class SGDragData {
  final String cardId;
  const SGDragData(this.cardId);
}

/// Pure helper: maps a drop at [visibleGap] (an index into [visible], the
/// render-filtered subset of [full]) onto the new full column order with
/// [dragged] inserted. Filtering is render-only, so the full order —
/// including filtered-out cards — is always preserved verbatim.
List<SmartCard> insertAtVisibleGap({
  required List<SmartCard> full,
  required List<SmartCard> visible,
  required SmartCard dragged,
  required int visibleGap,
}) {
  final remaining = full.where((c) => c.id != dragged.id).toList();
  if (visibleGap < visible.length) {
    final anchor = visible[visibleGap];
    final at = remaining.indexWhere((c) => c.id == anchor.id);
    final i = at < 0 ? remaining.length : at;
    return [...remaining.sublist(0, i), dragged, ...remaining.sublist(i)];
  }
  return [...remaining, dragged];
}

/// Native Smart Gen kanban — Trello-derived drag mechanics in the visionOS
/// glass skin, built for mobile touch.
///
/// - Columns page horizontally with snap; cards scroll vertically.
/// - Long-press lifts a card (physical lift: scale + deep shadow).
/// - Gap drop targets show the white insertion bar (the reference's answer
///   to Trello's blue line).
/// - Auto-scroll runs at the vertical and horizontal edges while dragging.
/// - Search and the All/Active/Urgent filter are render-only: drops always
///   resolve against the full column order, so filtered-out cards can never
///   be orphaned or reordered by accident.
class SGKanbanBoard extends StatefulWidget {
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

  const SGKanbanBoard({
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
  State<SGKanbanBoard> createState() => _SGKanbanBoardState();
}

class _ColumnDef {
  final String key;
  final String label;
  const _ColumnDef(this.key, this.label);
}

class _SGKanbanBoardState extends State<SGKanbanBoard> {
  late PageController _pageController;
  double _fraction = 0.88;
  final Map<String, ScrollController> _colScroll = {};
  final Map<String, GlobalKey> _colKeys = {};
  Timer? _scrollTick;
  Offset? _dragPointer; // global, updated while dragging
  bool _dragging = false;
  String? _hoverColumn;
  int? _hoverGap;
  String? _highlightId;
  Timer? _highlightTimer;

  SmartGenStore get store => widget.store;

  List<_ColumnDef> get _columns {
    final cols = widget.template?.settings['columns'];
    final labels = (cols is List && cols.isNotEmpty)
        ? cols.map((e) => e.toString()).toList()
        : const ['To Do', 'In Progress', 'Done'];
    return labels
        .map((l) => _ColumnDef(
            l.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'), l))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateWidget(covariant SGKanbanBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.highlightCardId;
    if (id != null && id != oldWidget.highlightCardId) {
      _jumpToCard(id);
    }
    if (!widget.selectMode && oldWidget.selectMode) {
      _highlightId = null;
    }
  }

  /// Spec §13: jump to a card in place — page to its column and pulse it.
  void _jumpToCard(String cardId) {
    final card = store.card(cardId);
    if (card == null) return;
    final cols = _columns;
    final idx =
        cols.indexWhere((c) => c.key == normalizeKanbanStatus(card.status));
    if (idx >= 0 && _pageController.hasClients) {
      _pageController.animateToPage(idx,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
    _highlightTimer?.cancel();
    setState(() => _highlightId = cardId);
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _highlightId = null);
    });
  }

  @override
  void dispose() {
    _scrollTick?.cancel();
    _highlightTimer?.cancel();
    _pageController.dispose();
    for (final c in _colScroll.values) {
      c.dispose();
    }
    store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  // ---------------- filtering (render-only) ----------------

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

  bool _visible(SmartCard c) => _matchesSearch(c) && _matchesFilter(c);

  // ---------------- drag plumbing ----------------

  /// Keeps columns phone-sized on wide screens: the page width is capped
  /// at 420pt and the viewport fraction recomputed so pages stay centered
  /// with a peek of their neighbors.
  PageController _controllerFor(double viewportWidth) {
    final f = ((viewportWidth * 0.88).clamp(0.0, 420.0)) / viewportWidth;
    if ((f - _fraction).abs() > 0.001) {
      _fraction = f;
      final old = _pageController;
      final page = old.hasClients ? (old.page?.round() ?? 0) : 0;
      _pageController = PageController(viewportFraction: f, initialPage: page);
      old.dispose();
    }
    return _pageController;
  }

  ScrollController _scrollFor(String colKey) =>
      _colScroll.putIfAbsent(colKey, () => ScrollController());

  GlobalKey _keyFor(String colKey) =>
      _colKeys.putIfAbsent(colKey, () => GlobalKey());

  void _onDragStart() {
    setState(() => _dragging = true);
    _ensureTick();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _dragPointer = d.globalPosition;
  }

  void _onDragEnd() {
    _dragging = false;
    _dragPointer = null;
    _scrollTick?.cancel();
    _scrollTick = null;
    if (_hoverColumn != null || _hoverGap != null) {
      setState(() {
        _hoverColumn = null;
        _hoverGap = null;
      });
    }
  }

  void _ensureTick() {
    _scrollTick ??=
        Timer.periodic(const Duration(milliseconds: 16), (_) => _autoScroll());
  }

  void _autoScroll() {
    final pos = _dragPointer;
    if (!_dragging || pos == null) return;
    const edge = 64.0;
    const speed = 14.0;

    // Vertical: scroll the column under the pointer.
    for (final col in _columns) {
      final key = _colKeys[col.key];
      final box = key?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (!rect.contains(pos)) continue;
      final ctrl = _colScroll[col.key];
      if (ctrl == null || !ctrl.hasClients) continue;
      if (pos.dy < rect.top + edge) {
        ctrl.jumpTo(
            (ctrl.offset - speed).clamp(0.0, ctrl.position.maxScrollExtent));
      } else if (pos.dy > rect.bottom - edge) {
        ctrl.jumpTo(
            (ctrl.offset + speed).clamp(0.0, ctrl.position.maxScrollExtent));
      }
      break;
    }

    // Horizontal: scroll the board at the screen edges.
    if (_pageController.hasClients) {
      final w = MediaQuery.of(context).size.width;
      const hEdge = 48.0;
      const hSpeed = 10.0;
      final offset = _pageController.offset;
      final max = _pageController.position.maxScrollExtent;
      if (pos.dx < hEdge) {
        _pageController.jumpTo((offset - hSpeed).clamp(0.0, max));
      } else if (pos.dx > w - hEdge) {
        _pageController.jumpTo((offset + hSpeed).clamp(0.0, max));
      }
    }
  }

  /// Commit a drop at [visibleGap] (index into the *visible* cards of the
  /// column). The visible index is mapped through neighboring visible cards
  /// onto the full column order, which is then persisted verbatim.
  void _drop(SGDragData data, String toStatus, int visibleGap) {
    final card = store.card(data.cardId);
    if (card == null) return;
    final fromStatus = card.status;

    final fullDest = store.boardCards(widget.board.id, status: toStatus);
    final visible = fullDest.where(_visible).toList();
    final newOrder = insertAtVisibleGap(
      full: fullDest,
      visible: visible,
      dragged: card,
      visibleGap: visibleGap,
    );

    store.moveCard(card.id, status: toStatus, canvasId: null);
    store.setColumnOrder(
        widget.board.id, toStatus, newOrder.map((c) => c.id).toList());
    if (fromStatus != toStatus) {
      final srcFull = store.boardCards(widget.board.id, status: fromStatus);
      store.setColumnOrder(
          widget.board.id, fromStatus, srcFull.map((c) => c.id).toList());
    }
  }

  void _addCard(String status, String title) {
    final templates = store.templatesOf(ComponentKind.card);
    if (templates.isEmpty) return;
    final tpl = templates.firstWhere(
      (t) => t.typeKey == 'task',
      orElse: () => templates.first,
    );
    store.instantiateCard(
      tpl.id,
      boardId: widget.board.id,
      status: status,
      title: title,
    );
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final cols = _columns;
    return LayoutBuilder(
      builder: (context, constraints) {
        final vw = constraints.maxWidth.clamp(1.0, 10000.0);
        // Phone: centered paging with a peek of neighboring columns.
        // Wide: Trello-style left-aligned columns, no leading dead zone.
        final padEnds = vw < 600;
        return PageView.builder(
          controller: _controllerFor(vw),
          padEnds: padEnds,
          itemCount: cols.length,
          itemBuilder: (context, i) => _ColumnView(
            key: _keyFor(cols[i].key),
            column: cols[i],
            store: store,
            board: widget.board,
            fullCards: store.boardCards(widget.board.id, status: cols[i].key),
            visibleCards: store
                .boardCards(widget.board.id, status: cols[i].key)
                .where(_visible)
                .toList(),
            scrollController: _scrollFor(cols[i].key),
            hoverGap: _hoverColumn == cols[i].key ? _hoverGap : null,
            dragArmed: _dragging,
            onHoverGap: (gap) => setState(() {
              _hoverColumn = gap == null ? null : cols[i].key;
              _hoverGap = gap;
            }),
            onDrop: (data, gap) => _drop(data, cols[i].key, gap),
            onDragStart: _onDragStart,
            onDragUpdate: _onDragUpdate,
            onDragEnd: _onDragEnd,
            onAddCard: (title) => _addCard(cols[i].key, title),
            selectMode: widget.selectMode,
            selectedIds: widget.selectedIds,
            onToggleSelect: widget.onToggleSelect,
            highlightId: _highlightId,
          ),
        );
      },
    );
  }
}

/// One kanban column: glass header chip + scrollable card list with gap
/// drop targets + inline add composer.
class _ColumnView extends StatefulWidget {
  final _ColumnDef column;
  final SmartGenStore store;
  final SmartBoard board;
  final List<SmartCard> fullCards;
  final List<SmartCard> visibleCards;
  final ScrollController scrollController;
  final int? hoverGap;
  final bool dragArmed;
  final ValueChanged<int?> onHoverGap;
  final void Function(SGDragData data, int gap) onDrop;
  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueChanged<String> onAddCard;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggleSelect;
  final String? highlightId;

  const _ColumnView({
    super.key,
    required this.column,
    required this.store,
    required this.board,
    this.selectMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.highlightId,
    required this.fullCards,
    required this.visibleCards,
    required this.scrollController,
    required this.hoverGap,
    required this.dragArmed,
    required this.onHoverGap,
    required this.onDrop,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onAddCard,
  });

  @override
  State<_ColumnView> createState() => _ColumnViewState();
}

class _ColumnViewState extends State<_ColumnView> {
  bool _composing = false;

  @override
  Widget build(BuildContext context) {
    final cards = widget.visibleCards;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ColumnHeader(
            label: widget.column.label,
            count: widget.fullCards.length,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  _Gap(
                    index: i,
                    hovered: widget.hoverGap == i,
                    armed: widget.dragArmed,
                    minHeight: 6,
                    onHover: widget.onHoverGap,
                    onDrop: widget.onDrop,
                  ),
                  _DraggableCard(
                    card: cards[i],
                    store: widget.store,
                    onDragStart: widget.onDragStart,
                    onDragUpdate: widget.onDragUpdate,
                    onDragEnd: widget.onDragEnd,
                    selectMode: widget.selectMode,
                    selected: widget.selectedIds.contains(cards[i].id),
                    highlighted: widget.highlightId == cards[i].id,
                    onToggleSelect: widget.onToggleSelect == null
                        ? null
                        : () => widget.onToggleSelect!(cards[i].id),
                  ),
                ],
                _Gap(
                  index: cards.length,
                  hovered: widget.hoverGap == cards.length,
                  armed: widget.dragArmed,
                  minHeight: cards.isEmpty ? 160 : 72,
                  emptyHint: cards.isEmpty,
                  onHover: widget.onHoverGap,
                  onDrop: widget.onDrop,
                ),
                const SizedBox(height: 6),
                if (_composing)
                  _Composer(
                    onSubmit: (t) {
                      widget.onAddCard(t);
                    },
                    onClose: () => setState(() => _composing = false),
                  )
                else
                  _AddButton(onTap: () => setState(() => _composing = true)),
                const SizedBox(height: 96), // clears the floating filter bar
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  final String label;
  final int count;

  const _ColumnHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: SGGlass.deepFill,
            borderRadius: BorderRadius.circular(SGGlass.rPill),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.22), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: AppFonts.instrumentSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(SGGlass.rPill),
                ),
                child: Text('$count',
                    style: AppFonts.instrumentSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A drop target in the gap before card [index]. Shows the white insertion
/// bar while hovered.
class _Gap extends StatelessWidget {
  final int index;
  final bool hovered;
  final bool armed;
  final double minHeight;
  final bool emptyHint;
  final ValueChanged<int?> onHover;
  final void Function(SGDragData data, int gap) onDrop;

  const _Gap({
    required this.index,
    required this.hovered,
    required this.minHeight,
    required this.onHover,
    required this.onDrop,
    this.armed = false,
    this.emptyHint = false,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<SGDragData>(
      onWillAcceptWithDetails: (_) {
        onHover(index);
        return true;
      },
      onLeave: (_) => onHover(null),
      onAcceptWithDetails: (d) {
        onHover(null);
        onDrop(d.data, index);
      },
      builder: (context, candidate, rejected) {
        // While a drag is armed the gaps open up so a finger can actually
        // hit them; at rest they collapse to hairlines.
        final h = hovered ? 30.0 : (armed ? 26.0 : minHeight);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: h,
          alignment: Alignment.center,
          child: hovered
              ? Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(SGGlass.rPill),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x59000000),
                          blurRadius: 8,
                          offset: Offset(0, 2)),
                    ],
                  ),
                )
              : (emptyHint
                  ? Text('Drop cards here',
                      style: AppFonts.instrumentSans(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.35)))
                  : null),
        );
      },
    );
  }
}

class _DraggableCard extends StatelessWidget {
  final SmartCard card;
  final SmartGenStore store;
  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;
  // Spec §12 multi-select.
  final bool selectMode;
  final bool selected;
  final bool highlighted;
  final VoidCallback? onToggleSelect;

  const _DraggableCard({
    required this.card,
    required this.store,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.selectMode = false,
    this.selected = false,
    this.highlighted = false,
    this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final body =
        SGKanbanCard(card: card, store: store, highlighted: highlighted);
    Widget w = LongPressDraggable<SGDragData>(
      data: SGDragData(card.id),
      delay: const Duration(milliseconds: 220),
      onDragStarted: onDragStart,
      onDragUpdate: onDragUpdate,
      onDragEnd: (_) => onDragEnd(),
      onDragCompleted: onDragEnd,
      onDraggableCanceled: (_, __) => onDragEnd(),
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Transform.scale(
            scale: 1.05,
            child: Container(
              decoration: const BoxDecoration(
                boxShadow: SGGlass.liftShadow,
                borderRadius: BorderRadius.all(Radius.circular(SGGlass.rCard)),
              ),
              child: Opacity(opacity: 0.96, child: body),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: body),
      child: body,
    );
    if (selectMode) {
      // In select mode the card is not draggable or editable: a tap
      // toggles its selection, and selection shows a blue outline.
      w = Stack(
        children: [
          AbsorbPointer(absorbing: true, child: w),
          Positioned.fill(
            child: GestureDetector(
              onTap: onToggleSelect,
              behavior: HitTestBehavior.opaque,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(SGGlass.rCard),
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
    return w;
  }
}

/// The light frosted kanban card (Widgets Board recipe): tinted type icon,
/// inline-editable title, notes snippet, due chip, urgent marker, overflow
/// menu. Tap the title to rename inline — no modal, ever.
class SGKanbanCard extends StatefulWidget {
  final SmartCard card;
  final SmartGenStore store;
  final bool highlighted;

  const SGKanbanCard(
      {super.key,
      required this.card,
      required this.store,
      this.highlighted = false});

  @override
  State<SGKanbanCard> createState() => _SGKanbanCardState();
}

class _SGKanbanCardState extends State<SGKanbanCard> {
  bool _editing = false;
  late final TextEditingController _ctrl;

  SmartCard get card => widget.card;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: card.title);
  }

  @override
  void didUpdateWidget(covariant SGKanbanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.card.title != card.title) {
      _ctrl.text = card.title;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _commit() {
    final t = _ctrl.text.trim();
    if (t.isNotEmpty && t != card.title) {
      card.title = t;
      widget.store.updateCard(card);
    } else {
      _ctrl.text = card.title;
    }
    setState(() => _editing = false);
  }


  @override
  Widget build(BuildContext context) {
    final tpl = widget.store.template(card.templateId);
    final panel = SGCardFace(
      card: card,
      template: tpl,
      snippet: SGCardFace.snippetFor(card, tpl),
      onMenuAt: _showCardMenu,
      title: _editing
          ? TextField(
              controller: _ctrl,
              autofocus: true,
              style: AppFonts.instrumentSans(
                  fontSize: 14, fontWeight: FontWeight.w600, color: SGGlass.ink),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _commit(),
              onTapOutside: (_) => _commit(),
            )
          : GestureDetector(
              onTap: () => setState(() => _editing = true),
              behavior: HitTestBehavior.opaque,
              child: Text(
                card.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.instrumentSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: SGGlass.ink),
              ),
            ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: widget.highlighted ? SGHighlightPulse(child: panel) : panel,
    );
  }


  void _showCardMenu(Offset at) {
    SGMenu.show(
      context,
      at: at,
      items: [
        SGMenuItem(
          icon: card.urgent
              ? Icons.notifications_off_outlined
              : Icons.notifications_active_outlined,
          label: card.urgent ? 'Clear urgent' : 'Mark urgent',
          onTap: () {
            card.urgent = !card.urgent;
            widget.store.updateCard(card);
          },
        ),
        SGMenuItem(
          icon: Icons.delete_outline_rounded,
          label: 'Delete card',
          destructive: true,
          onTap: () => widget.store.deleteCard(card.id),
        ),
      ],
    );
  }
}

/// Pulsing accent outline used when search jumps to a card in place
/// (spec §13) — the card flashes briefly so the user can spot it.
class SGHighlightPulse extends StatefulWidget {
  final Widget child;
  const SGHighlightPulse({super.key, required this.child});

  @override
  State<SGHighlightPulse> createState() => _HighlightPulseState();
}

class _HighlightPulseState extends State<SGHighlightPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SGGlass.rCard),
          border: Border.all(
            color: const Color(0xFF0A84FF)
                .withValues(alpha: 0.45 + 0.55 * _ctrl.value),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  const Color(0xFF0A84FF).withValues(alpha: 0.25 * _ctrl.value),
              blurRadius: 14,
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Inline "new card" composer at the foot of a kanban column.
class _Composer extends StatefulWidget {
  final ValueChanged<String> onSubmit;
  final VoidCallback onClose;
  const _Composer({required this.onSubmit, required this.onClose});

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    widget.onSubmit(t);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel.card(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            style: AppFonts.instrumentSans(fontSize: 14, color: SGGlass.ink),
            decoration: InputDecoration(
              hintText: 'Card title…',
              hintStyle:
                  AppFonts.instrumentSans(fontSize: 14, color: SGGlass.ink3),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: _submit,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: SGGlass.sysBlue,
                    borderRadius: BorderRadius.circular(SGGlass.rPill),
                  ),
                  child: Text('Add card',
                      style: AppFonts.instrumentSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onClose,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Cancel',
                      style: AppFonts.instrumentSans(
                          fontSize: 13, color: SGGlass.ink2)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "+ Add card" button at the foot of a kanban column.
class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E).withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x1EFFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text('Add card',
                style: AppFonts.instrumentSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
