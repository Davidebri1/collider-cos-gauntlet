import 'package:flutter/material.dart';
import 'package:collider_flutter/core/theme/app_fonts.dart';
import '../models/smartgen_models.dart';
import '../state/smartgen_store.dart';
import '../theme/smartgen_glass.dart';
import 'sg_menu.dart';

/// The Smart Gen top toolbar — a literal port of the Figma toolbar
/// (Frame 5): pale frosted bar, back chevron in a tinted circle, semibold
/// title, overflow pill, background blur 34, radius 24.
///
/// The title renames inline (tap-to-edit, no modal). Search expands inline
/// inside the bar. The overflow pill opens board actions in a glass menu.
class SGToolbar extends StatefulWidget {
  final String title;
  final ValueChanged<String> onRenameTitle;
  final ValueChanged<String> onSearch;
  final VoidCallback onBack;
  final VoidCallback onNewBoard;
  final VoidCallback onDeleteBoard;
  final bool canDeleteBoard;
  // Spec §12: multi-select mode toggle.
  final VoidCallback onToggleSelectMode;
  final bool selectMode;
  // Spec §14: statistics panel.
  final VoidCallback onShowStats;
  // Spec §11: board behaviors are managed inline here (no settings panel).
  final SmartGenStore? store;
  final SmartBoard? board;

  const SGToolbar({
    super.key,
    required this.title,
    required this.onRenameTitle,
    required this.onSearch,
    required this.onBack,
    required this.onNewBoard,
    required this.onDeleteBoard,
    required this.canDeleteBoard,
    required this.onToggleSelectMode,
    required this.selectMode,
    required this.onShowStats,
    this.store,
    this.board,
  });

  @override
  State<SGToolbar> createState() => _SGToolbarState();
}

