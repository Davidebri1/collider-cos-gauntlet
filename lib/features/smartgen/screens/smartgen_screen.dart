import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collider_flutter/core/theme/app_fonts.dart';
import '../models/smartgen_models.dart';
import '../state/smartgen_store.dart';
import '../theme/smartgen_glass.dart';
import '../widgets/component_drawer.dart';
import '../widgets/sg_filter_bar.dart';
import '../widgets/sg_side_rail.dart';
import '../widgets/sg_toolbar.dart';
import '../widgets/smart_board_view.dart';
import '../widgets/smart_genie_panel.dart';

/// The Smart Gen workspace — a visionOS glass window ported to mobile.
///
/// Layout (mobile):
/// - Floating dark-glass window holding a slim icon rail, the contextual
///   component drawer, and the board work surface.
/// - Top toolbar: back, inline-renamable board title, inline search,
///   board actions (ported from the Figma toolbar).
/// - Bottom-center floating filter bar: All / Active / Urgent (ported from
///   the Photos segmented toolbar).
/// - Genie floats bottom-right, minimizing back to the rail.
///
/// Entry stays contextual: rail icons unfold drawers; tapping a type
/// instantly deploys an instance. No hub, no separate board menu.
class SmartGenScreen extends StatefulWidget {
  final VoidCallback onClose;
  final bool isPro;
  final bool isElite;

  const SmartGenScreen({
    super.key,
    required this.onClose,
    this.isPro = false,
    this.isElite = false,
  });

  @override
  State<SmartGenScreen> createState() => _SmartGenScreenState();
}

/// Template-derived accent tint (same palette as the kanban card icons).
Color _tintFor(SmartCard card) {
  const tints = [
    SGGlass.sysBlue,
    SGGlass.sysPurple,
    SGGlass.sysTeal,
    SGGlass.sysOrange,
    SGGlass.sysGreen,
    SGGlass.sysPink,
  ];
  return tints[card.templateId.hashCode.abs() % tints.length];
}

class _SmartGenScreenState extends State<SmartGenScreen> {
  late SmartGenStore _store;
  ComponentKind? _drawerKind;
  bool _genieOpen = false;
  bool _genieMinimized = false;
  String _searchQuery = '';
  String _cardFilter = 'all'; // 'all' | 'active' | 'urgent'
  bool _ready = false;
  // Spec §12 multi-select, §13 search jump, §14 statistics.
  bool _selectMode = false;
  bool _bulkEditOpen = false;
  bool _bulkDeleteConfirm = false;
  final Set<String> _selectedIds = {};
  String? _highlightCardId;
  bool _statsOpen = false;

  @override
  void initState() {
    super.initState();
    // Use the app-wide shared store (provided in main.dart) so that
    // saves from other surfaces (e.g. ticker message zoom) land here.
    _store = context.read<SmartGenStore>();
    _store.addListener(_onStoreChanged);
    _store.load().then((_) {
      // First run with nothing on it: show a working board, not an empty lane.
      _store.seedStarterIfEmpty();
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _store.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  int get _railActive {
    if (_genieOpen && !_genieMinimized) return 3;
    return switch (_drawerKind) {
      ComponentKind.card => 0,
      ComponentKind.canvas => 1,
      ComponentKind.board => 2,
      null => -1,
    };
  }

  void _onRailSelect(int i) {
    setState(() {
      if (i == 3) {
        _genieOpen = !_genieOpen;
        _genieMinimized = false;
        _drawerKind = null;
        return;
      }
      final kind = ComponentKind.values[i];
      _drawerKind = _drawerKind == kind ? null : kind;
    });
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) _selectedIds.clear();
      _bulkEditOpen = false;
      _bulkDeleteConfirm = false;
    });
  }

  void _toggleSelect(String cardId) {
    setState(() {
      if (_selectedIds.contains(cardId)) {
        _selectedIds.remove(cardId);
      } else {
        _selectedIds.add(cardId);
      }
    });
  }

  void _jumpToCard(String cardId) {
    setState(() {
      _highlightCardId = cardId;
      _searchQuery = '';
    });
  }

  /// True when the active board renders the files explorer, which owns
  /// the bottom chrome with its own floating toolbar.
  bool get _filesViewActive {
    final board = _store.activeBoard;
    if (board == null) return false;
    return _store.template(board.templateId)?.settings['view'] == 'files';
  }

