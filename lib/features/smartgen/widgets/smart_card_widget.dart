import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:collider_flutter/core/theme/app_fonts.dart';
import '../theme/smartgen_glass.dart';
import '../models/smartgen_models.dart';
import '../state/smartgen_store.dart';
import 'sg_menu.dart';
import 'smartgen_icons.dart';

/// A Smart Card: physical object on a board or inside a canvas.
/// - Tap any field to edit it inline, at its location on the card.
/// - Cards with hidden fields flip 180° (3D) to reveal them on the back.
/// - Urgent cards with a due date show a live HH:MM:SS countdown.
/// - Long-press (hold, release without moving) opens the card menu.
/// - In kanban mode the card is a LongPressDraggable; in freeform mode the
///   parent moves it via [onMove] pan deltas.
///
/// Skinned on the kit's light frosted card (Widgets Board recipe):
/// white-gradient glass, white edge stroke, dark ink content — the same
/// material as the kanban cards.
class SmartCardWidget extends StatefulWidget {
  final SmartCard card;
  final ComponentTemplate? template;
  final SmartGenStore store;
  final bool kanbanMode;
  final ValueChanged<Offset>? onMove; // freeform pan delta
  final double width;

  /// Jump-to-card for embedded-card chips and search results.
  final ValueChanged<String>? onJumpToCard;

  const SmartCardWidget({
    super.key,
    required this.card,
    required this.template,
    required this.store,
    this.kanbanMode = true,
    this.onMove,
    this.width = 264,
    this.onJumpToCard,
  });

  @override
  State<SmartCardWidget> createState() => _SmartCardWidgetState();
}

