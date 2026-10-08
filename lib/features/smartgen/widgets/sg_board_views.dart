import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:collider_flutter/core/theme/app_fonts.dart';
import '../models/smartgen_models.dart';
import '../state/smartgen_store.dart';
import '../theme/smartgen_glass.dart';
import 'sg_card_face.dart';
import 'sg_menu.dart';
import 'sg_action_ribbon.dart';
import 'smart_card_widget.dart';

// ===========================================================================
// Shared infrastructure for the non-kanban board views (spec §6).
//
// Every view honors the same contracts:
// - [selectMode]/[selectedIds]/[onToggleSelect]: multi-select (spec §12).
// - [highlightCardId]: search jump-to-card pulse (spec §13).
// - search + All/Active/Urgent filtering is render-only (spec §13).
// - All management (add/rename/delete/reorder/…) is inline — no settings
//   screens, no edit modals (master spec inline-editing invariant).
// ===========================================================================

/// Selection/highlight wrapper shared by all board views: in select mode a
/// tap toggles selection (blue outline + check badge); [highlighted] draws
/// the search jump-to-card pulse.
class SGSelectable extends StatelessWidget {
  final Widget child;
  final bool selectMode;
  final bool selected;
  final bool highlighted;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onTap;

  const SGSelectable({
    super.key,
    required this.child,
    this.selectMode = false,
    this.selected = false,
    this.highlighted = false,
    this.onToggleSelect,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget w = highlighted ? _PulseBorder(child: child) : child;
    if (!selectMode && onTap == null) return w;
    return GestureDetector(
      onTap: selectMode ? onToggleSelect : onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          if (selectMode) AbsorbPointer(absorbing: true, child: w) else w,
          if (selectMode)
            Positioned.fill(
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
        ],
      ),
    );
  }
}

class _PulseBorder extends StatefulWidget {
  final Widget child;
  const _PulseBorder({required this.child});

  @override
  State<_PulseBorder> createState() => _PulseBorderState();
}

class _PulseBorderState extends State<_PulseBorder>
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
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF0A84FF)
                .withValues(alpha: 0.45 + 0.55 * _ctrl.value),
            width: 2.5,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Inline card inspector: the full card editor rendered in-surface, replacing
/// the old bottom-sheet editor. Views toggle it via [SGViewFilter.toggleExpanded].
class SGCardInspector extends StatelessWidget {
  final SmartGenStore store;
  final SmartCard card;
  final VoidCallback onCollapse;
  final double? maxHeight;
  const SGCardInspector(
      {super.key,
      required this.store,
      required this.card,
      required this.onCollapse,
      this.maxHeight});

  @override
  Widget build(BuildContext context) {
    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(card.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.instrumentSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SGGlass.ink)),
            ),
            GlassPressable(
              onTap: onCollapse,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.expand_less_rounded,
                    size: 16, color: SGGlass.ink3),
              ),
            ),
          ],
        ),
        SmartCardWidget(
          card: card,
          template: store.template(card.templateId),
          store: store,
          kanbanMode: false,
        ),
      ],
    );
    if (maxHeight != null) {
      body = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight!),
        child: SingleChildScrollView(child: body),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: GlassPanel(radius: 20, child: body),
    );
  }
}

/// Mixin-style helpers shared by the views below.
mixin SGViewFilter<T extends StatefulWidget> on State<T> {
  SmartGenStore get store;
  SmartBoard get board;
  String get searchQuery;
  String get cardFilter;
  bool get selectMode;
  Set<String> get selectedIds;
  ValueChanged<String>? get onToggleSelect;
  String? get highlightCardId;

  bool matches(SmartCard c) {
    final q = searchQuery.trim().toLowerCase();
    final hit = q.isEmpty ||
        c.title.toLowerCase().contains(q) ||
        c.values.values
            .any((v) => (v?.toString() ?? '').toLowerCase().contains(q));
    if (!hit) return false;
    switch (cardFilter) {
      case 'active':
        return c.status.toLowerCase() != 'done';
      case 'urgent':
        return c.urgent;
      default:
        return true;
    }
  }

  List<SmartCard> get visibleCards =>
      store.boardCards(board.id).where(matches).toList();

  ComponentTemplate? get defaultCardTemplate {
    final ts = store.templatesOf(ComponentKind.card);
    if (ts.isEmpty) return null;
    return ts.firstWhere((t) => t.typeKey == 'task', orElse: () => ts.first);
  }

  /// Creates a card on this board, or null (with a refusal notice) at the
  /// 999-card cap.
  SmartCard? addCard({
    String? title,
    String status = 'to_do',
    double x = 0,
    double y = 0,
    DateTime? dueAt,
  }) {
    final tpl = defaultCardTemplate;
    if (tpl == null) return null;
    final c = store.instantiateCard(tpl.id,
        boardId: board.id, status: status, title: title, x: x, y: y);
    if (c == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card limit reached (999).')),
      );
      return null;
    }
    if (c != null && dueAt != null) {
      c.dueAt = dueAt;
      store.updateCard(c);
    }
    return c;
  }

  /// Inline expansion state: the card whose full editor is shown in-surface.
  String? _expandedCardId;
  bool isExpanded(SmartCard c) => _expandedCardId == c.id;
  void toggleExpanded(SmartCard c) {
    setState(() => _expandedCardId = _expandedCardId == c.id ? null : c.id);
  }

  void collapseExpanded() => setState(() => _expandedCardId = null);

  /// The full card editor for [c], or a zero-size box when [c] is not expanded.
  Widget expandedInspector(SmartCard c) {
    if (!isExpanded(c)) return const SizedBox.shrink();
    return SGCardInspector(store: store, card: c, onCollapse: collapseExpanded);
  }

  /// Inspector for the currently expanded card, for placement below a view
  /// header (grid views where in-cell expansion would break the layout).
  Widget headerInspector() {
    final id = _expandedCardId;
    if (id == null) return const SizedBox.shrink();
    final c = store.card(id);
    if (c == null) {
      _expandedCardId = null;
      return const SizedBox.shrink();
    }
    return SGCardInspector(store: store, card: c, onCollapse: collapseExpanded);
  }

  Widget selectable(SmartCard card, Widget child, {VoidCallback? onTap}) {
    return SGSelectable(
      selectMode: selectMode,
      selected: selectedIds.contains(card.id),
      highlighted: highlightCardId == card.id,
      onToggleSelect:
          onToggleSelect == null ? null : () => onToggleSelect!(card.id),
      onTap: onTap ?? () => toggleExpanded(card),
      child: child,
    );
  }

  /// Small overflow menu for a card tile: edit, duplicate, delete.
  void cardMenu(BuildContext context, Offset at, SmartCard card,
      {List<SGMenuItem> extra = const []}) {
    SGMenu.show(
      context,
      at: at,
      items: [
        SGMenuItem(
          icon: Icons.open_in_full_rounded,
          label: 'Open',
          onTap: () => toggleExpanded(card),
        ),
        ...extra,
        SGMenuItem(
          icon: Icons.copy_rounded,
          label: 'Duplicate',
          onTap: () => store.duplicateCard(card.id),
        ),
        SGMenuItem(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          destructive: true,
          onTap: () => store.deleteCard(card.id),
        ),
      ],
    );
  }
}

/// Decodes a data-URL attachment into bytes for image tiles.
Uint8List? _dataUrlBytes(String dataUrl) {
  try {
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    return base64Decode(dataUrl.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

CardAttachment? _firstImage(SmartCard card) {
  for (final a in card.attachments) {
    if (a.isImage && a.dataUrl.isNotEmpty) return a;
  }
  return null;
}

/// Picks image files and attaches them to [card] (used by album/vision).
Future<void> pickImagesInto(
    BuildContext context, SmartGenStore store, SmartCard card) async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: true,
    withData: true,
  );
  if (res == null) return;
  for (final f in res.files) {
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) continue;
    if (bytes.length > 2 * 1024 * 1024) continue; // persistence guard
    final mime = f.extension == 'png'
        ? 'image/png'
        : (f.extension == 'gif' ? 'image/gif' : 'image/jpeg');
    store.addAttachment(
      card.id,
      CardAttachment(
        name: f.name,
        mime: mime,
        dataUrl: 'data:$mime;base64,${base64Encode(bytes)}',
        sizeBytes: bytes.length,
      ),
    );
  }
}