  @override
  Widget build(BuildContext context) {
    // On narrow (phone) viewports the component drawer is a slide-over that
    // floats above the board — side-by-side would crush the board to a sliver.
    final narrow = MediaQuery.of(context).size.width < 600;
    final drawerOverlay = _drawerKind != null && narrow;
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: GlassPanel.window(
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                      child: SGSideRail(
                        onClose: widget.onClose,
                        entries: const [
                          SGRailEntry(Icons.style_rounded, 'Cards'),
                          SGRailEntry(Icons.crop_free_rounded, 'Canvases'),
                          SGRailEntry(Icons.dashboard_rounded, 'Boards'),
                          SGRailEntry(Icons.foggy, 'Genie'),
                        ],
                        activeIndex: _railActive,
                        onSelect: _onRailSelect,
                        onNew: () =>
                            setState(() => _drawerKind = ComponentKind.card),
                      ),
                    ),
                    if (_drawerKind != null && !narrow)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                        child: ComponentDrawer(
                          key: ValueKey(_drawerKind),
                          kind: _drawerKind!,
                          store: _store,
                          onClose: () => setState(() => _drawerKind = null),
                        ),
                      ),
                    Expanded(child: _buildBoardArea()),
                  ],
                ),
                // Dismiss scrim behind the slide-over drawer; the rail stays live.
                if (drawerOverlay)
                  Positioned(
                    left: 86,
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _drawerKind = null),
                      child: Container(
                          color: Colors.black.withValues(alpha: 0.18)),
                    ),
                  ),
                if (drawerOverlay)
                  Positioned(
                    left: 86,
                    top: 10,
                    bottom: 10,
                    child: ComponentDrawer(
                      key: ValueKey(_drawerKind),
                      kind: _drawerKind!,
                      store: _store,
                      onClose: () => setState(() => _drawerKind = null),
                    ),
                  ),
                // Floating filter bar, above the permanent dock (Photos toolbar recipe).
                // Hidden while the narrow drawer covers the board, and while
                // the files explorer owns the bottom chrome with its own
                // floating toolbar (no stacked pills).
                if (_ready && !drawerOverlay && !_filesViewActive)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 96,
                    child: Center(
                      child: SGFilterBar(
                        value: _cardFilter,
                        onChanged: (v) => setState(() => _cardFilter = v),
                      ),
                    ),
                  ),
                // Genie floats bottom-right; minimizes to the rail.
                if (_genieOpen && !_genieMinimized)
                  Positioned(
                    right: 14,
                    bottom: 76,
                    child: SmartGeniePanel(
                      store: _store,
                      isPro: widget.isPro,
                      isElite: widget.isElite,
                      onClose: () => setState(() => _genieOpen = false),
                      onMinimize: () => setState(() => _genieMinimized = true),
                    ),
                  ),
                // Note: the permanent bottom nav bar lives at the app shell
                // level (PermanentNavBar in main.dart) — SmartGen does not
                // render its own. Contextual options live in the side nav
                // or action ribbons, never in a second dock.
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoardArea() {
    if (!_ready) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child:
              CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
      );
    }
    final board = _store.activeBoard;
    if (board == null) {
      return Center(
        child: Text('No boards yet.',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.4))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: SGToolbar(
            title: board.title,
            onRenameTitle: (t) => _store.renameBoard(board.id, t),
            onSearch: (q) => setState(() => _searchQuery = q),
            onBack: widget.onClose,
            onNewBoard: () => setState(() => _drawerKind = ComponentKind.board),
            onDeleteBoard: () => _store.deleteBoard(board.id),
            canDeleteBoard: _store.boards.length > 1,
            onToggleSelectMode: _toggleSelectMode,
            selectMode: _selectMode,
            onShowStats: () => setState(() => _statsOpen = true),
            store: _store,
            board: board,
          ),
        ),
        // Spec §13: search results overlay — color dot + metadata, tap to
        // jump to the card in place (no modal).
        if (_searchQuery.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: _buildSearchResults(board),
          ),
        Expanded(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                child: SmartBoardView(
                  board: board,
                  template: _store.template(board.templateId),
                  store: _store,
                  searchQuery: _searchQuery,
                  cardFilter: _cardFilter,
                  selectMode: _selectMode,
                  selectedIds: _selectedIds,
                  onToggleSelect: _toggleSelect,
                  highlightCardId: _highlightCardId,
                ),
              ),
              // Spec §12: floating bulk-action bar + inline bulk editor.
              if (_selectMode && _bulkEditOpen)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 132,
                  child: _BulkEditPanel(
                    count: _selectedIds.length,
                    columns: _columnLabels(_store.activeBoard!),
                    onApply: _applyBulkEdit,
                    onClose: _toggleBulkEdit,
                  ),
                ),
              if (_selectMode)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 78,
                  child: Center(child: _buildBulkBar()),
                ),
              // Spec §14: statistics as a floating panel (not a modal).
              if (_statsOpen)
                Positioned(
                  right: 8,
                  top: 4,
                  child: _buildStatsPanel(board),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- search results (spec §13) ----------------

  List<SmartCard> _searchHits(SmartBoard board) {
    final q = _searchQuery.trim().toLowerCase();
    return _store
        .boardCards(board.id)
        .where((c) =>
            c.title.toLowerCase().contains(q) ||
            c.values.values
                .any((v) => (v?.toString() ?? '').toLowerCase().contains(q)))
        .take(8)
        .toList();
  }

  Widget _buildSearchResults(SmartBoard board) {
    final hits = _searchHits(board);
    return GlassPanel(
      radius: 16,
      blur: 30,
      fill: SGGlass.paleFill,
      border: SGGlass.edgeStrokeSoft,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: hits.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text('No cards match "$_searchQuery"',
                  style: AppFonts.instrumentSans(
                      fontSize: 12.5, color: SGGlass.ink3)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in hits)
                  GestureDetector(
                    onTap: () => _jumpToCard(c.id),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _tintFor(c),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.instrumentSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: SGGlass.ink)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${c.status} · ${c.priority}',
                            style: AppFonts.instrumentSans(
                                fontSize: 11, color: SGGlass.ink3),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  // ---------------- bulk actions (spec §12) ----------------

  Widget _buildBulkBar() {
    final n = _selectedIds.length;
    if (_bulkDeleteConfirm && n > 0) {
      return GlassPanel(
        radius: 30,
        blur: 30,
        fill: SGGlass.darkFill,
        border: SGGlass.edgeStroke,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Delete $n card${n == 1 ? '' : 's'}?',
                style: AppFonts.instrumentSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
            _bulkBtn(Icons.close_rounded, 'Keep',
                () => setState(() => _bulkDeleteConfirm = false)),
            _bulkBtn(Icons.delete_forever_rounded, 'Delete', _onBulkDeleteTap,
                destructive: true),
          ],
        ),
      );
    }
    return GlassPanel(
      radius: 30,
      blur: 30,
      fill: SGGlass.darkFill,
      border: SGGlass.edgeStroke,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              n == 0 ? 'Tap cards to select' : '$n selected',
              style: AppFonts.instrumentSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
          if (n > 0) ...[
            _bulkBtn(Icons.edit_outlined, 'Edit', _toggleBulkEdit),
            _bulkBtn(Icons.delete_outline_rounded, 'Delete', _onBulkDeleteTap,
                destructive: true),
          ],
          _bulkBtn(Icons.close_rounded, 'Cancel', _toggleSelectMode),
        ],
      ),
    );
  }

  Widget _bulkBtn(IconData icon, String label, VoidCallback onTap,
      {bool destructive = false}) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: destructive
                ? SGGlass.sysRed.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 5),
              Text(label,
                  style: AppFonts.instrumentSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _columnLabels(SmartBoard board) {
    final raw = _store.template(board.templateId)?.settings['columns'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    return const ['To Do', 'In Progress', 'Done'];
  }

  void _toggleBulkEdit() {
    setState(() => _bulkEditOpen = !_bulkEditOpen);
  }

  void _applyBulkEdit({String? p, bool? u, String? s}) {
    final ids = _selectedIds.toList();
    _store.bulkSet(ids, priority: p, urgent: u, status: s);
    setState(() {
      _selectedIds.clear();
      _selectMode = false;
      _bulkEditOpen = false;
    });
  }

  /// First tap arms the inline delete confirmation in the bulk bar;
  /// the second tap executes.
  void _onBulkDeleteTap() {
    if (!_bulkDeleteConfirm) {
      setState(() => _bulkDeleteConfirm = true);
      return;
    }
    final n = _selectedIds.length;
    final ids = _selectedIds.toList();
    _store.bulkDelete(ids);
    setState(() {
      _selectedIds.clear();
      _selectMode = false;
      _bulkDeleteConfirm = false;
      _bulkEditOpen = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $n card${n == 1 ? '' : 's'}')),
      );
    }
  }

  // ---------------- statistics (spec §14) ----------------

  Widget _buildStatsPanel(SmartBoard board) {
    final stats = _store.boardStats(board.id);
    final byStatus = stats['byStatus'] as Map<String, int>;
    return GlassPanel(
      radius: 18,
      blur: 34,
      fill: SGGlass.paleFill,
      border: SGGlass.edgeStrokeSoft,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: SizedBox(
        width: 240,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Board statistics',
                      style: AppFonts.instrumentSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: SGGlass.ink)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _statsOpen = false),
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: SGGlass.ink3),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _statRow('Total cards', '${stats['total']}'),
            _statRow('Urgent', '${stats['urgent']}'),
            _statRow('Overdue', '${stats['overdue']}'),
            _statRow('Due soon', '${stats['dueSoon']}'),
            _statRow('Completed', '${stats['completedPct']}%'),
            const SizedBox(height: 6),
            for (final e in byStatus.entries) _statRow(e.key, '${e.value}'),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style:
                    AppFonts.instrumentSans(fontSize: 12, color: SGGlass.ink2)),
          ),
          Text(value,
              style: AppFonts.instrumentSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SGGlass.ink)),
        ],
      ),
    );
  }
}