class _SGToolbarState extends State<SGToolbar> {
  bool _editingTitle = false;
  bool _searchOpen = false;
  late final TextEditingController _titleCtrl;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.title);
  }

  @override
  void didUpdateWidget(covariant SGToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title && !_editingTitle) {
      _titleCtrl.text = widget.title;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _commitTitle() {
    final t = _titleCtrl.text.trim();
    if (t.isNotEmpty && t != widget.title) widget.onRenameTitle(t);
    setState(() => _editingTitle = false);
  }

  @override
  Widget build(BuildContext context) {
    // Narrow (phone) viewports: the board title must keep its space — the
    // frame's toolbar is back + title + search + overflow only. Spec
    // actions (§12 multi-select, §14 statistics) live in the overflow menu.
    final narrow = MediaQuery.of(context).size.width < 600;
    return GlassPanel(
      radius: SGGlass.rToolbar,
      blur: SGGlass.blurBar,
      fill: SGGlass.paleFill,
      border: SGGlass.edgeStroke,
      shadows: SGGlass.barShadow,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            // Back chevron in the tinted circle (measured: 42px, pale blue).
            Tooltip(
              message: 'Back',
              child: GestureDetector(
                onTap: widget.onBack,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9E1F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.chevron_left_rounded,
                      size: 24, color: SGGlass.ink2),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Title — tap to rename inline.
            Expanded(
              child: _editingTitle
                  ? TextField(
                      controller: _titleCtrl,
                      autofocus: true,
                      style: AppFonts.instrumentSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: SGGlass.ink),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _commitTitle(),
                      onTapOutside: (_) => _commitTitle(),
                    )
                  : GestureDetector(
                      onTap: () => setState(() => _editingTitle = true),
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.instrumentSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: SGGlass.ink),
                      ),
                    ),
            ),
            // Inline expanding search.
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: _searchOpen ? (narrow ? 120 : 150) : 40,
              height: 40,
              child: _searchOpen
                  ? Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFE0E0E0), width: 1),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        style: AppFonts.instrumentSans(
                            fontSize: 13, color: SGGlass.ink),
                        decoration: InputDecoration(
                          hintText: 'Search cards',
                          hintStyle: AppFonts.instrumentSans(
                              fontSize: 13, color: SGGlass.ink3),
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 16, color: SGGlass.ink3),
                          suffixIcon: GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              widget.onSearch('');
                              setState(() => _searchOpen = false);
                            },
                            child: const Icon(Icons.close_rounded,
                                size: 15, color: SGGlass.ink3),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: widget.onSearch,
                      ),
                    )
                  : Tooltip(
                      message: 'Search cards',
                      child: GestureDetector(
                        onTap: () => setState(() => _searchOpen = true),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFFE0E0E0), width: 1),
                          ),
                          child: const Icon(Icons.search_rounded,
                              size: 18, color: SGGlass.ink2),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            // Overflow pill (measured: white fill, gray stroke, cr 30).
            // Also holds the spec actions (§12 multi-select, §14
            // statistics) so the title keeps its space on narrow screens.
            Tooltip(
              message: 'Board actions',
              child: GestureDetector(
                onTapDown: (d) => _showBoardMenu(d.globalPosition),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: const Color(0xFFE0E0E0), width: 1),
                  ),
                  child: const Icon(Icons.more_horiz_rounded,
                      size: 18, color: SGGlass.ink2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBoardMenu(Offset at) {
    SGMenu.show(
      context,
      at: at,
      items: [
        SGMenuItem(
          icon: Icons.edit_outlined,
          label: 'Rename board',
          onTap: () => setState(() => _editingTitle = true),
        ),
        SGMenuItem(
          icon: Icons.add_rounded,
          label: 'New board',
          onTap: widget.onNewBoard,
        ),
        if (widget.store != null && widget.board != null)
          SGMenuItem(
            icon: Icons.tune_rounded,
            label: 'Board behaviors…',
            onTap: () => _showBehaviors(at),
          ),
        SGMenuItem(
          icon: Icons.checklist_rounded,
          label:
              widget.selectMode ? 'Exit multi-select' : 'Multi-select cards',
          onTap: widget.onToggleSelectMode,
        ),
        SGMenuItem(
          icon: Icons.bar_chart_rounded,
          label: 'Board statistics',
          onTap: widget.onShowStats,
        ),
        if (widget.canDeleteBoard)
          SGMenuItem(
            icon: Icons.delete_outline_rounded,
            label: 'Delete board',
            destructive: true,
            onTap: widget.onDeleteBoard,
          ),
      ],
    );
  }

  /// Spec §11 board behaviors, managed inline on the board itself —
  /// there is no settings panel by design.
  void _showBehaviors(Offset at) {
    final store = widget.store!;
    final board = widget.board!;
    const defs = [
      (
        'inheritColumnStatus',
        'Inherit column status',
        'Cards with the inherit flag update status on drop.'
      ),
      (
        'urgentAutoCalendar',
        'Urgent → auto calendar',
        'Urgent cards without due dates appear on today.'
      ),
      ('autoSort', 'Auto sort', 'Keep columns sorted by priority.'),
      (
        'autoFilterComplete',
        'Auto filter complete',
        'Done cards collapse out of the Active filter.'
      ),
      ('autoArrange', 'Auto arrange', 'Tidy freeform cards into a grid.'),
    ];
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        final screen = MediaQuery.of(ctx).size;
        const width = 300.0;
        var dx = (at.dx - width + 24).clamp(8.0, screen.width - width - 8.0);
        var dy = (at.dy + 8).clamp(8.0, screen.height - 320.0);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => entry.remove(),
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: dx,
              top: dy,
              child: Material(
                color: Colors.transparent,
                child: GlassPanel.menu(
                  child: SizedBox(
                    width: width,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                          child: Text('Board behaviors',
                              style: AppFonts.instrumentSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                        for (final (key, label, sub) in defs)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(label,
                                            style: AppFonts.instrumentSans(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white)),
                                        Text(sub,
                                            style: AppFonts.instrumentSans(
                                                fontSize: 10.5,
                                                color: Colors.white54)),
                                      ],
                                    ),
                                  ),
                                ),
                                Switch.adaptive(
                                  value: board.behavior(key),
                                  activeThumbColor: const Color(0xFF64FFDA),
                                  onChanged: (v) {
                                    store.setBoardBehavior(board.id, key, v);
                                    entry.remove();
                                    _showBehaviors(at);
                                  },
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(entry);
  }
}