/// Template-derived accent tint (same palette as kanban card icons).
Color viewTintFor(SmartCard card) {
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

String _fmtDay(DateTime d) {
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${m[d.month - 1]} ${d.day}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ===========================================================================
// Calendar (spec §6): month grid. Cards with due dates land on their day;
// with the "Urgent → auto calendar" behavior on, urgent cards without due
// dates appear on today. Tapping a day opens its cards + an inline composer.
// ===========================================================================

class SGCalendarView extends StatefulWidget {
  final SmartBoard board;
  final SmartGenStore store;
  final String searchQuery;
  final String cardFilter;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggleSelect;
  final String? highlightCardId;

  const SGCalendarView({
    super.key,
    required this.board,
    required this.store,
    this.searchQuery = '',
    this.cardFilter = 'all',
    this.selectMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.highlightCardId,
  });

  @override
  State<SGCalendarView> createState() => _SGCalendarViewState();
}

class _SGCalendarViewState extends State<SGCalendarView> with SGViewFilter {
  DateTime? _selectedDay;
  @override
  SmartGenStore get store => widget.store;
  @override
  SmartBoard get board => widget.board;
  @override
  String get searchQuery => widget.searchQuery;
  @override
  String get cardFilter => widget.cardFilter;
  @override
  bool get selectMode => widget.selectMode;
  @override
  Set<String> get selectedIds => widget.selectedIds;
  @override
  ValueChanged<String>? get onToggleSelect => widget.onToggleSelect;
  @override
  String? get highlightCardId => widget.highlightCardId;

  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  Map<DateTime, List<SmartCard>> _byDay() {
    final map = <DateTime, List<SmartCard>>{};
    final autoToday = board.behavior('urgentAutoCalendar');
    final today = DateTime.now();
    for (final c in visibleCards) {
      DateTime? d = c.dueAt;
      if (d == null && autoToday && c.urgent) d = today;
      if (d == null) continue;
      final key = DateTime(d.year, d.month, d.day);
      (map[key] ??= []).add(c);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final byDay = _byDay();
    final first = DateTime(_month.year, _month.month, 1);
    // Monday-first grid.
    final lead = (first.weekday - 1) % 7;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final today = DateTime.now();
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              _navBtn(Icons.chevron_left_rounded, () {
                setState(
                    () => _month = DateTime(_month.year, _month.month - 1));
              }),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final n = DateTime.now();
                    setState(() => _month = DateTime(n.year, n.month));
                  },
                  child: Text(
                    '${months[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: AppFonts.instrumentSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: SGGlass.ink),
                  ),
                ),
              ),
              _navBtn(Icons.chevron_right_rounded, () {
                setState(
                    () => _month = DateTime(_month.year, _month.month + 1));
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final n in names)
                Expanded(
                  child: Center(
                    child: Text(n,
                        style: AppFonts.instrumentSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: SGGlass.ink3)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.72,
            ),
            itemCount: lead + daysInMonth,
            itemBuilder: (context, i) {
              if (i < lead) return const SizedBox.shrink();
              final day = i - lead + 1;
              final date = DateTime(_month.year, _month.month, day);
              final cards = byDay[date] ?? const [];
              final isToday = _sameDay(date, today);
              return GestureDetector(
                onTap: () => setState(() => _selectedDay =
                    (_selectedDay != null && _sameDay(_selectedDay!, date))
                        ? null
                        : date),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  decoration: BoxDecoration(
                    color: isToday
                        ? const Color(0xFF0A84FF).withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isToday
                          ? const Color(0xFF0A84FF).withValues(alpha: 0.5)
                          : const Color(0x14000000),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$day',
                          style: AppFonts.instrumentSans(
                              fontSize: 11,
                              fontWeight:
                                  isToday ? FontWeight.w800 : FontWeight.w600,
                              color: isToday
                                  ? const Color(0xFF0A84FF)
                                  : SGGlass.ink2)),
                      const SizedBox(height: 2),
                      for (var k = 0; k < cards.length.clamp(0, 3); k++)
                        Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          height: 6,
                          decoration: BoxDecoration(
                            color: cards[k].urgent
                                ? SGGlass.sysRed
                                : viewTintFor(cards[k]),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      if (cards.length > 3)
                        Text('+${cards.length - 3}',
                            style: AppFonts.instrumentSans(
                                fontSize: 8, color: SGGlass.ink3)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _dayPanel(),
      ],
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return Tooltip(
      message: 'Change month',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Icon(icon, size: 20, color: SGGlass.ink2),
        ),
      ),
    );
  }

  /// Inline day panel: the selected day's cards plus a dated composer,
  /// rendered in-surface below the month grid — never a modal.
  Widget _dayPanel() {
    final date = _selectedDay;
    if (date == null) return const SizedBox.shrink();
    final cards = _byDay()[DateTime(date.year, date.month, date.day)] ?? [];
    final composerCtrl = TextEditingController();
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 90),
      child: GlassPanel(
        radius: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_fmtDay(date),
                      style: AppFonts.instrumentSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: SGGlass.ink)),
                ),
                GlassPressable(
                  onTap: () => setState(() => _selectedDay = null),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.expand_less_rounded,
                        size: 16, color: SGGlass.ink3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final c in cards)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            selectable(c, _DayRow(card: c, store: store)),
                            expandedInspector(c),
                          ],
                        ),
                      ),
                    if (cards.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('No cards on this day.',
                            style: AppFonts.instrumentSans(
                                fontSize: 12.5, color: SGGlass.ink3)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: composerCtrl,
              style: AppFonts.instrumentSans(fontSize: 13, color: SGGlass.ink),
              decoration: InputDecoration(
                hintText: 'Add card on ${_fmtDay(date)}…',
                hintStyle:
                    AppFonts.instrumentSans(fontSize: 13, color: SGGlass.ink3),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (t) {
                if (t.trim().isEmpty) return;
                final nc = addCard(
                    title: t.trim(),
                    dueAt: DateTime(date.year, date.month, date.day, 9));
                if (nc != null) {
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final SmartCard card;
  final SmartGenStore store;
  const _DayRow({required this.card, required this.store});

  @override
  Widget build(BuildContext context) {
    return GlassPanel.card(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: viewTintFor(card), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.instrumentSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SGGlass.ink)),
                if (card.dueAt != null)
                  Text(
                    '${card.dueAt!.hour.toString().padLeft(2, '0')}:${card.dueAt!.minute.toString().padLeft(2, '0')}',
                    style: AppFonts.instrumentSans(
                        fontSize: 11, color: SGGlass.ink3),
                  ),
              ],
            ),
          ),
          if (card.urgent)
            const Icon(Icons.flag_rounded, size: 15, color: SGGlass.sysRed),
        ],
      ),
    );
  }
}

// ===========================================================================
// Notebook (spec §6): each card is a page. Page list with word counts;
// the open page edits title + body inline. Pages add/rename/delete/reorder.
// ===========================================================================

class SGNotebookView extends StatefulWidget {
  final SmartBoard board;
  final SmartGenStore store;
  final String searchQuery;
  final String cardFilter;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggleSelect;
  final String? highlightCardId;

  const SGNotebookView({
    super.key,
    required this.board,
    required this.store,
    this.searchQuery = '',
    this.cardFilter = 'all',
    this.selectMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.highlightCardId,
  });

  @override
  State<SGNotebookView> createState() => _SGNotebookViewState();
}

class _SGNotebookViewState extends State<SGNotebookView> with SGViewFilter {
  @override
  SmartGenStore get store => widget.store;
  @override
  SmartBoard get board => widget.board;
  @override
  String get searchQuery => widget.searchQuery;
  @override
  String get cardFilter => widget.cardFilter;
  @override
  bool get selectMode => widget.selectMode;
  @override
  Set<String> get selectedIds => widget.selectedIds;
  @override
  ValueChanged<String>? get onToggleSelect => widget.onToggleSelect;
  @override
  String? get highlightCardId => widget.highlightCardId;

  String? _openPageId;

  String _bodyOf(SmartCard c) => (c.values['body']?.toString() ?? '');