/// Bottom sheet for bulk-editing the selected cards (spec §12): applies one
/// attribute change to every selected card.
class _BulkEditPanel extends StatefulWidget {
  final int count;
  final List<String> columns;
  final void Function({String? p, bool? u, String? s}) onApply;
  final VoidCallback onClose;

  const _BulkEditPanel(
      {required this.count,
      required this.columns,
      required this.onApply,
      required this.onClose});

  @override
  State<_BulkEditPanel> createState() => _BulkEditPanelState();
}

class _BulkEditPanelState extends State<_BulkEditPanel> {
  String? _priority;
  bool? _urgent;
  String? _status;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 24,
      blur: 40,
      fill: SGGlass.paleFill,
      border: SGGlass.edgeStrokeSoft,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit ${widget.count} card${widget.count == 1 ? '' : 's'}',
              style: AppFonts.instrumentSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: SGGlass.ink)),
          const SizedBox(height: 12),
          Text('Priority',
              style: AppFonts.instrumentSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SGGlass.ink2)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final p in const ['P0', 'P1', 'P2', 'P3'])
                ChoiceChip(
                  label: Text(p, style: AppFonts.instrumentSans(fontSize: 12)),
                  selected: _priority == p,
                  onSelected: (v) => setState(() => _priority = v ? p : null),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Urgent',
                    style: AppFonts.instrumentSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SGGlass.ink2)),
              ),
              ChoiceChip(
                label: Text('Set urgent',
                    style: AppFonts.instrumentSans(fontSize: 12)),
                selected: _urgent == true,
                onSelected: (v) => setState(() => _urgent = v ? true : null),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Clear urgent',
                    style: AppFonts.instrumentSans(fontSize: 12)),
                selected: _urgent == false,
                onSelected: (v) => setState(() => _urgent = v ? false : null),
              ),
            ],
          ),
          if (widget.columns.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Move to column',
                style: AppFonts.instrumentSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SGGlass.ink2)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final c in widget.columns)
                  ChoiceChip(
                    label:
                        Text(c, style: AppFonts.instrumentSans(fontSize: 12)),
                    selected: _status == c,
                    onSelected: (v) => setState(() => _status = v ? c : null),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onClose,
                  child: Text('Cancel',
                      style: AppFonts.instrumentSans(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    widget.onApply(p: _priority, u: _urgent, s: _status);
                  },
                  child: Text('Apply',
                      style: AppFonts.instrumentSans(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