class _SmartCardWidgetState extends State<SmartCardWidget>
    with TickerProviderStateMixin {
  late AnimationController _flip;
  late AnimationController _pulse; // urgent badge pulse (spec §20)
  bool _flipped = false;
  bool _editingTitle = false;
  bool _fieldsEditMode = false;
  bool _showTemplateUpdatePrompt = false;
  String? _editingFieldId; // value editing
  String? _addingFieldLabel; // inline add-field row state (null = hidden)
  String? _openSection; // 'details' | 'attach' | 'embed' | 'triggers'
  late TextEditingController _titleCtrl;
  late TextEditingController _assigneeCtrl;
  late TextEditingController _tagCtrl;
  Timer? _ticker;
  // Kanban hold-press vs drag disambiguation.
  Offset? _dragStartOffset;
  double _dragDistance = 0;

  SmartCard get card => widget.card;
  ComponentTemplate? get tpl => widget.template;
  SmartGenStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520));
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _titleCtrl = TextEditingController(text: card.title);
    _assigneeCtrl = TextEditingController(text: card.assignee);
    _tagCtrl = TextEditingController();
    _armTicker();
  }

  @override
  void didUpdateWidget(covariant SmartCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.title != card.title && !_editingTitle) {
      _titleCtrl.text = card.title;
    }
    if (oldWidget.card.assignee != card.assignee &&
        _assigneeCtrl.text != card.assignee) {
      _assigneeCtrl.text = card.assignee;
    }
    _armTicker();
  }

  void _armTicker() {
    _ticker?.cancel();
    if (card.urgent && card.dueAt != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
    // The urgent pulse runs only while the card is urgent — a perpetually
    // repeating ticker on every card would keep pumpAndSettle (and the
    // GPU) busy forever.
    if (card.urgent) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    _pulse.dispose();
    _titleCtrl.dispose();
    _assigneeCtrl.dispose();
    _tagCtrl.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  bool get _isEditing =>
      _editingTitle || _editingFieldId != null || _fieldsEditMode;

  void _toggleFlip() {
    setState(() => _flipped = !_flipped);
    if (_flipped) {
      _flip.forward();
    } else {
      _flip.reverse();
    }
  }

  // ---------------- menu ----------------

  void _showMenu(Offset at) {
    SGMenu.show(
      context,
      at: at,
      items: [
        SGMenuItem(
          icon: Icons.title_rounded,
          label: 'Edit title',
          onTap: () => setState(() => _editingTitle = true),
        ),
        SGMenuItem(
          icon: Icons.tune_rounded,
          label: 'Edit fields',
          onTap: () => setState(() => _fieldsEditMode = true),
        ),
        SGMenuItem(
          icon: card.urgent
              ? Icons.notifications_off_outlined
              : Icons.notifications_active_outlined,
          label: card.urgent ? 'Clear urgent' : 'Mark urgent',
          onTap: () {
            card.urgent = !card.urgent;
            store.updateCard(card);
          },
        ),
        SGMenuItem(
          icon: Icons.event_rounded,
          label: 'Set due date',
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: card.dueAt ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              card.dueAt = picked;
              store.updateCard(card);
            }
          },
        ),
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

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final body = SizedBox(
      width: widget.width,
      child: AnimatedBuilder(
        animation: _flip,
        builder: (_, __) {
          final angle = _flip.value * pi;
          final showBack = angle > pi / 2;
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: showBack
                ? Transform(
                    transform: Matrix4.rotationY(pi),
                    alignment: Alignment.center,
                    child: _buildBack(),
                  )
                : _buildFront(),
          );
        },
      ),
    );

    if (widget.kanbanMode) {
      return LongPressDraggable<String>(
        data: 'card:${card.id}',
        delay: const Duration(milliseconds: 280),
        feedback: Material(
            color: Colors.transparent,
            child: Opacity(opacity: 0.92, child: body)),
        childWhenDragging: Opacity(opacity: 0.25, child: body),
        onDragStarted: () {
          _dragStartOffset = null; // captured on first update
          _dragDistance = 0;
        },
        onDragUpdate: (details) {
          _dragStartOffset ??= details.globalPosition;
          _dragDistance = (details.globalPosition - _dragStartOffset!).distance;
        },
        onDragEnd: (details) {
          // Hold + release without moving = the standard hold-press menu.
          if (_dragDistance < 12) _showMenu(details.offset);
          _dragDistance = 0;
          _dragStartOffset = null;
        },
        child: body,
      );
    }
    // Freeform: the card itself is the drag surface (pan), menu on long-press.
    return GestureDetector(
      onPanUpdate: _isEditing ? null : (d) => widget.onMove?.call(d.delta),
      onLongPressStart: (d) => _showMenu(d.globalPosition),
      child: body,
    );
  }

  // ---------------- front ----------------

  Widget _buildFront() {
    final accent = _accentColor();
    return GlassPanel.card(
      child: Container(
        // Spec §1 / master §7.3: the card's color washes the FULL surface as
        // a soft optical gradient — not a left stripe — while the frosted
        // glass skin and dark-ink legibility are preserved.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SGGlass.rCard - 1),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.34),
              accent.withValues(alpha: 0.16),
              accent.withValues(alpha: 0.07),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(13, 11, 9, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTitleRow(),
            if (card.urgent && card.dueAt != null) _buildCountdown(),
            const SizedBox(height: 4),
            ..._visibleFields(),
            if (_fieldsEditMode) _buildFieldsEditor(),
            _buildSectionToggles(),
            if (_openSection == 'details') _buildDetailsSection(),
            if (_openSection == 'attach') _buildAttachmentsSection(),
            if (_openSection == 'embed') _buildEmbedsSection(),
            if (_openSection == 'triggers') _buildTriggersSection(),
          ],
        ),
      ),
    );
  }

  /// Collapsible inline sections (spec §3 as amended: no modal — every
  /// field group lives on the card itself).
  Widget _buildSectionToggles() {
    final items = [
      (
        'details',
        Icons.person_outline_rounded,
        'Details',
        card.assignee.isNotEmpty || card.dueAt != null || card.tags.isNotEmpty
      ),
      (
        'attach',
        Icons.attach_file_rounded,
        'Files',
        card.attachments.isNotEmpty
      ),
      (
        'embed',
        Icons.layers_outlined,
        'Embedded',
        card.embeddedCardIds.isNotEmpty
      ),
      ('triggers', Icons.bolt_outlined, 'Triggers', card.triggers.isNotEmpty),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (key, icon, label, has) in items)
            GlassPressable(
              onTap: () => setState(
                  () => _openSection = _openSection == key ? null : key),
              child: Tooltip(
                message: label,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: _openSection == key
                        ? SGGlass.ink
                        : (has
                            ? const Color(0x14000000)
                            : const Color(0x08000000)),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0x1A000000), width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                          size: 12,
                          color: _openSection == key
                              ? Colors.white
                              : SGGlass.ink2),
                      const SizedBox(width: 5),
                      Text(label,
                          style: AppFonts.instrumentSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _openSection == key
                                  ? Colors.white
                                  : SGGlass.ink2)),
                      if (has && key == 'attach')
                        Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Text('${card.attachments.length}',
                              style: AppFonts.instrumentSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _openSection == key
                                      ? Colors.white70
                                      : SGGlass.ink3)),
                        ),
                      if (has && key == 'embed')
                        Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Text('${card.embeddedCardIds.length}',
                              style: AppFonts.instrumentSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _openSection == key
                                      ? Colors.white70
                                      : SGGlass.ink3)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- inline sections (spec §3/§16/§18/§19) ----------------

  Widget _sectionShell(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x14000000), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppFonts.instrumentSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: SGGlass.ink3,
                  letterSpacing: 0.4)),
          const SizedBox(height: 7),
          ...children,
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 7, bottom: 3),
        child: Text(text,
            style: AppFonts.instrumentSans(fontSize: 10, color: SGGlass.ink3)),
      );

  // ---- Details: assignee, due date/time, priority, tags (spec §3) ----

  Widget _buildDetailsSection() {
    final history =
        store.fieldHistory(card.templateId, 'assignee').take(4).toList();
    return _sectionShell('Details', [
      _sectionLabel('Assignee'),
      GlassField(
        controller: _assigneeCtrl,
        hintText: 'Who owns this?',
        light: true,
        onSubmitted: (_) => _saveAssignee(),
        onTapOutside: (_) => _saveAssignee(),
      ),
      if (history.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: history
                .map((h) => GlassPressable(
                      onTap: () {
                        _assigneeCtrl.text = h;
                        _saveAssignee();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0x0A000000),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                              color: const Color(0x1A000000), width: 0.5),
                        ),
                        child: Text(h,
                            style: AppFonts.instrumentSans(
                                fontSize: 11, color: SGGlass.ink2)),
                      ),
                    ))
                .toList(),
          ),
        ),
      _sectionLabel('Due date & time'),
      Row(
        children: [
          Expanded(child: _dueButton(isDate: true)),
          const SizedBox(width: 6),
          Expanded(child: _dueButton(isDate: false)),
          if (card.dueAt != null)
            GlassPressable(
              onTap: () => store.setDueAt(card.id, null),
              child: const Tooltip(
                message: 'Clear due date',
                child: Padding(
                  padding: EdgeInsets.all(7),
                  child:
                      Icon(Icons.close_rounded, size: 13, color: SGGlass.ink3),
                ),
              ),
            ),
        ],
      ),
      _sectionLabel('Priority'),
      Wrap(
        spacing: 6,
        children: ['P0', 'P1', 'P2', 'P3'].map((p) {
          final sel = card.priority == p;
          return GlassPressable(
            onTap: () => store.setPriority(card.id, p),
            child: Tooltip(
              message: 'Priority $p',
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? SGGlass.ink : const Color(0x0A000000),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: sel ? Colors.transparent : const Color(0x20000000),
                      width: 0.5),
                ),
                child: Text(p,
                    style: AppFonts.instrumentSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : SGGlass.ink2)),
              ),
            ),
          );
        }).toList(),
      ),
      _sectionLabel('Tags'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          ...card.tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _accentColor().withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: _accentColor().withValues(alpha: 0.4), width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t,
                        style: AppFonts.instrumentSans(
                            fontSize: 11, color: SGGlass.ink)),
                    const SizedBox(width: 5),
                    GlassPressable(
                      onTap: () => store.setTags(
                          card.id, card.tags.where((e) => e != t).toList()),
                      child: const Icon(Icons.close_rounded,
                          size: 11, color: SGGlass.ink3),
                    ),
                  ],
                ),
              )),
          SizedBox(
            width: 110,
            child: GlassField(
              controller: _tagCtrl,
              hintText: '+ tag',
              light: true,
              onSubmitted: (_) => _addTag(),
            ),
          ),
        ],
      ),
    ]);
  }

  void _saveAssignee() {
    final v = _assigneeCtrl.text.trim();
    if (v != card.assignee) store.setAssignee(card.id, v);
  }

  void _addTag() {
    final v = _tagCtrl.text.trim();
    if (v.isEmpty || card.tags.contains(v)) {
      _tagCtrl.clear();
      return;
    }
    store.setTags(card.id, [...card.tags, v]);
    _tagCtrl.clear();
  }

  Widget _dueButton({required bool isDate}) {
    final due = card.dueAt;
    final label = due == null
        ? (isDate ? 'Set date' : 'Set time')
        : isDate
            ? '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}'
            : '${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}';
    return GlassPressable(
      onTap: () => _pickDue(isDate: isDate),
      child: Tooltip(
        message: isDate ? 'Due date' : 'Due time',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x0A000000),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x14000000), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isDate ? Icons.event_rounded : Icons.schedule_rounded,
                  size: 13, color: SGGlass.ink3),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.instrumentSans(
                        fontSize: 12, color: SGGlass.ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDue({required bool isDate}) async {
    final now = DateTime.now();
    final current = card.dueAt ?? now;
    if (isDate) {
      final picked = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        store.setDueAt(
            card.id,
            DateTime(picked.year, picked.month, picked.day, current.hour,
                current.minute));
      }
    } else {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (picked != null) {
        store.setDueAt(
            card.id,
            DateTime(current.year, current.month, current.day, picked.hour,
                picked.minute));
      }
    }
  }

  // ---- Attachments (spec §19) ----

  Widget _buildAttachmentsSection() {
    return _sectionShell('Attachments', [
      if (card.attachments.isEmpty)
        Text('No files yet.',
            style:
                AppFonts.instrumentSans(fontSize: 11.5, color: SGGlass.ink3)),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: card.attachments
            .map((a) => _AttachmentTile(
                  attachment: a,
                  onDelete: () => store.removeAttachment(card.id, a.id),
                ))
            .toList(),
      ),
      const SizedBox(height: 8),
      GlassPressable(
        onTap: _pickFiles,
        child: Tooltip(
          message: 'Attach files',
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x1A000000), width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, size: 13, color: SGGlass.ink3),
                const SizedBox(width: 5),
                Text('Attach files',
                    style: AppFonts.instrumentSans(
                        fontSize: 11.5, color: SGGlass.ink3)),
              ],
            ),
          ),
        ),
      ),
    ]);
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result == null) return;
      var skipped = 0;
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null) {
          skipped++;
          continue;
        }
        if (bytes.length > 2 * 1024 * 1024) {
          skipped++; // keep the persisted payload lean
          continue;
        }
        final mime = _guessMime(f.name, f.extension);
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
      if (skipped > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '$skipped file${skipped == 1 ? '' : 's'} skipped (over 2 MB).'),
            behavior: SnackBarBehavior.floating));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open the file picker.'),
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  String _guessMime(String name, String? ext) {
    final e = (ext ?? name.split('.').last).toLowerCase();
    return switch (e) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'md' => 'text/markdown',
      _ => 'application/octet-stream',
    };
  }

  // ---- Embedded cards (spec §16) ----

  Widget _buildEmbedsSection() {
    final others = store
        .boardCards(card.boardId)
        .where((c) => c.id != card.id && !card.embeddedCardIds.contains(c.id))
        .take(8)
        .toList();
    return _sectionShell('Embedded cards', [
      if (card.embeddedCardIds.isEmpty && others.isEmpty)
        Text('No other cards on this board yet.',
            style:
                AppFonts.instrumentSans(fontSize: 11.5, color: SGGlass.ink3)),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: card.embeddedCardIds.map((id) {
          final target = store.card(id);
          if (target == null) return const SizedBox.shrink();
          return GlassPressable(
            onTap: () => widget.onJumpToCard?.call(id),
            child: Tooltip(
              message: 'Open ${target.title}',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x0A000000),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0x20000000), width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.layers_outlined,
                        size: 11, color: SGGlass.ink3),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(target.title,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.instrumentSans(
                              fontSize: 11, color: SGGlass.ink)),
                    ),
                    const SizedBox(width: 5),
                    GlassPressable(
                      onTap: () => store.unembedCard(card.id, id),
                      child: const Tooltip(
                        message: 'Remove embed',
                        child: Icon(Icons.close_rounded,
                            size: 11, color: SGGlass.ink3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
      if (others.isNotEmpty) ...[
        _sectionLabel('Embed a card'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: others
              .map((o) => GlassPressable(
                    onTap: () => store.embedCard(card.id, o.id),
                    child: Tooltip(
                      message: 'Embed ${o.title}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0x1A000000), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded,
                                size: 11, color: SGGlass.ink3),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(o.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.instrumentSans(
                                      fontSize: 11, color: SGGlass.ink2)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    ]);
  }

  // ---- Triggers (spec §18) ----

  Widget _buildTriggersSection() {
    return _sectionShell('Triggers', [
      _triggerRow('done_final', 'Mark done → set status to final',
          'When this card reads Done, pin it to the last column.'),
      _triggerRow('hourly_progress', 'Auto-progress status hourly',
          'Advance one column each hour while the workspace is open.'),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Inherit column status',
                      style: AppFonts.instrumentSans(
                          fontSize: 12, color: SGGlass.ink)),
                  Text('Update status to match the column on drop.',
                      style: AppFonts.instrumentSans(
                          fontSize: 10.5, color: SGGlass.ink3)),
                ],
              ),
            ),
            Switch.adaptive(
              value: card.inheritStatus,
              activeThumbColor: SGGlass.sysBlue,
              onChanged: (v) => store.setInheritStatus(card.id, v),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _triggerRow(String flag, String title, String subtitle) {
    final on = card.triggers.contains(flag);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppFonts.instrumentSans(
                        fontSize: 12, color: SGGlass.ink)),
                Text(subtitle,
                    style: AppFonts.instrumentSans(
                        fontSize: 10.5, color: SGGlass.ink3)),
              ],
            ),
          ),
          Switch.adaptive(
            value: on,
            activeThumbColor: SGGlass.sysBlue,
            onChanged: (_) => store.toggleTrigger(card.id, flag),
          ),
        ],
      ),
    );
  }

  Color _accentColor() {
    final raw = tpl?.settings['accent'] as String?;
    if (raw == null) return const Color(0xFF64FFDA);
    try {
      return Color(int.parse(raw));
    } catch (_) {
      return const Color(0xFF64FFDA);
    }
  }

  Widget _buildTitleRow() {
    final tint = _accentColor();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tpl != null)
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 7),
            child: Icon(smartGenIcon(tpl!.iconName), size: 14, color: tint),
          ),
        Expanded(
          child: _editingTitle
              ? GlassField(
                  controller: _titleCtrl,
                  autofocus: true,
                  light: true,
                  style: AppFonts.instrumentSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: SGGlass.ink,
                      letterSpacing: -0.2),
                  onSubmitted: (_) => _saveTitle(),
                  onTapOutside: (_) => _saveTitle(),
                )
              : GestureDetector(
                  onTap: () => setState(() => _editingTitle = true),
                  behavior: HitTestBehavior.opaque,
                  child: Text(card.title,
                      style: AppFonts.instrumentSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: SGGlass.ink,
                          letterSpacing: -0.2)),
                ),
        ),
        if (card.hiddenFieldIds.isNotEmpty)
          GlassPressable(
            onTap: _toggleFlip,
            child: const Padding(
              padding: EdgeInsets.all(5),
              child: Icon(Icons.flip_rounded, size: 13, color: SGGlass.ink3),
            ),
          ),
        if (card.urgent)
          Tooltip(
            message: card.urgent ? 'Urgent' : '',
            child: Padding(
              padding: const EdgeInsets.only(top: 6, right: 2),
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SGGlass.sysRed
                        .withValues(alpha: 0.55 + 0.45 * _pulse.value),
                    boxShadow: [
                      BoxShadow(
                        color: SGGlass.sysRed
                            .withValues(alpha: 0.5 * _pulse.value),
                        blurRadius: 6 * _pulse.value,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        GestureDetector(
          onTapDown: (d) => _showMenu(d.globalPosition),
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(5),
            child:
                Icon(Icons.more_horiz_rounded, size: 15, color: SGGlass.ink3),
          ),
        ),
      ],
    );
  }

  void _saveTitle() {
    final v = _titleCtrl.text.trim();
    if (v.isNotEmpty) {
      card.title = v;
      store.updateCard(card);
    } else {
      _titleCtrl.text = card.title;
    }
    setState(() => _editingTitle = false);
  }

  Widget _buildCountdown() {
    final diff = card.dueAt!.difference(DateTime.now());
    final overdue = diff.isNegative;
    final d = overdue ? -diff : diff;
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    final hot = overdue || d.inHours < 1;
    return Container(
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: hot
            ? SGGlass.sysRed.withValues(alpha: 0.10)
            : const Color(0x0A000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: hot
                ? SGGlass.sysRed.withValues(alpha: 0.45)
                : const Color(0x14000000),
            width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined,
              size: 12, color: hot ? SGGlass.sysRed : SGGlass.ink3),
          const SizedBox(width: 6),
          Text(
            overdue ? 'OVERDUE $hh:$mm:$ss' : '$hh:$mm:$ss',
            style: AppFonts.instrumentSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: hot ? SGGlass.sysRed : SGGlass.ink2,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _visibleFields() {
    final t = tpl;
    if (t == null) return [];
    return t.fields
        .where((f) => !card.hiddenFieldIds.contains(f.id))
        .map((f) => _InlineFieldRow(
              key: ValueKey('${card.id}_${f.id}'),
              field: f,
              value: card.values[f.id],
              editing: _editingFieldId == f.id,
              editMode: _fieldsEditMode,
              store: store,
              card: card,
              template: t,
              onTap: () => setState(() => _editingFieldId = f.id),
              onDone: () => setState(() => _editingFieldId = null),
            ))
        .toList();
  }

  Widget _buildFieldsEditor() {
    final t = tpl!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        if (_addingFieldLabel == null)
          GlassPressable(
            onTap: () => setState(() => _addingFieldLabel = ''),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x1A000000), width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, size: 13, color: SGGlass.ink3),
                  const SizedBox(width: 5),
                  Text('Add field',
                      style: AppFonts.instrumentSans(
                          fontSize: 11.5, color: SGGlass.ink3)),
                ],
              ),
            ),
          )
        else
          _AddFieldRow(
            onCancel: () => setState(() => _addingFieldLabel = null),
            onAdd: (label, kind) {
              store.addField(t.id,
                  label.trim().isEmpty ? 'New field' : label.trim(), kind);
              setState(() => _addingFieldLabel = null);
            },
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GlassPressable(
                onTap: () => setState(() => _fieldsEditMode = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x0F000000),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text('Done',
                      style: AppFonts.instrumentSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: SGGlass.ink2)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GlassPressable(
                onTap: () {
                  setState(() => _showTemplateUpdatePrompt = true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SGGlass.ink,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text('Update',
                      style: AppFonts.instrumentSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
        if (_showTemplateUpdatePrompt) _buildTemplateUpdatePrompt(t),
      ],
    );
  }

  /// Inline "update deployed instances too?" prompt.
  Widget _buildTemplateUpdatePrompt(ComponentTemplate t) {
    final kindLabel = {
      'card': 'cards',
      'canvas': 'canvases',
      'board': 'boards'
    }[t.kind.name]!;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SGGlass.ink.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Update all deployed $kindLabel too?',
              style: AppFonts.instrumentSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SGGlass.ink)),
          const SizedBox(height: 4),
          Text(
            'No = only the template changes. Yes = every deployed $kindLabel of this type gets the latest configuration.',
            style: AppFonts.instrumentSans(
                fontSize: 11.5, color: SGGlass.ink3, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GlassPressable(
                  onTap: () {
                    setState(() {
                      _showTemplateUpdatePrompt = false;
                      _fieldsEditMode = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x0F000000),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text('No, template only',
                        style: AppFonts.instrumentSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: SGGlass.ink2)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassPressable(
                  onTap: () {
                    store.applyTemplateToInstances(t.id);
                    setState(() {
                      _showTemplateUpdatePrompt = false;
                      _fieldsEditMode = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: SGGlass.ink,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text('Yes, update all',
                        style: AppFonts.instrumentSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- back (hidden fields) ----------------

  Widget _buildBack() {
    final t = tpl;
    final hidden =
        t?.fields.where((f) => card.hiddenFieldIds.contains(f.id)).toList() ??
            [];
    return GlassPanel.card(
      padding: const EdgeInsets.fromLTRB(13, 11, 9, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_off_outlined,
                  size: 13, color: SGGlass.ink3),
              const SizedBox(width: 6),
              Text('Hidden fields',
                  style: AppFonts.instrumentSans(
                      fontSize: 11.5, color: SGGlass.ink3)),
              const Spacer(),
              GlassPressable(
                onTap: _toggleFlip,
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child:
                      Icon(Icons.flip_rounded, size: 13, color: SGGlass.ink3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (hidden.isEmpty)
            Text('Nothing hidden.',
                style:
                    AppFonts.instrumentSans(fontSize: 12, color: SGGlass.ink3)),
          ...hidden.map((f) => Opacity(
                opacity: 0.55,
                child: Row(
                  children: [
                    Expanded(
                      child: _InlineFieldRow(
                        field: f,
                        value: card.values[f.id],
                        editing: _editingFieldId == f.id,
                        editMode: false,
                        store: store,
                        card: card,
                        template: t!,
                        onTap: () => setState(() => _editingFieldId = f.id),
                        onDone: () => setState(() => _editingFieldId = null),
                      ),
                    ),
                    GlassPressable(
                      onTap: () {
                        store.setFieldHidden(card.id, f.id, false);
                        if (card.hiddenFieldIds.isEmpty) _toggleFlip();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(Icons.visibility_outlined,
                            size: 13, color: SGGlass.ink3),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

/// One field row: label + value. Tap to edit inline with the field's control.
class _InlineFieldRow extends StatefulWidget {
  final FieldDef field;
  final dynamic value;
  final bool editing;
  final bool editMode; // template-edit affordances visible
  final SmartGenStore store;
  final SmartCard card;
  final ComponentTemplate template;
  final VoidCallback onTap;
  final VoidCallback onDone;

  const _InlineFieldRow({
    super.key,
    required this.field,
    required this.value,
    required this.editing,
    required this.editMode,
    required this.store,
    required this.card,
    required this.template,
    required this.onTap,
    required this.onDone,
  });

  @override
  State<_InlineFieldRow> createState() => _InlineFieldRowState();
}

class _InlineFieldRowState extends State<_InlineFieldRow> {
  late TextEditingController _ctrl;
  bool _showNewOption = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _displayValue());
  }

  @override
  void didUpdateWidget(covariant _InlineFieldRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.editing && oldWidget.editing) {
      _ctrl.text = _displayValue();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _displayValue() => widget.value?.toString() ?? '';

  void _save(dynamic v) {
    widget.store.setFieldValue(widget.card.id, widget.field.id, v);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.editMode) return _buildEditModeRow();
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.field.label,
              style:
                  AppFonts.instrumentSans(fontSize: 10, color: SGGlass.ink3)),
          const SizedBox(height: 2),
          widget.editing ? _buildEditor() : _buildViewer(),
        ],
      ),
    );
  }

  Widget _buildViewer() {
    final f = widget.field;
    Widget content;
    switch (f.kind) {
      case FieldKind.toggle:
        final on = widget.value == true || widget.value == 'true';
        content = Text(on ? 'On' : 'Off',
            style: AppFonts.instrumentSans(
                fontSize: 12.5, color: on ? SGGlass.ink : SGGlass.ink3));
        break;
      case FieldKind.color:
        content = Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _parseColor(widget.value) ?? const Color(0x14000000),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0x28000000), width: 0.5),
              ),
            ),
            const SizedBox(width: 7),
            Text(_displayValue().isEmpty ? 'No color' : _displayValue(),
                style: AppFonts.instrumentSans(
                    fontSize: 12.5, color: SGGlass.ink, height: 1.4)),
          ],
        );
        break;
      case FieldKind.date:
        content = Text(
            _displayValue().isEmpty
                ? 'No date'
                : _displayValue().split(' ').first,
            style: AppFonts.instrumentSans(
                fontSize: 12.5, color: SGGlass.ink, height: 1.4));
        break;
      case FieldKind.time:
        content = Text(_displayValue().isEmpty ? 'No time' : _displayValue(),
            style: AppFonts.instrumentSans(
                fontSize: 12.5, color: SGGlass.ink, height: 1.4));
        break;
      case FieldKind.datetime:
        content = Text(
            _displayValue().isEmpty
                ? 'No date/time'
                : _displayValue().replaceAll('T', ' ').split('.').first,
            style: AppFonts.instrumentSans(
                fontSize: 12.5, color: SGGlass.ink, height: 1.4));
        break;
      default:
        final text = _displayValue();
        content = Text(
          text.isEmpty ? '—' : text,
          style: AppFonts.instrumentSans(
              fontSize: 12.5,
              color: text.isEmpty ? SGGlass.ink3 : SGGlass.ink,
              height: 1.4),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        );
    }
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: content,
      ),
    );
  }

  Widget _buildEditor() {
    final f = widget.field;
    switch (f.kind) {
      case FieldKind.toggle:
        final on = widget.value == true || widget.value == 'true';
        return Align(
          alignment: Alignment.centerLeft,
          child: Switch.adaptive(
            value: on,
            activeThumbColor: SGGlass.sysBlue,
            onChanged: (v) => _save(v),
          ),
        );
      case FieldKind.dropdown:
        return _buildDropdownEditor();
      case FieldKind.date:
        return _buildDateEditor();
      case FieldKind.time:
        return _buildTimeEditor();
      case FieldKind.datetime:
        return _buildDateTimeEditor();
      case FieldKind.color:
        return _buildColorEditor();
      case FieldKind.number:
        return _buildTextEditor(TextInputType.number);
      default:
        final label = f.label.toLowerCase();
        final multiline = label.contains('descript') ||
            label.contains('notes') ||
            label.contains('body') ||
            label.contains('content') ||
            label.contains('entry');
        return _buildTextEditor(
            multiline ? TextInputType.multiline : TextInputType.text,
            multiline: multiline);
    }
  }

  Widget _buildTextEditor(TextInputType kb, {bool multiline = false}) {
    // Spec §4: suggest previously used values above the input.
    final history = widget.store
        .fieldHistory(widget.template.id, widget.field.label)
        .where((h) => h != _ctrl.text)
        .take(4)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (history.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: history
                  .map((h) => GlassPressable(
                        onTap: () {
                          _ctrl.text = h;
                          _save(h);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0x0A000000),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: const Color(0x1A000000), width: 0.5),
                          ),
                          child: Text(h,
                              style: AppFonts.instrumentSans(
                                  fontSize: 11, color: SGGlass.ink2)),
                        ),
                      ))
                  .toList(),
            ),
          ),
        GlassField(
          controller: _ctrl,
          autofocus: true,
          light: true,
          keyboardType: kb,
          maxLines: multiline ? 4 : 1,
          minLines: multiline ? 2 : 1,
          onSubmitted: (_) => _save(_ctrl.text.trim()),
          onTapOutside: (_) => _save(_ctrl.text.trim()),
        ),
      ],
    );
  }

  /// Spec §4: "+ Add new…" persists the option on the field, feeds the
  /// value history, and — for the Status field — creates a real kanban
  /// column on the board.
  void _saveNewOption(String raw) {
    final v = raw.trim();
    if (v.isEmpty) {
      widget.onDone();
      return;
    }
    final f = widget.field;
    if (!f.options.contains(v)) {
      final updated = f.copy()..options = [...f.options, v];
      widget.store.updateField(widget.template.id, updated);
    }
    widget.store.recordFieldHistory(widget.template.id, f.label, v);
    if (f.label.toLowerCase() == 'status') {
      widget.store.addBoardColumn(widget.card.boardId, v);
    }
    _save(v);
  }

  Widget _buildDropdownEditor() {
    final f = widget.field;
    final current = _displayValue();
    // Spec §4: history values not yet options are suggested too.
    final history = widget.store
        .fieldHistory(widget.template.id, f.label)
        .where((h) => !f.options.contains(h))
        .take(3)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...f.options.map((opt) {
              final sel = opt == current;
              return GlassPressable(
                onTap: () => _save(opt),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? SGGlass.ink : const Color(0x0A000000),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            sel ? Colors.transparent : const Color(0x20000000),
                        width: 0.5),
                  ),
                  child: Text(opt,
                      style: AppFonts.instrumentSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : SGGlass.ink2)),
                ),
              );
            }),
            ...history.map((h) => GlassPressable(
                  onTap: () => _saveNewOption(h),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: SGGlass.sysBlue.withValues(alpha: 0.5),
                          width: 0.5),
                    ),
                    child: Text(h,
                        style: AppFonts.instrumentSans(
                            fontSize: 11.5, color: SGGlass.ink2)),
                  ),
                )),
            GlassPressable(
              onTap: () => setState(() => _showNewOption = !_showNewOption),
              child: Tooltip(
                message: 'Add new option',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0x20000000), width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 12, color: SGGlass.ink3),
                      const SizedBox(width: 4),
                      Text('+ Add new…',
                          style: AppFonts.instrumentSans(
                              fontSize: 11, color: SGGlass.ink3)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_showNewOption)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _NewOptionRow(
              onSubmit: _saveNewOption,
              onCancel: () => setState(() => _showNewOption = false),
            ),
          ),
      ],
    );
  }

  Widget _buildDateEditor() {
    return GlassPressable(
      onTap: () async {
        DateTime initial;
        try {
          initial = DateTime.parse(_displayValue());
        } catch (_) {
          initial = DateTime.now();
        }
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          _save(
              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
        } else {
          widget.onDone();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x0A000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x14000000), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_rounded, size: 13, color: SGGlass.ink3),
            const SizedBox(width: 6),
            Text(
                _displayValue().isEmpty
                    ? 'Pick a date'
                    : _displayValue().split(' ').first,
                style: AppFonts.instrumentSans(
                    fontSize: 12.5, color: SGGlass.ink, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeEditor() {
    return GlassPressable(
      onTap: () async {
        TimeOfDay initial;
        try {
          final parts = _displayValue().split(':');
          initial =
              TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        } catch (_) {
          initial = TimeOfDay.now();
        }
        final picked = await showTimePicker(
          context: context,
          initialTime: initial,
        );
        if (picked != null) {
          _save(
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        } else {
          widget.onDone();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x0A000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x14000000), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, size: 13, color: SGGlass.ink3),
            const SizedBox(width: 6),
            Text(_displayValue().isEmpty ? 'Pick a time' : _displayValue(),
                style: AppFonts.instrumentSans(
                    fontSize: 12.5, color: SGGlass.ink, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeEditor() {
    return GlassPressable(
      onTap: () async {
        DateTime initial;
        try {
          initial = DateTime.parse(_displayValue());
        } catch (_) {
          initial = DateTime.now();
        }
        final date = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date == null) {
          widget.onDone();
          return;
        }
        if (!mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(initial),
        );
        if (time == null) {
          widget.onDone();
          return;
        }
        _save(DateTime(date.year, date.month, date.day, time.hour, time.minute)
            .toIso8601String());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x0A000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x14000000), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_rounded, size: 13, color: SGGlass.ink3),
            const SizedBox(width: 6),
            Text(
                _displayValue().isEmpty
                    ? 'Pick date & time'
                    : _displayValue().replaceAll('T', ' ').split('.').first,
                style: AppFonts.instrumentSans(
                    fontSize: 12.5, color: SGGlass.ink, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildColorEditor() {
    const swatches = [
      0xFF64FFDA,
      0xFF7CC4FF,
      0xFFB79CFF,
      0xFFFFB3C7,
      0xFFFFD28F,
      0xFF9DFF9D,
      0xFFFFFFFF,
      0xFF1A1B1E,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: swatches.map((hex) {
        final sel = _displayValue() == hex.toString();
        return GlassPressable(
          onTap: () => _save(hex.toString()),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Color(hex),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: sel ? SGGlass.ink : const Color(0x28000000),
                  width: sel ? 1.5 : 0.5),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color? _parseColor(dynamic v) {
    try {
      return Color(int.parse(v.toString()));
    } catch (_) {
      return null;
    }
  }

  // -------- template-level field editing (inline on the card) --------

  Widget _buildEditModeRow() {
    final f = widget.field;
    final store = widget.store;
    final t = widget.template;
    return Container(
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x0A000000),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x14000000), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(f.label,
                    style: AppFonts.instrumentSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SGGlass.ink)),
              ),
              _editBtn(
                f.required ? Icons.star_rounded : Icons.star_outline_rounded,
                f.required ? SGGlass.ink : SGGlass.ink3,
                () {
                  final updated = f.copy()..required = !f.required;
                  store.updateField(t.id, updated);
                },
              ),
              _editBtn(Icons.visibility_off_outlined, SGGlass.ink3, () {
                store.setFieldHidden(widget.card.id, f.id, true);
              }),
              _editBtn(Icons.delete_outline_rounded, SGGlass.ink3, () {
                store.removeField(t.id, f.id);
              }),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: FieldKind.values.map((k) {
                final sel = k == f.kind;
                return Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: GlassPressable(
                    onTap: () {
                      final updated = f.copy()..kind = k;
                      store.updateField(t.id, updated);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: sel ? SGGlass.ink : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                            color: sel
                                ? Colors.transparent
                                : const Color(0x20000000),
                            width: 0.5),
                      ),
                      child: Text(k.name,
                          style: AppFonts.instrumentSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : SGGlass.ink3)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editBtn(IconData icon, Color color, VoidCallback onTap) {
    return GlassPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, size: 13, color: color),
      ),
    );
  }
}

/// Inline "new custom field" row used while editing a template on the card.
class _AddFieldRow extends StatefulWidget {
  final VoidCallback onCancel;
  final void Function(String label, FieldKind kind) onAdd;
  const _AddFieldRow({required this.onCancel, required this.onAdd});

  @override
  State<_AddFieldRow> createState() => _AddFieldRowState();
}

class _AddFieldRowState extends State<_AddFieldRow> {
  final _ctrl = TextEditingController();
  // Spec §17 custom-field types.
  FieldKind _kind = FieldKind.text;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const kinds = {
      FieldKind.text: 'text',
      FieldKind.number: 'number',
      FieldKind.toggle: 'boolean',
      FieldKind.date: 'date',
      FieldKind.time: 'time',
      FieldKind.datetime: 'datetime',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GlassField(
                controller: _ctrl,
                hintText: 'Custom field name…',
                light: true,
                autofocus: true,
                onSubmitted: (_) => widget.onAdd(_ctrl.text, _kind),
              ),
            ),
            const SizedBox(width: 6),
            GlassPressable(
              onTap: () => widget.onAdd(_ctrl.text, _kind),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SGGlass.ink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_rounded,
                    size: 14, color: Colors.white),
              ),
            ),
            const SizedBox(width: 6),
            GlassPressable(
              onTap: widget.onCancel,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x0F000000),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: SGGlass.ink3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: kinds.entries.map((e) {
            final sel = _kind == e.key;
            return GlassPressable(
              onTap: () => setState(() => _kind = e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? SGGlass.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: sel ? Colors.transparent : const Color(0x20000000),
                      width: 0.5),
                ),
                child: Text(e.value,
                    style: AppFonts.instrumentSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : SGGlass.ink3)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// One attachment tile: image thumbnail, video tile with a player affordance,
/// or icon + name for everything else (spec §19).
class _AttachmentTile extends StatelessWidget {
  final CardAttachment attachment;
  final VoidCallback onDelete;

  const _AttachmentTile({required this.attachment, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: attachment.name,
      child: Stack(
        children: [
          GlassPressable(
            onTap: attachment.isVideo ? () => _playVideo(context) : null,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x20000000), width: 0.5),
                color: const Color(0x0A000000),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: _buildPreview(),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GlassPressable(
              onTap: onDelete,
              child: const Tooltip(
                message: 'Remove attachment',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: Color(0xAA000000), shape: BoxShape.circle),
                  child: Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Icons.close_rounded,
                        size: 10, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final a = attachment;
    if (a.isImage) {
      try {
        final comma = a.dataUrl.indexOf(',');
        final bytes = base64Decode(
            comma >= 0 ? a.dataUrl.substring(comma + 1) : a.dataUrl);
        return Image.memory(bytes,
            fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fileFallback());
      } catch (_) {
        return _fileFallback();
      }
    }
    if (a.isVideo) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0x14000000)),
          const Center(
              child: Icon(Icons.play_circle_outline_rounded,
                  size: 26, color: SGGlass.ink2)),
          Positioned(
            bottom: 4,
            left: 4,
            right: 4,
            child: Text(a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.instrumentSans(
                    fontSize: 8.5, color: SGGlass.ink3)),
          ),
        ],
      );
    }
    return _fileFallback();
  }

  Widget _fileFallback() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.insert_drive_file_outlined,
            size: 22, color: SGGlass.ink3),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(attachment.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style:
                  AppFonts.instrumentSans(fontSize: 8.5, color: SGGlass.ink3)),
        ),
      ],
    );
  }

  void _playVideo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _VideoDialog(dataUrl: attachment.dataUrl),
    );
  }
}

/// Inline video player overlay for a video attachment.
class _VideoDialog extends StatefulWidget {
  final String dataUrl;
  const _VideoDialog({required this.dataUrl});

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  VideoPlayerController? _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.dataUrl));
      await ctrl.initialize();
      await ctrl.play();
      if (mounted) setState(() => _ctrl = ctrl);
    } catch (e) {
      if (mounted) setState(() => _error = 'This video can\u2019t play here.');
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Text(_error!,
                  style: AppFonts.instrumentSans(
                      fontSize: 12.5, color: Colors.white70))
            else if (_ctrl == null)
              const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white54))
            else
              AspectRatio(
                  aspectRatio: _ctrl!.value.aspectRatio,
                  child: VideoPlayer(_ctrl!)),
            const SizedBox(height: 8),
            GlassPressable(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9)),
                child: Text('Close',
                    style: AppFonts.instrumentSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SGGlass.ink)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline "+ Add new…" input row for dropdown options (spec §4).
class _NewOptionRow extends StatefulWidget {
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;
  const _NewOptionRow({required this.onSubmit, required this.onCancel});

  @override
  State<_NewOptionRow> createState() => _NewOptionRowState();
}

class _NewOptionRowState extends State<_NewOptionRow> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GlassField(
            controller: _ctrl,
            hintText: 'New option name…',
            light: true,
            autofocus: true,
            onSubmitted: (_) => widget.onSubmit(_ctrl.text),
          ),
        ),
        const SizedBox(width: 6),
        GlassPressable(
          onTap: () => widget.onSubmit(_ctrl.text),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SGGlass.ink,
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.check_rounded, size: 14, color: Colors.white),
          ),
        ),
        const SizedBox(width: 6),
        GlassPressable(
          onTap: widget.onCancel,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0x0F000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.close_rounded, size: 14, color: SGGlass.ink3),
          ),
        ),
      ],
    );
  }
}