  int _wordsOf(SmartCard c) {
    final text = '${c.title} ${_bodyOf(c)}'.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  @override
  Widget build(BuildContext context) {
    final pages = visibleCards;
    final narrow = MediaQuery.of(context).size.width < 600;
    if (_openPageId != null) {
      final page = store.card(_openPageId!);
      if (page == null) {
        _openPageId = null;
      } else {
        return _PageEditor(
          card: page,
          store: store,
          wordCount: _wordsOf(page),
          onBack: narrow ? () => setState(() => _openPageId = null) : null,
          onChangedBody: (v) {
            page.values['body'] = v;
            store.updateCard(page);
          },
          onRenamed: (t) {
            page.title = t;
            store.updateCard(page);
          },
        );
      }
    }
    if (narrow) return _pageList(pages, embedded: false);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 240, child: _pageList(pages, embedded: true)),
        Expanded(
          child: _openPageId == null
              ? Center(
                  child: Text('Select a page',
                      style: AppFonts.instrumentSans(
                          fontSize: 13, color: SGGlass.ink3)),
                )
              : Builder(builder: (context) {
                  final page = store.card(_openPageId!);
                  if (page == null) return const SizedBox.shrink();
                  return _PageEditor(
                    card: page,
                    store: store,
                    wordCount: _wordsOf(page),
                    onChangedBody: (v) {
                      page.values['body'] = v;
                      store.updateCard(page);
                    },
                    onRenamed: (t) {
                      page.title = t;
                      store.updateCard(page);
                    },
                  );
                }),
        ),
      ],
    );
  }

  Widget _pageList(List<SmartCard> pages, {required bool embedded}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Text('Pages · ${pages.length}',
                    style: AppFonts.instrumentSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SGGlass.ink)),
              ),
              Tooltip(
                message: 'Add page',
                child: GestureDetector(
                  onTap: () {
                    final c = addCard(title: 'Untitled page');
                    if (c != null) {
                      setState(() => _openPageId = c.id);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: SGGlass.ink,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 15, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
            itemCount: pages.length,
            itemBuilder: (context, i) {
              final p = pages[i];
              final selected = _openPageId == p.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: selectable(
                  p,
                  GestureDetector(
                    onTap: selectMode
                        ? null
                        : () => setState(() => _openPageId = p.id),
                    onLongPress: () {},
                    onSecondaryTapDown: (d) =>
                        _pageMenu(d.globalPosition, pages, i),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF0A84FF).withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF0A84FF).withValues(alpha: 0.45)
                              : const Color(0x14000000),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.instrumentSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: SGGlass.ink)),
                                const SizedBox(height: 2),
                                Text('${_wordsOf(p)} words',
                                    style: AppFonts.instrumentSans(
                                        fontSize: 11, color: SGGlass.ink3)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTapDown: (d) =>
                                _pageMenu(d.globalPosition, pages, i),
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.more_horiz_rounded,
                                  size: 16, color: SGGlass.ink3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  onTap: null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _pageMenu(Offset at, List<SmartCard> pages, int i) {
    final p = pages[i];
    cardMenu(context, at, p, extra: [
      if (i > 0)
        SGMenuItem(
          icon: Icons.arrow_upward_rounded,
          label: 'Move up',
          onTap: () => store.reorderBoardCard(board.id, p.id, i - 1),
        ),
      if (i < pages.length - 1)
        SGMenuItem(
          icon: Icons.arrow_downward_rounded,
          label: 'Move down',
          onTap: () => store.reorderBoardCard(board.id, p.id, i + 1),
        ),
    ]);
  }
}

class _PageEditor extends StatefulWidget {
  final SmartCard card;
  final SmartGenStore store;
  final int wordCount;
  final VoidCallback? onBack;
  final ValueChanged<String> onChangedBody;
  final ValueChanged<String> onRenamed;

  const _PageEditor({
    required this.card,
    required this.store,
    required this.wordCount,
    required this.onChangedBody,
    required this.onRenamed,
    this.onBack,
  });

  @override
  State<_PageEditor> createState() => _PageEditorState();
}

class _PageEditorState extends State<_PageEditor> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.card.title);
    _bodyCtrl = TextEditingController(
        text: widget.card.values['body']?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _PageEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _titleCtrl.text = widget.card.title;
      _bodyCtrl.text = widget.card.values['body']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _queueSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.onChangedBody(_bodyCtrl.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              if (widget.onBack != null)
                GestureDetector(
                  onTap: widget.onBack,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.chevron_left_rounded,
                        size: 22, color: SGGlass.ink2),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: _titleCtrl,
                  style: AppFonts.instrumentSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: SGGlass.ink),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Page title',
                  ),
                  onSubmitted: (t) {
                    if (t.trim().isNotEmpty) widget.onRenamed(t.trim());
                  },
                  onTapOutside: (_) {
                    final t = _titleCtrl.text.trim();
                    if (t.isNotEmpty && t != widget.card.title) {
                      widget.onRenamed(t);
                    }
                  },
                ),
              ),
              Text('${widget.wordCount} words',
                  style: AppFonts.instrumentSans(
                      fontSize: 11, color: SGGlass.ink3)),
            ],
          ),
        ),
        const Divider(height: 16, indent: 12, endIndent: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
            child: TextField(
              controller: _bodyCtrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: AppFonts.instrumentSans(
                  fontSize: 14, height: 1.5, color: SGGlass.ink),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Start writing…',
                hintStyle:
                    AppFonts.instrumentSans(fontSize: 14, color: SGGlass.ink3),
              ),
              onChanged: (_) => _queueSave(),
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Photo Album (spec §6): grid of photo tiles. Each card contributes its
// image attachments; the caption is the card title, editable inline.
// Tiles add photos, reorder (move left/right), delete.
// ===========================================================================

class SGAlbumView extends StatefulWidget {
  final SmartBoard board;
  final SmartGenStore store;
  final String searchQuery;
  final String cardFilter;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggleSelect;
  final String? highlightCardId;

  const SGAlbumView({
    super.key,
    required this.board,
    required this.store,
    this.searchQuery = '',
    this.cardFilter = 'all',
    this.selectMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.highlightCardId,
  });

  @override
  State<SGAlbumView> createState() => _SGAlbumViewState();
}

class _SGAlbumViewState extends State<SGAlbumView> with SGViewFilter {
  @override
  SmartGenStore get store => widget.store;
  @override
  SmartBoard get board => widget.board;
  @override
  String get searchQuery => widget.searchQuery;
  @override
  String get cardFilter => widget.cardFilter;
  @override
  bool get selectMode => widget.selectMode;
  @override
  Set<String> get selectedIds => widget.selectedIds;
  @override
  ValueChanged<String>? get onToggleSelect => widget.onToggleSelect;
  @override
  String? get highlightCardId => widget.highlightCardId;

  @override
  Widget build(BuildContext context) {
    final cards = visibleCards;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Text('Photos · ${cards.length}',
                    style: AppFonts.instrumentSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SGGlass.ink)),
              ),
              _AlbumBtn(
                icon: Icons.add_photo_alternate_outlined,
                label: 'Add photo',
                onTap: () async {
                  final c = addCard(title: 'Untitled photo');
                  if (c != null && mounted) {
                    await pickImagesInto(context, store, c);
                  }
                },
              ),
              const SizedBox(width: 8),
              _AlbumBtn(
                icon: Icons.note_add_outlined,
                label: 'Add card',
                onTap: () => addCard(title: 'Untitled photo'),
              ),
            ],
          ),
        ),
        headerInspector(),
        Expanded(
          child: cards.isEmpty
              ? Center(
                  child: Text('No photos yet — add one to begin.',
                      style: AppFonts.instrumentSans(
                          fontSize: 13, color: SGGlass.ink3)),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, i) {
                    final c = cards[i];
                    final img = _firstImage(c);
                    final bytes =
                        img == null ? null : _dataUrlBytes(img.dataUrl);
                    return selectable(
                      c,
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x14000000)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(14)),
                                child: bytes != null
                                    ? Image.memory(bytes, fit: BoxFit.cover)
                                    : Container(
                                        color: viewTintFor(c)
                                            .withValues(alpha: 0.14),
                                        child: Icon(
                                          Icons.photo_outlined,
                                          size: 34,
                                          color: viewTintFor(c),
                                        ),
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(c.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppFonts.instrumentSans(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: SGGlass.ink)),
                                  ),
                                  GestureDetector(
                                    onTapDown: (d) => cardMenu(
                                        context, d.globalPosition, c,
                                        extra: [
                                          SGMenuItem(
                                            icon: Icons
                                                .add_photo_alternate_outlined,
                                            label: 'Add photos',
                                            onTap: () => pickImagesInto(
                                                context, store, c),
                                          ),
                                          if (i > 0)
                                            SGMenuItem(
                                              icon: Icons.arrow_back_rounded,
                                              label: 'Move left',
                                              onTap: () =>
                                                  store.reorderBoardCard(
                                                      board.id, c.id, i - 1),
                                            ),
                                          if (i < cards.length - 1)
                                            SGMenuItem(
                                              icon: Icons.arrow_forward_rounded,
                                              label: 'Move right',
                                              onTap: () =>
                                                  store.reorderBoardCard(
                                                      board.id, c.id, i + 1),
                                            ),
                                        ]),
                                    behavior: HitTestBehavior.opaque,
                                    child: const Padding(
                                      padding: EdgeInsets.all(2),
                                      child: Icon(Icons.more_horiz_rounded,
                                          size: 15, color: SGGlass.ink3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AlbumBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AlbumBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: SGGlass.ink2),
              const SizedBox(width: 5),
              Text(label,
                  style: AppFonts.instrumentSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SGGlass.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Storyboard (spec §6): horizontal filmstrip of panels. Panels add/edit
// (caption inline), delete, and reorder by drag; export copies a numbered
// shot list to the clipboard.
// ===========================================================================

class SGStoryboardView extends StatefulWidget {
  final SmartBoard board;
  final SmartGenStore store;
  final String searchQuery;
  final String cardFilter;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggleSelect;
  final String? highlightCardId;

  const SGStoryboardView({
    super.key,
    required this.board,
    required this.store,
    this.searchQuery = '',
    this.cardFilter = 'all',
    this.selectMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.highlightCardId,
  });

  @override
  State<SGStoryboardView> createState() => _SGStoryboardViewState();
}

class _SGStoryboardViewState extends State<SGStoryboardView> with SGViewFilter {
  @override
  SmartGenStore get store => widget.store;
  @override
  SmartBoard get board => widget.board;
  @override
  String get searchQuery => widget.searchQuery;
  @override
  String get cardFilter => widget.cardFilter;
  @override
  bool get selectMode => widget.selectMode;
  @override
  Set<String> get selectedIds => widget.selectedIds;
  @override
  ValueChanged<String>? get onToggleSelect => widget.onToggleSelect;
  @override
  String? get highlightCardId => widget.highlightCardId;

  @override
  Widget build(BuildContext context) {
    final cards = visibleCards;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Text('Panels · ${cards.length}',
                    style: AppFonts.instrumentSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SGGlass.ink)),
              ),
              _AlbumBtn(
                icon: Icons.ios_share_rounded,
                label: 'Export',
                onTap: () => _export(cards),
              ),
              const SizedBox(width: 8),
              _AlbumBtn(
                icon: Icons.add_rounded,
                label: 'Add panel',
                onTap: () => addCard(title: 'Panel ${cards.length + 1}'),
              ),
            ],
          ),
        ),
        headerInspector(),
        Expanded(
          child: cards.isEmpty
              ? Center(
                  child: Text('No panels yet — add one, then drag to reorder.',
                      style: AppFonts.instrumentSans(
                          fontSize: 13, color: SGGlass.ink3)),
                )
              : ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 4, 100, 90),
                  itemCount: cards.length,
                  onReorder: (oldI, newI) {
                    final to = newI > oldI ? newI - 1 : newI;
                    store.reorderBoardCard(board.id, cards[oldI].id, to);
                  },
                  proxyDecorator: (child, _, __) => Material(
                    color: Colors.transparent,
                    child: Opacity(opacity: 0.9, child: child),
                  ),
                  itemBuilder: (context, i) {
                    final c = cards[i];
                    return _PanelCard(
                      key: ValueKey(c.id),
                      index: i,
                      card: c,
                      store: store,
                      board: board,
                      selectable: (child) => selectable(c, child),
                      onMenu: (at) => cardMenu(context, at, c, extra: [
                        SGMenuItem(
                          icon: Icons.add_photo_alternate_outlined,
                          label: 'Add image',
                          onTap: () => pickImagesInto(context, store, c),
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _export(List<SmartCard> cards) {
    final buf = StringBuffer('${board.title} — shot list\n\n');
    for (var i = 0; i < cards.length; i++) {
      final c = cards[i];
      buf.writeln(
          '${i + 1}. ${c.title}${c.values['body'] != null && (c.values['body'] as String).isNotEmpty ? ' — ${c.values['body']}' : ''}');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shot list copied to clipboard.')),
    );
  }
}

class _PanelCard extends StatefulWidget {
  final int index;
  final SmartCard card;
  final SmartGenStore store;
  final SmartBoard board;
  final Widget Function(Widget child) selectable;
  final ValueChanged<Offset> onMenu;

  const _PanelCard({
    super.key,
    required this.index,
    required this.card,
    required this.store,
    required this.board,
    required this.selectable,
    required this.onMenu,
  });

  @override
  State<_PanelCard> createState() => _PanelCardState();
}

class _PanelCardState extends State<_PanelCard> {
  bool _editingCaption = false;
  late final TextEditingController _capCtrl;

  @override
  void initState() {
    super.initState();
    _capCtrl = TextEditingController(text: widget.card.title);
  }

  @override
  void didUpdateWidget(covariant _PanelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _capCtrl.text = widget.card.title;
      _editingCaption = false;
    }
  }

  @override
  void dispose() {
    _capCtrl.dispose();
    super.dispose();
  }

  void _commit() {
    final t = _capCtrl.text.trim();
    if (t.isNotEmpty && t != widget.card.title) {
      widget.card.title = t;
      widget.store.updateCard(widget.card);
    } else {
      _capCtrl.text = widget.card.title;
    }
    setState(() => _editingCaption = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    final img = _firstImage(c);
    final bytes = img == null ? null : _dataUrlBytes(img.dataUrl);
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      child: widget.selectable(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: SGGlass.ink,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Text('${widget.index + 1}',
                        style: AppFonts.instrumentSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTapDown: (d) => widget.onMenu(d.globalPosition),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.more_horiz_rounded,
                        size: 16, color: SGGlass.ink3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x14000000)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.cover)
                      : Container(
                          color: viewTintFor(c).withValues(alpha: 0.12),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(c.title,
                                  textAlign: TextAlign.center,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.instrumentSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: SGGlass.ink)),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _editingCaption
                ? TextField(
                    controller: _capCtrl,
                    autofocus: true,
                    style: AppFonts.instrumentSans(
                        fontSize: 12.5, color: SGGlass.ink),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _commit(),
                    onTapOutside: (_) => _commit(),
                  )
                : GestureDetector(
                    onTap: () => setState(() => _editingCaption = true),
                    behavior: HitTestBehavior.opaque,
                    child: Text(c.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.instrumentSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: SGGlass.ink2)),
                  ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Vision Board (spec §6): an inspiration collage. Cards lay out as a
// two-column staggered mosaic; image attachments lead, text cards render on
// their template tint. Cards can be nudged up/down in the flow.
// ===========================================================================

class SGVisionBoardView extends StatefulWidget {
  final SmartBoard board;
  final SmartGenStore store;
  final String searchQuery;
  final String cardFilter;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggleSelect;
  final String? highlightCardId;

  const SGVisionBoardView({
    super.key,
    required this.board,
    required this.store,
    this.searchQuery = '',
    this.cardFilter = 'all',
    this.selectMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.highlightCardId,
  });

  @override
  State<SGVisionBoardView> createState() => _SGVisionBoardViewState();
}

class _SGVisionBoardViewState extends State<SGVisionBoardView>
    with SGViewFilter {
  @override
  SmartGenStore get store => widget.store;
  @override
  SmartBoard get board => widget.board;
  @override
  String get searchQuery => widget.searchQuery;
  @override
  String get cardFilter => widget.cardFilter;
  @override
  bool get selectMode => widget.selectMode;
  @override
  Set<String> get selectedIds => widget.selectedIds;
  @override
  ValueChanged<String>? get onToggleSelect => widget.onToggleSelect;
  @override
  String? get highlightCardId => widget.highlightCardId;

  @override
  Widget build(BuildContext context) {
    final cards = visibleCards;
    final left = <SmartCard>[];
    final right = <SmartCard>[];
    for (var i = 0; i < cards.length; i++) {
      (i.isEven ? left : right).add(cards[i]);
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6F1E8), Color(0xFFEDE4F2)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text('Vision · ${cards.length}',
                      style: AppFonts.instrumentSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: SGGlass.ink)),
                ),
                _AlbumBtn(
                  icon: Icons.add_photo_alternate_outlined,
                  label: 'Add inspiration',
                  onTap: () async {
                    final c = addCard(title: 'Inspiration');
                    if (c != null && mounted) {
                      await pickImagesInto(context, store, c);
                    }
                  },
                ),
                const SizedBox(width: 8),
                _AlbumBtn(
                  icon: Icons.add_rounded,
                  label: 'Add note',
                  onTap: () => addCard(title: 'New inspiration'),
                ),
              ],
            ),
          ),
          headerInspector(),
          Expanded(
            child: cards.isEmpty
                ? Center(
                    child: Text('Pin what you are working toward.',
                        style: AppFonts.instrumentSans(
                            fontSize: 13, color: SGGlass.ink3)),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _mosaicColumn(left, cards, 0)),
                        const SizedBox(width: 10),
                        Expanded(child: _mosaicColumn(right, cards, 1)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _mosaicColumn(List<SmartCard> col, List<SmartCard> all, int colIndex) {
    return Column(
      children: [
        for (var k = 0; k < col.length; k++) ...[
          _visionTile(col[k], all.indexOf(col[k])),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _visionTile(SmartCard c, int flatIndex) {
    final img = _firstImage(c);
    final bytes = img == null ? null : _dataUrlBytes(img.dataUrl);
    // Vary tile heights for the collage feel.
    final h = [170.0, 220.0, 140.0, 200.0][flatIndex % 4];
    return selectable(
      c,
      Container(
        height: bytes != null ? h : null,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              if (bytes != null)
                SizedBox(
                  height: h,
                  width: double.infinity,
                  child: Image.memory(bytes, fit: BoxFit.cover),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: viewTintFor(c).withValues(alpha: 0.85),
                  child: Text(c.title,
                      style: AppFonts.instrumentSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3)),
                ),
              // Caption overlay only over photos; text tiles already
              // show the title in the tinted body.
              if (bytes != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(c.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.instrumentSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                        GestureDetector(
                          onTapDown: (d) =>
                              cardMenu(context, d.globalPosition, c, extra: [
                            if (flatIndex > 0)
                              SGMenuItem(
                                icon: Icons.arrow_upward_rounded,
                                label: 'Move earlier',
                                onTap: () => store.reorderBoardCard(
                                    board.id, c.id, flatIndex - 1),
                              ),
                          ]),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.more_horiz_rounded,
                                size: 15, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Swimlane Board (spec §6/§7.5): cards grouped into lanes (rows); each lane
// groups its cards by status. Lanes add/rename/delete inline; cards move
// between lanes and statuses from the card menu — no configuration screens.
// ===========================================================================

/// Inline lane name editor: replaces the old rename dialog.
class _LaneNameField extends StatefulWidget {
  final String initial;
  final String hint;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;
  const _LaneNameField(
      {required this.initial,
      this.hint = 'Lane name…',
      required this.onSubmit,
      required this.onCancel});

  @override
  State<_LaneNameField> createState() => _LaneNameFieldState();
}

class _LaneNameFieldState extends State<_LaneNameField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  void _done() {
    widget.onSubmit(_ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            style: AppFonts.instrumentSans(fontSize: 13.5, color: SGGlass.ink),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle:
                  AppFonts.instrumentSans(fontSize: 13.5, color: SGGlass.ink3),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onSubmitted: (_) => _done(),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _done,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.check_rounded, size: 18, color: SGGlass.ink2),
          ),
        ),
        GestureDetector(
          onTap: widget.onCancel,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.close_rounded, size: 18, color: SGGlass.ink3),
          ),
        ),
      ],
    );
  }
}

class SGSwimlaneView extends StatefulWidget {
  final SmartBoard board;
  final SmartGenStore store;
  final String searchQuery;
  final String cardFilter;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggleSelect;
  final String? highlightCardId;

  const SGSwimlaneView({
    super.key,
    required this.board,
    required this.store,
    this.searchQuery = '',
    this.cardFilter = 'all',
    this.selectMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.highlightCardId,
  });

  @override
  State<SGSwimlaneView> createState() => _SGSwimlaneViewState();
}

class _SGSwimlaneViewState extends State<SGSwimlaneView> with SGViewFilter {
  String? _editingLane;
  bool _addingLane = false;
  @override
  SmartGenStore get store => widget.store;
  @override
  SmartBoard get board => widget.board;
  @override
  String get searchQuery => widget.searchQuery;
  @override
  String get cardFilter => widget.cardFilter;
  @override
  bool get selectMode => widget.selectMode;
  @override
  Set<String> get selectedIds => widget.selectedIds;
  @override
  ValueChanged<String>? get onToggleSelect => widget.onToggleSelect;
  @override
  String? get highlightCardId => widget.highlightCardId;

  static const _defaultLane = 'General';

  List<String> get _lanes {
    final raw = board.settings['lanes'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    final fromCards = visibleCards
        .map((c) => (c.values['lane']?.toString() ?? '').trim())
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList();
    return fromCards.isEmpty ? [_defaultLane] : fromCards;
  }

  String _laneOf(SmartCard c) {
    final l = (c.values['lane']?.toString() ?? '').trim();
    return l.isEmpty ? _lanes.first : l;
  }

  void _setLane(SmartCard c, String lane) {
    c.values['lane'] = lane;
    store.updateCard(c);
  }

  void _saveLanes(List<String> lanes) {
    store.setBoardSetting(board.id, 'lanes', lanes);
  }

  @override
  Widget build(BuildContext context) {
    final lanes = _lanes;
    final columns = _columns();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Text('Swimlanes · ${lanes.length}',
                    style: AppFonts.instrumentSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SGGlass.ink)),
              ),
              _AlbumBtn(
                icon: Icons.add_rounded,
                label: 'Add lane',
                onTap: () => setState(() {
                  _addingLane = true;
                  _editingLane = null;
                }),
              ),
            ],
          ),
        ),
        if (_addingLane)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _LaneNameField(
              initial: '',
              hint: 'New lane name…',
              onCancel: () => setState(() => _addingLane = false),
              onSubmit: (name) {
                if (name.isNotEmpty) _saveLanes([...lanes, name]);
                setState(() => _addingLane = false);
              },
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
            itemCount: lanes.length,
            itemBuilder: (context, li) {
              final lane = lanes[li];
              final laneCards =
                  visibleCards.where((c) => _laneOf(c) == lane).toList();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x14000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: _editingLane == lane
                                ? _LaneNameField(
                                    initial: lane,
                                    onCancel: () =>
                                        setState(() => _editingLane = null),
                                    onSubmit: (name) {
                                      if (name.isNotEmpty && name != lane) {
                                        final next = lanes
                                            .map((l) => l == lane ? name : l)
                                            .toList();
                                        _saveLanes(next);
                                        for (final c
                                            in store.boardCards(board.id)) {
                                          if ((c.values['lane']?.toString() ??
                                                  '') ==
                                              lane) {
                                            _setLane(c, name);
                                          }
                                        }
                                      }
                                      setState(() => _editingLane = null);
                                    },
                                  )
                                : GestureDetector(
                                    onTap: () => setState(() {
                                      _editingLane = lane;
                                      _addingLane = false;
                                    }),
                                    behavior: HitTestBehavior.opaque,
                                    child: Text(lane,
                                        style: AppFonts.instrumentSans(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: SGGlass.ink)),
                                  ),
                          ),
                          Text('${laneCards.length}',
                              style: AppFonts.instrumentSans(
                                  fontSize: 11.5, color: SGGlass.ink3)),
                          const SizedBox(width: 4),
                          Tooltip(
                            message: 'Add card to lane',
                            child: GestureDetector(
                              onTap: () {
                                final c = addCard(title: 'New card');
                                if (c != null) _setLane(c, lane);
                              },
                              behavior: HitTestBehavior.opaque,
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.add_rounded,
                                    size: 16, color: SGGlass.ink2),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTapDown: (d) =>
                                _laneMenu(d.globalPosition, lane, lanes),
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.more_horiz_rounded,
                                  size: 16, color: SGGlass.ink3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final col in columns) ...[
                      _laneStatusGroup(
                          lane, col.key, col.label, laneCards, lanes),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<_ColDef> _columns() {
    final raw = board.settings['columns'];
    final labels = (raw is List && raw.isNotEmpty)
        ? raw.map((e) => e.toString()).toList()
        : const ['To Do', 'In Progress', 'Done'];
    return labels.map((l) => _ColDef(normalizeKanbanStatus(l), l)).toList();
  }

  Widget _laneStatusGroup(String lane, String statusKey, String label,
      List<SmartCard> laneCards, List<String> lanes) {
    final cards = laneCards
        .where((c) => normalizeKanbanStatus(c.status) == statusKey)
        .toList();
    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AppFonts.instrumentSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: SGGlass.ink3)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cards)
                selectable(
                  c,
                  GestureDetector(
                    onTapDown: (d) =>
                        cardMenu(context, d.globalPosition, c, extra: [
                      for (final l in lanes)
                        if (l != _laneOf(c))
                          SGMenuItem(
                            icon: Icons.swap_horiz_rounded,
                            label: 'Move to $l',
                            onTap: () => _setLane(c, l),
                          ),
                      for (final col in _columns())
                        if (col.key != normalizeKanbanStatus(c.status))
                          SGMenuItem(
                            icon: Icons.drive_file_move_outlined,
                            label: 'To ${col.label}',
                            onTap: () {
                              c.status = col.key;
                              store.updateCard(c);
                            },
                          ),
                    ]),
                    behavior: HitTestBehavior.opaque,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: SGCardFace(
                        card: c,
                        template: store.template(c.templateId),
                        snippet: SGCardFace.snippetFor(
                            c, store.template(c.templateId)),
                        // No "…" button: tap-anywhere already opens the menu
                        // via the outer GestureDetector.
                        title: Text(c.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.instrumentSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: SGGlass.ink)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          headerInspector(),
        ],
      ),
    );
  }

  void _laneMenu(Offset at, String lane, List<String> lanes) {
    SGMenu.show(
      context,
      at: at,
      items: [
        SGMenuItem(
          icon: Icons.edit_outlined,
          label: 'Rename lane',
          onTap: () => setState(() {
            _editingLane = lane;
            _addingLane = false;
          }),
        ),
        SGMenuItem(
          icon: Icons.delete_outline_rounded,
          label: 'Delete lane',
          destructive: true,
          onTap: () {
            final next = lanes.where((l) => l != lane).toList();
            _saveLanes(next.isEmpty ? [_defaultLane] : next);
            for (final c in store.boardCards(board.id)) {
              if (_laneOf(c) == lane) {
                _setLane(c, (next.isEmpty ? [_defaultLane] : next).first);
              }
            }
          },
        ),
      ],
    );
  }
}

class _ColDef {
  final String key;
  final String label;
  const _ColDef(this.key, this.label);
}

// ===========================================================================
// US Map / World Map (spec §6): pins on a stylized map surface. Pins are
// cards with normalized map coordinates; they drag, add (tap-to-place),
// delete, and group by region — all inline.
// ===========================================================================

class SGMapView extends StatefulWidget {
  final SmartBoard board;
  final SmartGenStore store;
  final bool world; // false = US, true = world
  final String searchQuery;
  final String cardFilter;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggleSelect;
  final String? highlightCardId;

  const SGMapView({
    super.key,
    required this.board,
    required this.store,
    this.world = false,
    this.searchQuery = '',
    this.cardFilter = 'all',
    this.selectMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.highlightCardId,
  });

  @override
  State<SGMapView> createState() => _SGMapViewState();
}

class _SGMapViewState extends State<SGMapView> with SGViewFilter {
  @override
  SmartGenStore get store => widget.store;
  @override
  SmartBoard get board => widget.board;
  @override
  String get searchQuery => widget.searchQuery;
  @override
  String get cardFilter => widget.cardFilter;
  @override
  bool get selectMode => widget.selectMode;
  @override
  Set<String> get selectedIds => widget.selectedIds;
  @override
  ValueChanged<String>? get onToggleSelect => widget.onToggleSelect;
  @override
  String? get highlightCardId => widget.highlightCardId;

  bool _placing = false;
  String? _regionFilter;
  Offset? _pendingPin;
  String? _editingRegionFor;
  bool _showRegionFilter = false;
  final _mapKey = GlobalKey();

  double _px(SmartCard c) =>
      (c.values['mapX'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.5;
  double _py(SmartCard c) =>
      (c.values['mapY'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.5;
  String _regionOf(SmartCard c) =>
      (c.values['region']?.toString() ?? '').trim();

  void _setPos(SmartCard c, double x, double y) {
    c.values['mapX'] = x.clamp(0.0, 1.0);
    c.values['mapY'] = y.clamp(0.0, 1.0);
    store.updateCard(c);
  }

  @override
  Widget build(BuildContext context) {
    var cards = visibleCards;
    if (_regionFilter != null) {
      cards = cards.where((c) => _regionOf(c) == _regionFilter).toList();
    }
    final regions = visibleCards
        .map(_regionOf)
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _regionEditorBar(),
        _regionFilterRow(regions),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                    '${widget.world ? 'World' : 'US'} · ${cards.length} pin${cards.length == 1 ? '' : 's'}',
                    style: AppFonts.instrumentSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SGGlass.ink)),
              ),
              if (regions.isNotEmpty)
                _AlbumBtn(
                  icon: Icons.filter_list_rounded,
                  label: _regionFilter ?? 'Regions',
                  onTap: () =>
                      setState(() => _showRegionFilter = !_showRegionFilter),
                ),
              const SizedBox(width: 8),
              _AlbumBtn(
                icon: _placing
                    ? Icons.close_rounded
                    : Icons.add_location_alt_outlined,
                label: _placing ? 'Cancel' : 'Add pin',
                onTap: () => setState(() {
                  _placing = !_placing;
                  if (!_placing) _pendingPin = null;
                }),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return GestureDetector(
                  onTapDown:
                      _placing ? (d) => _placePin(d.localPosition, w, h) : null,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    key: _mapKey,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFDCEBF7), Color(0xFFEFF6EC)],
                      ),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _MapGridPainter(world: widget.world),
                            ),
                          ),
                          if (_placing && _pendingPin == null)
                            Positioned.fill(
                              child: Container(
                                alignment: Alignment.topCenter,
                                padding: const EdgeInsets.only(top: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: SGGlass.ink.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text('Tap the map to place the pin',
                                      style: AppFonts.instrumentSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                ),
                              ),
                            ),
                          if (_pendingPin != null) ...[
                            _pinDraftEditor(),
                            Positioned(
                              left:
                                  (_pendingPin!.dx * w - 18).clamp(0.0, w - 36),
                              top:
                                  (_pendingPin!.dy * h - 40).clamp(0.0, h - 44),
                              child: const IgnorePointer(
                                child: Icon(Icons.location_on_rounded,
                                    size: 36, color: Color(0xFF0A84FF)),
                              ),
                            ),
                          ],
                          for (final c in cards)
                            Positioned(
                              left: (_px(c) * w - 18).clamp(0.0, w - 36),
                              top: (_py(c) * h - 40).clamp(0.0, h - 44),
                              child: _MapPin(
                                card: c,
                                selected: selectedIds.contains(c.id),
                                highlighted: highlightCardId == c.id,
                                selectMode: selectMode,
                                region: _regionOf(c),
                                onTap: () {
                                  if (selectMode) {
                                    onToggleSelect?.call(c.id);
                                  } else {
                                    toggleExpanded(c);
                                  }
                                },
                                onMenu: (at) => _pinMenu(at, c),
                                onDragEnd: (global) {
                                  final box = _mapKey.currentContext
                                      ?.findRenderObject() as RenderBox?;
                                  if (box == null) return;
                                  final local = box.globalToLocal(global);
                                  // The pin's anchor sits ~18pt right and
                                  // ~40pt below the feedback's top-left.
                                  _setPos(c, (local.dx + 18) / box.size.width,
                                      (local.dy + 40) / box.size.height);
                                },
                              ),
                            ),
                          // Inline pin inspector: anchored in-surface at the
                          // bottom of the map, never a modal route.
                          if (_expandedCardId != null)
                            Positioned(
                              left: 10,
                              right: 10,
                              bottom: 10,
                              child: Builder(builder: (context) {
                                final c = store.card(_expandedCardId!);
                                if (c == null) {
                                  return const SizedBox.shrink();
                                }
                                return SGCardInspector(
                                  store: store,
                                  card: c,
                                  onCollapse: collapseExpanded,
                                  maxHeight: h * 0.52,
                                );
                              }),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _placePin(Offset local, double w, double h) {
    setState(() {
      _pendingPin = Offset(
          (local.dx / w).clamp(0.0, 1.0), (local.dy / h).clamp(0.0, 1.0));
    });
  }

  void _commitPin(String title, String region) {
    final at = _pendingPin;
    if (at == null) return;
    final c = addCard(title: title.trim().isEmpty ? 'New pin' : title.trim());
    if (c != null) {
      _setPos(c, at.dx, at.dy);
      final r = region.trim();
      if (r.isNotEmpty) {
        c.values['region'] = r;
        store.updateCard(c);
      }
    }
    setState(() {
      _pendingPin = null;
      _placing = false;
    });
  }

  /// Inline pin draft editor, anchored at the top of the map while placing.
  Widget _pinDraftEditor() {
    final titleCtrl = TextEditingController();
    final regionCtrl = TextEditingController();
    return Positioned(
      left: 10,
      right: 10,
      top: 10,
      child: GlassPanel(
        radius: 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New pin',
                style: AppFonts.instrumentSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SGGlass.ink)),
            const SizedBox(height: 8),
            TextField(
              controller: titleCtrl,
              autofocus: true,
              style: AppFonts.instrumentSans(fontSize: 13, color: SGGlass.ink),
              decoration: InputDecoration(
                  hintText: 'Label',
                  hintStyle: AppFonts.instrumentSans(
                      fontSize: 13, color: SGGlass.ink3),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              onSubmitted: (_) => _commitPin(titleCtrl.text, regionCtrl.text),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: regionCtrl,
              style: AppFonts.instrumentSans(fontSize: 13, color: SGGlass.ink),
              decoration: InputDecoration(
                  hintText:
                      widget.world ? 'Country / region' : 'State / region',
                  hintStyle: AppFonts.instrumentSans(
                      fontSize: 13, color: SGGlass.ink3),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              onSubmitted: (_) => _commitPin(titleCtrl.text, regionCtrl.text),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _AlbumBtn(
                  icon: Icons.close_rounded,
                  label: 'Cancel',
                  onTap: () => setState(() => _pendingPin = null),
                ),
                const SizedBox(width: 8),
                _AlbumBtn(
                  icon: Icons.check_rounded,
                  label: 'Place pin',
                  onTap: () => _commitPin(titleCtrl.text, regionCtrl.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _pinMenu(Offset at, SmartCard c) {
    cardMenu(context, at, c, extra: [
      SGMenuItem(
        icon: Icons.flag_outlined,
        label: _regionOf(c).isEmpty ? 'Set region' : 'Region: ${_regionOf(c)}',
        onTap: () => setState(() => _editingRegionFor = c.id),
      ),
    ]);
  }

  /// Inline region editor bar, shown below the map header while editing.
  Widget _regionEditorBar() {
    final id = _editingRegionFor;
    if (id == null) return const SizedBox.shrink();
    final c = store.card(id);
    if (c == null) {
      _editingRegionFor = null;
      return const SizedBox.shrink();
    }
    final ctrl = TextEditingController(text: _regionOf(c));
    void save() {
      c.values['region'] = ctrl.text.trim();
      store.updateCard(c);
      setState(() => _editingRegionFor = null);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: GlassPanel(
        radius: 14,
        child: Row(
          children: [
            const Icon(Icons.flag_outlined, size: 16, color: SGGlass.ink3),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: ctrl,
                autofocus: true,
                style:
                    AppFonts.instrumentSans(fontSize: 13, color: SGGlass.ink),
                decoration: InputDecoration(
                  hintText:
                      widget.world ? 'Country / region' : 'State / region',
                  hintStyle: AppFonts.instrumentSans(
                      fontSize: 13, color: SGGlass.ink3),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (_) => save(),
              ),
            ),
            GestureDetector(
              onTap: save,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.check_rounded, size: 18, color: SGGlass.ink2),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _editingRegionFor = null),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, size: 18, color: SGGlass.ink3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Inline region filter: an expandable chip row below the header.
  Widget _regionFilterRow(List<String> regions) {
    if (!_showRegionFilter) return const SizedBox.shrink();
    Widget chip(String? region, String label, int count) {
      final active = _regionFilter == region;
      return GestureDetector(
        onTap: () => setState(() => _regionFilter = region),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF0A84FF)
                : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color:
                    active ? const Color(0xFF0A84FF) : const Color(0x14000000)),
          ),
          child: Text('$label · $count',
              style: AppFonts.instrumentSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : SGGlass.ink2)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip(null, 'All', visibleCards.length),
          for (final r in regions)
            chip(r, r, visibleCards.where((c) => _regionOf(c) == r).length),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final SmartCard card;
  final bool selected;
  final bool highlighted;
  final bool selectMode;
  final String region;
  final VoidCallback onTap;
  final ValueChanged<Offset> onMenu;
  final ValueChanged<Offset> onDragEnd;

  const _MapPin({
    required this.card,
    required this.selected,
    required this.highlighted,
    required this.selectMode,
    required this.region,
    required this.onTap,
    required this.onMenu,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final tint = viewTintFor(card);
    final pin = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: selectMode ? onTap : null,
          onLongPress: selectMode ? null : () {},
          onSecondaryTapDown:
              selectMode ? null : (d) => onMenu(d.globalPosition),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: highlighted
                    ? const Color(0xFF0A84FF)
                    : selected
                        ? const Color(0xFF0A84FF)
                        : const Color(0x22000000),
                width: highlighted || selected ? 2 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              card.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.instrumentSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: SGGlass.ink),
            ),
          ),
        ),
        Icon(Icons.location_on_rounded, size: 26, color: tint),
      ],
    );
    if (selectMode) return pin;
    return Draggable<String>(
      data: 'pin:${card.id}',
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.9, child: pin),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: pin),
      onDragEnd: (d) => onDragEnd(d.offset),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: pin,
      ),
    );
  }
}

/// Faint lat/long-style grid with a soft abstract landmass — a stylized map
/// surface, not a geographic survey.
class _MapGridPainter extends CustomPainter {
  final bool world;
  const _MapGridPainter({required this.world});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF9DB8D2).withValues(alpha: 0.35)
      ..strokeWidth = 0.7;
    final step = world ? 34.0 : 28.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    // Soft landmass blobs.
    final landPaint = Paint()
      ..color = const Color(0xFFCFE3C8).withValues(alpha: 0.5);
    final blobs = world
        ? [
            Rect.fromLTWH(size.width * 0.08, size.height * 0.15,
                size.width * 0.3, size.height * 0.4),
            Rect.fromLTWH(size.width * 0.5, size.height * 0.2,
                size.width * 0.38, size.height * 0.5),
            Rect.fromLTWH(size.width * 0.3, size.height * 0.6,
                size.width * 0.25, size.height * 0.25),
          ]
        : [
            Rect.fromLTWH(size.width * 0.12, size.height * 0.18,
                size.width * 0.72, size.height * 0.5),
            Rect.fromLTWH(size.width * 0.6, size.height * 0.62,
                size.width * 0.18, size.height * 0.2),
          ];
    for (final r in blobs) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(28)),
        landPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter old) => old.world != world;
}

/// A single file row: the attachment plus the card it lives on.
class SGFileEntry {
  final SmartCard card;
  final CardAttachment file;
  const SGFileEntry(this.card, this.file);
}

/// Undoable file operation (local to the explorer session).
class _FileOp {
  final VoidCallback undo;
  final VoidCallback redo;
  const _FileOp({required this.undo, required this.redo});
}

/// Files explorer — the photo-viewer reference (Figma secondary) with Smart
/// Gen assets: every attachment across the board's cards, browsed in a
/// floating window with a numbered thumbnail sidebar, a preview stage, and
/// floating toolbars. Nothing here is full-width; the window floats in the
/// board area like every other visionOS surface.
class SGFilesView extends StatefulWidget {
  final SmartBoard board;
  final SmartGenStore store;
  final String searchQuery;
  final String cardFilter;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggleSelect;
  final String? highlightCardId;

  const SGFilesView({
    super.key,
    required this.board,
    required this.store,
    this.searchQuery = '',
    this.cardFilter = 'all',
    this.selectMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.highlightCardId,
  });

  @override
  State<SGFilesView> createState() => _SGFilesViewState();
}

class _SGFilesViewState extends State<SGFilesView> with SGViewFilter {
  @override
  SmartGenStore get store => widget.store;
  @override
  SmartBoard get board => widget.board;
  @override
  String get searchQuery => widget.searchQuery;
  @override
  String get cardFilter => widget.cardFilter;
  @override
  bool get selectMode => widget.selectMode;
  @override
  Set<String> get selectedIds => widget.selectedIds;
  @override
  ValueChanged<String>? get onToggleSelect => widget.onToggleSelect;
  @override
  String? get highlightCardId => widget.highlightCardId;

  String? _selectedId;
  bool _sidebarOpen = true;
  bool _gridMode = false;
  bool _ribbonCollapsed = false;
  String _sort = 'name'; // name | size | type
  double _zoom = 1.0;
  bool _renaming = false;
  bool _previewOpen = false; // in-surface floating preview (R25: no modals)
  late final TextEditingController _renameCtrl;
  Timer? _slideshow;
  final List<_FileOp> _undoStack = [];
  final List<_FileOp> _redoStack = [];
  final Map<String, Uint8List> _bytesCache = {};

  @override
  void initState() {
    super.initState();
    _renameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _slideshow?.cancel();
    _renameCtrl.dispose();
    super.dispose();
  }

  List<SGFileEntry> get _files {
    final out = <SGFileEntry>[];
    for (final c in visibleCards) {
      for (final a in c.attachments) {
        out.add(SGFileEntry(c, a));
      }
    }
    switch (_sort) {
      case 'size':
        out.sort((a, b) => b.file.sizeBytes.compareTo(a.file.sizeBytes));
        break;
      case 'type':
        out.sort((a, b) {
          final t = a.file.mime.compareTo(b.file.mime);
          return t != 0 ? t : a.file.name.compareTo(b.file.name);
        });
        break;
      default:
        out.sort((a, b) => a.file.name.compareTo(b.file.name));
    }
    return out;
  }

  SGFileEntry? get _selected {
    final files = _files;
    if (files.isEmpty) return null;
    final i = files.indexWhere((e) => e.file.id == _selectedId);
    return i < 0 ? files.first : files[i];
  }

  Uint8List? _bytesFor(CardAttachment f) {
    if (f.dataUrl.isEmpty) return null;
    return _bytesCache.putIfAbsent(f.id, () {
      try {
        final b64 = f.dataUrl.split(',').last;
        return base64Decode(b64);
      } catch (_) {
        return Uint8List(0);
      }
    });
  }

  void _pushOp(_FileOp op) {
    _undoStack.add(op);
    _redoStack.clear();
  }

  void _doUndo() {
    if (_undoStack.isEmpty) return;
    final op = _undoStack.removeLast();
    op.undo();
    _redoStack.add(op);
    setState(() {});
  }

  void _doRedo() {
    if (_redoStack.isEmpty) return;
    final op = _redoStack.removeLast();
    op.redo();
    _undoStack.add(op);
    setState(() {});
  }

  void _deleteSelected() {
    final s = _selected;
    if (s == null) return;
    final cardId = s.card.id;
    final att = s.file;
    store.removeAttachment(cardId, att.id);
    _pushOp(_FileOp(
      undo: () => store.addAttachment(cardId, att),
      redo: () => store.removeAttachment(cardId, att.id),
    ));
    setState(() => _selectedId = null);
  }

  void _duplicateSelected() {
    final s = _selected;
    if (s == null) return;
    final cardId = s.card.id;
    final copy = CardAttachment(
      name: _copyName(s.file.name),
      mime: s.file.mime,
      dataUrl: s.file.dataUrl,
      sizeBytes: s.file.sizeBytes,
    );
    store.addAttachment(cardId, copy);
    _pushOp(_FileOp(
      undo: () => store.removeAttachment(cardId, copy.id),
      redo: () => store.addAttachment(cardId, copy),
    ));
    setState(() => _selectedId = copy.id);
  }

  String _copyName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return '$name copy';
    return '${name.substring(0, dot)} copy${name.substring(dot)}';
  }

  Future<void> _addFile() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (res == null || !mounted) return;
    for (final f in res.files) {
      final bytes = f.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      if (bytes.length > 2 * 1024 * 1024) continue; // persistence guard
      final ext = (f.extension ?? '').toLowerCase();
      final mime = ext == 'png'
          ? 'image/png'
          : ext == 'gif'
              ? 'image/gif'
              : (ext == 'jpg' || ext == 'jpeg')
                  ? 'image/jpeg'
                  : ext == 'pdf'
                      ? 'application/pdf'
                      : 'application/octet-stream';
      final card = store.instantiateCard('builtin_card_note',
          boardId: board.id, title: f.name);
      if (card == null) continue;
      final att = CardAttachment(
        name: f.name,
        mime: mime,
        dataUrl: 'data:$mime;base64,${base64Encode(bytes)}',
        sizeBytes: bytes.length,
      );
      store.addAttachment(card.id, att);
      final cardId = card.id;
      _pushOp(_FileOp(
        undo: () => store.removeAttachment(cardId, att.id),
        redo: () => store.addAttachment(cardId, att),
      ));
      _selectedId = att.id;
    }
    setState(() {});
  }

  void _commitRename() {
    final s = _selected;
    final t = _renameCtrl.text.trim();
    setState(() => _renaming = false);
    if (s == null || t.isEmpty || t == s.file.name) return;
    final old = s.file.name;
    s.file.name = t;
    store.updateCard(s.card);
    _pushOp(_FileOp(
      undo: () {
        s.file.name = old;
        store.updateCard(s.card);
      },
      redo: () {
        s.file.name = t;
        store.updateCard(s.card);
      },
    ));
    setState(() {});
  }

  void _toggleSlideshow() {
    if (_slideshow != null) {
      _slideshow!.cancel();
      _slideshow = null;
      setState(() {});
      return;
    }
    final images =
        _files.where((e) => e.file.isImage && e.file.dataUrl.isNotEmpty);
    if (images.isEmpty) return;
    _slideshow = Timer.periodic(const Duration(seconds: 3), (_) {
      final imgs = images.toList();
      final cur = imgs.indexWhere((e) => e.file.id == _selectedId);
      final next = imgs[(cur + 1) % imgs.length];
      if (mounted) setState(() => _selectedId = next.file.id);
    });
    setState(() {});
  }

  void _cycleZoom() {
    setState(() => _zoom = _zoom >= 2.0 ? 1.0 : (_zoom >= 1.5 ? 2.0 : 1.5));
  }

  String _fmtSize(int bytes) {
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  String _kindLabel(String mime) {
    if (mime.startsWith('image/')) return 'IMAGE';
    if (mime.startsWith('video/')) return 'VIDEO';
    if (mime == 'application/pdf') return 'PDF';
    if (mime.contains('csv') || mime.contains('sheet')) return 'DATA';
    return 'FILE';
  }

  IconData _mimeIcon(String mime) {
    if (mime.startsWith('image/')) return Icons.image_rounded;
    if (mime.startsWith('video/')) return Icons.videocam_rounded;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_rounded;
    if (mime.contains('csv') || mime.contains('sheet')) {
      return Icons.table_chart_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  void _sortMenu(Offset at) {
    SGMenu.show(
      context,
      at: at,
      items: [
        SGMenuItem(
            icon: Icons.sort_by_alpha_rounded,
            label: 'Sort by name',
            highlighted: _sort == 'name',
            onTap: () => setState(() => _sort = 'name')),
        SGMenuItem(
            icon: Icons.storage_rounded,
            label: 'Sort by size',
            highlighted: _sort == 'size',
            onTap: () => setState(() => _sort = 'size')),
        SGMenuItem(
            icon: Icons.category_rounded,
            label: 'Sort by type',
            highlighted: _sort == 'type',
            onTap: () => setState(() => _sort = 'type')),
      ],
    );
  }

  void _fileMenu(Offset at) {
    final s = _selected;
    if (s == null) return;
    SGMenu.show(
      context,
      at: at,
      items: [
        SGMenuItem(
            icon: Icons.edit_rounded,
            label: 'Rename',
            onTap: () {
              _renameCtrl.text = s.file.name;
              setState(() => _renaming = true);
            }),
        SGMenuItem(
            icon: Icons.copy_rounded,
            label: 'Duplicate',
            onTap: _duplicateSelected),
        SGMenuItem(
            icon: Icons.grid_view_rounded,
            label: _gridMode ? 'Exit grid' : 'Grid view',
            onTap: () => setState(() => _gridMode = !_gridMode)),
        SGMenuItem(
            icon: Icons.open_in_new_rounded,
            label: 'Open preview',
            onTap: _openPreviewOverlay),
        SGMenuItem(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            destructive: true,
            onTap: _deleteSelected),
      ],
    );
  }

  void _openPreviewOverlay() {
    final s = _selected;
    if (s == null) return;
    // R25: in-surface floating window, not a modal dialog. The preview
    // renders as a Positioned overlay inside this view's Stack.
    setState(() => _previewOpen = true);
  }

  Widget _previewWindow() {
    final s = _selected;
    if (s == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _previewOpen = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.35),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // swallow taps inside the window
              child: GlassPanel.window(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.86,
                  height: MediaQuery.of(context).size.height * 0.62,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(s.file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.instrumentSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                          GlassPressable(
                            onTap: () =>
                                setState(() => _previewOpen = false),
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(Icons.close_rounded,
                                  size: 16, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(child: _previewBody(s, large: true)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final files = _files;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: GlassPanel.window(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Floating top toolbar (Frame 5 recipe): window chrome.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Center(child: _topToolbar(files.length)),
                ),
                Expanded(
                  child: files.isEmpty
                      ? _emptyState()
                      : _gridMode
                          ? _gridBody(files)
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_sidebarOpen) _sidebar(files),
                                Expanded(child: _stage(files)),
                              ],
                            ),
                ),
                // Bottom area reserved for the permanent dock (added by the
                // screen). No contextual toolbar here per master spec §6.1.
                const SizedBox(height: 8),
              ],
            ),
            // Contextual action ribbon: demure, floating at the right edge.
            // Per master spec, contextual options live here, not in the
            // permanent bottom dock.
            if (files.isNotEmpty)
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(child: _actionRibbon()),
              ),
            // In-surface floating preview window (R25: zero modals).
            if (_previewOpen) _previewWindow(),
          ],
        ),
      ),
    );
  }

  Widget _actionRibbon() {
    return SGActionRibbon(
      collapsed: _ribbonCollapsed,
      onToggleCollapse: () => setState(() => _ribbonCollapsed = !_ribbonCollapsed),
      actions: [
        SGRibbonAction(
          icon: Icons.undo_rounded,
          label: 'Undo',
          onTap: _doUndo,
          enabled: _undoStack.isNotEmpty,
        ),
        SGRibbonAction(
          icon: Icons.redo_rounded,
          label: 'Redo',
          onTap: _doRedo,
          enabled: _redoStack.isNotEmpty,
        ),
        SGRibbonAction(
          icon: Icons.zoom_in_rounded,
          label: 'Zoom: ${(_zoom * 100).round()}%',
          onTap: _cycleZoom,
        ),
        SGRibbonAction(
          icon: Icons.grid_view_rounded,
          label: 'Toggle grid',
          onTap: () {
            _slideshow?.cancel();
            _slideshow = null;
            setState(() => _gridMode = !_gridMode);
          },
          active: _gridMode,
        ),
        SGRibbonAction(
          icon: _slideshow != null ? Icons.stop_rounded : Icons.play_arrow_rounded,
          label: _slideshow != null ? 'Stop slideshow' : 'Slideshow',
          onTap: _toggleSlideshow,
          active: _slideshow != null,
        ),
        SGRibbonAction(
          icon: Icons.copy_rounded,
          label: 'Duplicate',
          onTap: _duplicateSelected,
          enabled: _selected != null,
        ),
        SGRibbonAction(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          onTap: _deleteSelected,
          enabled: _selected != null,
        ),
        SGRibbonAction(
          icon: Icons.fullscreen_rounded,
          label: 'Preview',
          onTap: _openPreviewOverlay,
          enabled: _selected != null,
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.folder_open_rounded,
                size: 30, color: Colors.white54),
          ),
          const SizedBox(height: 14),
          Text('No files yet',
              style: AppFonts.instrumentSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text('Attach files to any card and browse them here.',
              style: AppFonts.instrumentSans(
                  fontSize: 12.5, color: Colors.white54)),
          const SizedBox(height: 16),
          GlassPressable(
            onTap: _addFile,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded,
                      size: 16, color: SGGlass.sysBlue),
                  const SizedBox(width: 6),
                  Text('Add file',
                      style: AppFonts.instrumentSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SGGlass.sysBlue)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- top toolbar ----------------

  Widget _topToolbar(int count) {
    return GlassPanel.bar(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      // The desktop reference toolbar is wide; on a phone it scrolls
      // instead of overflowing — every action stays one swipe away.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _barBtn(Icons.chevron_left_rounded, _sidebarOpen ? 'Hide sidebar' : 'Show sidebar',
                () => setState(() => _sidebarOpen = !_sidebarOpen)),
          GestureDetector(
            onTapDown: (d) => _sortMenu(d.globalPosition),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Files · $count',
                      style: AppFonts.instrumentSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: Colors.white60),
                ],
              ),
            ),
          ),
          _barBtn(
              _slideshow != null
                  ? Icons.stop_rounded
                  : Icons.play_arrow_rounded,
              _slideshow != null ? 'Stop slideshow' : 'Slideshow',
              _toggleSlideshow),
          Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: Colors.white.withValues(alpha: 0.14)),
          _barBtn(Icons.note_add_rounded, 'Add file', _addFile),
          _barBtn(Icons.more_horiz_rounded, 'File actions', () {},
              onTapDown: (pos) => _fileMenu(pos)),
          _barBtn(Icons.open_in_new_rounded, 'Open preview', _openPreviewOverlay),
          ],
        ),
      ),
    );
  }

  Widget _barBtn(IconData icon, String tip, VoidCallback onTap,
      {ValueChanged<Offset>? onTapDown}) {
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: onTapDown == null ? onTap : null,
        onTapDown:
            onTapDown == null ? null : (d) => onTapDown(d.globalPosition),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 17, color: Colors.white.withValues(alpha: 0.85)),
        ),
      ),
    );
  }

  // ---------------- sidebar ----------------

  Widget _sidebar(List<SGFileEntry> files) {
    // The reference sidebar is ~1/4 of the window; on a phone that ratio
    // keeps the stage usable.
    final narrow = MediaQuery.of(context).size.width < 480;
    return Container(
      width: narrow ? 104 : 148,
      margin: const EdgeInsets.fromLTRB(12, 0, 0, 0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Context header: which board's files these are.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
            child: Text(widget.board.title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.instrumentSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.white.withValues(alpha: 0.45))),
          ),
          Expanded(
            // Faded edges (Figma faded-edges recipe): the list dissolves
            // into the panel instead of clipping hard.
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.88, 1.0],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: _sidebarList(files),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
            child: GlassPressable(
              onTap: _addFile,
              child: const Padding(
                padding: EdgeInsets.all(9),
                child: Icon(Icons.add_rounded,
                    size: 17, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sidebar list: flat numbered thumbnails, or grouped under category
  /// headers when sorted by type (the convenient category-menu mode).
  Widget _sidebarList(List<SGFileEntry> files) {
    if (_sort != 'type') {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
        itemCount: files.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _thumb(files[i], i),
      );
    }
    // Group consecutive same-kind files under category headers. The files
    // list is already sorted by type, so kinds arrive in runs.
    final items = <Widget>[];
    String? lastKind;
    for (var i = 0; i < files.length; i++) {
      final kind = _kindLabel(files[i].file.mime);
      if (kind != lastKind) {
        lastKind = kind;
        if (items.isNotEmpty) items.add(const SizedBox(height: 6));
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
          child: Text(kind.toUpperCase(),
              style: AppFonts.instrumentSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.white.withValues(alpha: 0.4))),
        ));
      }
      items.add(_thumb(files[i], i));
      items.add(const SizedBox(height: 10));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
      children: items,
    );
  }

  Widget _thumb(SGFileEntry e, int i) {
    final selected = e.file.id == (_selectedId ?? _files.first.file.id);
    final bytes = _bytesFor(e.file);
    return GestureDetector(
      onTap: () {
        _slideshow?.cancel();
        _slideshow = null;
        setState(() => _selectedId = e.file.id);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 64,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: Colors.white, width: 2)
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.1)),
              color: Colors.white.withValues(alpha: 0.06),
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes != null && bytes.isNotEmpty
                ? Image.memory(bytes,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _mimeTile(e.file.mime, 22))
                : _mimeTile(e.file.mime, 22),
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text('${i + 1}',
                style: AppFonts.instrumentSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.45))),
          ),
        ],
      ),
    );
  }

  Widget _mimeTile(String mime, double iconSize) {
    return Center(
      child: Icon(_mimeIcon(mime),
          size: iconSize, color: Colors.white.withValues(alpha: 0.5)),
    );
  }

  // ---------------- stage ----------------

  Widget _stage(List<SGFileEntry> files) {
    final s = _selected;
    if (s == null) return const SizedBox.shrink();
    final idx = files.indexWhere((e) => e.file.id == s.file.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Eyebrow row (viewer recipe): kind + position … size.
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
            child: Row(
              children: [
                Flexible(
                  child: Text('${_kindLabel(s.file.mime)} · ${idx + 1} of ${files.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.instrumentSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: Colors.white.withValues(alpha: 0.5))),
                ),
                const SizedBox(width: 8),
                Text(_fmtSize(s.file.sizeBytes),
                    style: AppFonts.instrumentSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.5))),
              ],
            ),
          ),
          Expanded(child: _previewBody(s)),
          const SizedBox(height: 10),
          // Metadata strip: inline rename + attachment source.
          Row(
            children: [
              Expanded(
                child: _renaming
                    ? TextField(
                        controller: _renameCtrl,
                        autofocus: true,
                        style: AppFonts.instrumentSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _commitRename(),
                        onTapOutside: (_) => _commitRename(),
                      )
                    : GestureDetector(
                        onTap: () {
                          _renameCtrl.text = s.file.name;
                          setState(() => _renaming = true);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Text(s.file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.instrumentSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(SGGlass.rPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.style_rounded,
                          size: 11, color: Colors.white60),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text('in ${s.card.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.instrumentSans(
                                fontSize: 11, color: Colors.white60)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewBody(SGFileEntry s, {bool large = false}) {
    final bytes = _bytesFor(s.file);
    if (bytes != null && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.18),
          child: Center(
            child: Transform.scale(
              scale: large ? 1.0 : _zoom,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _docCard(s),
              ),
            ),
          ),
        ),
      );
    }
    return _docCard(s);
  }

  Widget _docCard(SGFileEntry s) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: SGGlass.sysBlue.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(_mimeIcon(s.file.mime),
                  size: 34, color: SGGlass.sysBlue),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(s.file.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.instrumentSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
            const SizedBox(height: 6),
            Text('${_kindLabel(s.file.mime)} · ${_fmtSize(s.file.sizeBytes)}',
                style: AppFonts.instrumentSans(
                    fontSize: 12, color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  // ---------------- grid ----------------

  Widget _gridBody(List<SGFileEntry> files) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.86,
      ),
      itemCount: files.length,
      itemBuilder: (ctx, i) {
        final e = files[i];
        final bytes = _bytesFor(e.file);
        return GestureDetector(
          onTap: () => setState(() {
            _selectedId = e.file.id;
            _gridMode = false;
          }),
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1)),
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: bytes != null && bytes.isNotEmpty
                      ? Image.memory(bytes,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _mimeTile(e.file.mime, 26))
                      : _mimeTile(e.file.mime, 26),
                ),
              ),
              const SizedBox(height: 4),
              Text(e.file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.instrumentSans(
                      fontSize: 10.5, color: Colors.white70)),
            ],
          ),
        );
      },
    );
  }
  }

