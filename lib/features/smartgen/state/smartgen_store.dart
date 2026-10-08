import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/smartgen_models.dart';
import '../models/builtin_types.dart';

const _kStoreKey = 'smartgen_store_v1';
const _kGenieKey = 'smartgen_genie_history_v1';

/// Central state for the Smart Gen suite: templates, cards, canvases, boards.
/// Template edits never touch deployed instances until [applyTemplateToInstances]
/// is called (the "update deployed too?" confirmation path).
class SmartGenStore extends ChangeNotifier {
  final Map<String, ComponentTemplate> _templates = {};
  final Map<String, SmartCard> _cards = {};
  final Map<String, SmartCanvas> _canvases = {};
  final Map<String, SmartBoard> _boards = {};
  final Set<String> _hiddenBuiltinIds = {};
  String? _activeBoardId;
  bool _loaded = false;

  /// Spec §4: previously used values per "templateId::fieldLabel", newest first.
  final Map<String, List<String>> _fieldHistory = {};

  /// Spec §7: "cardId:kind" alert keys already toasted, so periodic checks
  /// don't spam. Pruned whenever an alert condition clears.
  final Set<String> _notifiedAlerts = {};

  /// Spec S3: persisted Genie conversation history.
  final List<Map<String, String>> _genieHistory = [];

  static const int maxCards = 999; // spec §21
  static const int maxCanvasesPerBoard = 10; // spec S3

  bool get loaded => _loaded;
  String? get activeBoardId => _activeBoardId;
  SmartBoard? get activeBoard =>
      _activeBoardId != null ? _boards[_activeBoardId] : null;

  List<ComponentTemplate> templatesOf(ComponentKind kind) => _templates.values
      .where((t) => t.kind == kind && !_hiddenBuiltinIds.contains(t.id))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  ComponentTemplate? template(String id) => _templates[id];
  SmartCard? card(String id) => _cards[id];
  SmartCanvas? canvas(String id) => _canvases[id];
  SmartBoard? board(String id) => _boards[id];

  List<SmartBoard> get boards => _boards.values.toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Cards directly on a board (not inside a canvas).
  /// Ordered by the persisted kanban position, then creation time.
  List<SmartCard> boardCards(String boardId, {String? status}) => _cards.values
      .where((c) =>
          c.boardId == boardId &&
          c.canvasId == null &&
          (status == null || c.status == status))
      .toList()
    ..sort((a, b) {
      final o = a.sortOrder.compareTo(b.sortOrder);
      return o != 0 ? o : a.createdAt.compareTo(b.createdAt);
    });

  /// Persist an exact kanban column order (card ids, top to bottom).
  /// Called by the kanban bridge after a drag so the drop position survives
  /// reloads. Ids not currently in the column are ignored.
  void setColumnOrder(String boardId, String status, List<String> orderedIds) {
    var i = 0;
    for (final id in orderedIds) {
      final c = _cards[id];
      if (c == null ||
          c.boardId != boardId ||
          c.canvasId != null ||
          c.status != status) {
        continue;
      }
      c.sortOrder = (i + 1) * 1024.0;
      c.updatedAt = DateTime.now();
      i++;
    }
    _changed();
  }

  /// Next free sort position at the end of a board column.
  double _endOfColumn(String boardId, String status) {
    var max = 0.0;
    for (final c in _cards.values) {
      if (c.boardId == boardId && c.canvasId == null && c.status == status) {
        if (c.sortOrder > max) max = c.sortOrder;
      }
    }
    return max + 1024.0;
  }

  List<SmartCard> canvasCards(String canvasId) {
    final cv = _canvases[canvasId];
    if (cv == null) return [];
    return cv.cardIds.map((id) => _cards[id]).whereType<SmartCard>().toList();
  }

  List<SmartCanvas> boardCanvases(String boardId) =>
      _boards[boardId]
          ?.canvasIds
          .map((id) => _canvases[id])
          .whereType<SmartCanvas>()
          .toList() ??
      [];

  List<SmartCard> searchCards(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _cards.values
        .where((c) =>
            c.title.toLowerCase().contains(q) ||
            c.values.values
                .any((v) => (v?.toString() ?? '').toLowerCase().contains(q)))
        .toList();
  }

  // ---------------- lifecycle ----------------

  Future<void> load() async {
    for (final t in builtinTemplates()) {
      _templates[t.id] = t;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStoreKey);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        for (final t in (j['templates'] as List? ?? [])) {
          final tpl =
              ComponentTemplate.fromJson((t as Map).cast<String, dynamic>());
          _templates[tpl.id] = tpl;
        }
        for (final c in (j['cards'] as List? ?? [])) {
          final card = SmartCard.fromJson((c as Map).cast<String, dynamic>());
          _cards[card.id] = card;
        }
        for (final c in (j['canvases'] as List? ?? [])) {
          final cv = SmartCanvas.fromJson((c as Map).cast<String, dynamic>());
          _canvases[cv.id] = cv;
        }
        for (final b in (j['boards'] as List? ?? [])) {
          final bd = SmartBoard.fromJson((b as Map).cast<String, dynamic>());
          _boards[bd.id] = bd;
        }
        _hiddenBuiltinIds
            .addAll(((j['hiddenBuiltins'] as List?) ?? []).cast<String>());
        _activeBoardId = j['activeBoardId'] as String?;
        final fh = j['fieldHistory'] as Map?;
        if (fh != null) {
          fh.forEach((k, v) =>
              _fieldHistory[k.toString()] = (v as List).cast<String>());
        }
        _notifiedAlerts
            .addAll(((j['notifiedAlerts'] as List?) ?? []).cast<String>());
      }
      final gh = prefs.getString(_kGenieKey);
      if (gh != null) {
        _genieHistory
          ..clear()
          ..addAll(((jsonDecode(gh) as List))
              .map((m) => (m as Map).cast<String, String>()));
      }
    } catch (_) {
      // Corrupt cache: fall back to built-ins only.
    }
    if (_boards.isEmpty) {
      final tpl = _templates.values.firstWhere((t) =>
          t.kind == ComponentKind.board && t.typeKey == 'kanban_swimlanes');
      final board = SmartBoard(templateId: tpl.id, title: 'My Board');
      _boards[board.id] = board;
      _activeBoardId = board.id;
      _seedStarterCards(board.id);
    }
    _activeBoardId ??= _boards.keys.first;
    _loaded = true;
    notifyListeners();
    await _persist();
  }

  /// First run opens on a working board rather than an empty one: a handful
  /// of cards spread across the three default columns, covering a few of the
  /// built-in types so the surfaces, colors and status groups are all visible
  /// the first time the surface is opened.
  void _seedStarterCards(String boardId) {
    SmartCard? seed(String typeKey, String title, String status,
        {String description = '', String assignee = '', String priority = 'P2', bool urgent = false}) {
      final tpl = _templates.values
          .where((t) => t.kind == ComponentKind.card && t.typeKey == typeKey)
          .firstOrNull;
      if (tpl == null) return null;
      final card = instantiateCard(tpl.id, boardId: boardId, status: status, title: title);
      if (card == null) return null;
      card.values['Title'] = title;
      card.values['Description'] = description;
      card.values['Status'] = _labelFor(status);
      card.assignee = assignee;
      card.priority = priority;
      card.urgent = urgent;
      return card;
    }

    seed('task', 'Set up your first workspace', 'to_do',
        description: 'Rename this board, add a lane, and drop a card of your own into it.',
        assignee: 'You', priority: 'P1');
    seed('task', 'Review the board views', 'to_do',
        description: 'Swipe the view switcher for Calendar, Notebook, Album and the rest.',
        priority: 'P2');
    seed('project', 'Collider refresh', 'in_progress',
        description: 'The active effort this board is tracking.',
        assignee: 'You', priority: 'P1');
    seed('feature', 'One-tap wallpaper set', 'in_progress',
        description: 'Ship the single-press set from the theme gallery.',
        priority: 'P2');
    seed('note', 'Everything here is editable in place', 'done',
        description: 'Tap any field on a card to change it. No settings screen.');
  }

  /// The display label a column key shows in the card's Status dropdown.
  static String _labelFor(String status) {
    switch (normalizeKanbanStatus(status)) {
      case 'in_progress':
        return 'In Progress';
      case 'done':
        return 'Done';
      case 'to_do':
      default:
        return 'To Do';
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kStoreKey,
          jsonEncode({
            'templates': _templates.values
                .where((t) => !t.isBuiltIn)
                .map((t) => t.toJson())
                .toList(),
            'cards': _cards.values.map((c) => c.toJson()).toList(),
            'canvases': _canvases.values.map((c) => c.toJson()).toList(),
            'boards': _boards.values.map((b) => b.toJson()).toList(),
            'hiddenBuiltins': _hiddenBuiltinIds.toList(),
            'activeBoardId': _activeBoardId,
            'fieldHistory': _fieldHistory,
            'notifiedAlerts': _notifiedAlerts.toList(),
          }));
    } catch (_) {}
  }

  Future<void> _persistGenie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kGenieKey, jsonEncode(_genieHistory));
    } catch (_) {}
  }

  void _changed() {
    notifyListeners();
    _persist();
  }

  // ---------------- templates ----------------

  ComponentTemplate createTemplate(
      ComponentKind kind, String name, String typeKey) {
    final tpl = ComponentTemplate(
        kind: kind, name: name, typeKey: typeKey, iconName: 'widgets_rounded');
    _templates[tpl.id] = tpl;
    _changed();
    return tpl;
  }

  void renameTemplate(String id, String name) {
    final t = _templates[id];
    if (t == null) return;
    t.name = name;
    t.version++;
    _changed();
  }

  void deleteTemplate(String id) {
    final t = _templates[id];
    if (t == null) return;
    if (t.isBuiltIn) {
      _hiddenBuiltinIds.add(id); // built-ins hide, never vanish
    } else {
      _templates.remove(id);
    }
    _changed();
  }

  void duplicateTemplate(String id) {
    final t = _templates[id];
    if (t == null) return;
    final copy = t.copy();
    final dup = ComponentTemplate(
      kind: copy.kind,
      name: '${copy.name} copy',
      typeKey: '${copy.typeKey}_copy_${DateTime.now().millisecondsSinceEpoch}',
      iconName: copy.iconName,
      fields: copy.fields,
      settings: copy.settings,
    );
    _templates[dup.id] = dup;
    _changed();
  }

  FieldDef addField(String templateId, String label,
      [FieldKind kind = FieldKind.text]) {
    final t = _templates[templateId]!;
    final f = FieldDef(label: label, kind: kind);
    t.fields.add(f);
    t.version++;
    _changed();
    return f;
  }

  void updateField(String templateId, FieldDef updated) {
    final t = _templates[templateId];
    if (t == null) return;
    final i = t.fields.indexWhere((f) => f.id == updated.id);
    if (i >= 0) t.fields[i] = updated;
    t.version++;
    _changed();
  }

  void removeField(String templateId, String fieldId) {
    final t = _templates[templateId];
    if (t == null) return;
    t.fields.removeWhere((f) => f.id == fieldId);
    t.version++;
    _changed();
  }

  void reorderField(String templateId, int oldIndex, int newIndex) {
    final t = _templates[templateId];
    if (t == null) return;
    if (newIndex > oldIndex) newIndex--;
    final f = t.fields.removeAt(oldIndex);
    t.fields.insert(newIndex, f);
    t.version++;
    _changed();
  }

  /// "Yes" path of the update prompt: push the template's current field
  /// configuration onto every deployed instance of that type. Instances keep
  /// their own values; new/renamed fields get defaults, removed fields drop
  /// their values, hidden flags survive.
  void applyTemplateToInstances(String templateId) {
    final t = _templates[templateId];
    if (t == null) return;
    final fieldIds = t.fields.map((f) => f.id).toSet();
    final defaults = {for (final f in t.fields) f.id: f.defaultValue};
    switch (t.kind) {
      case ComponentKind.card:
        for (final c
            in _cards.values.where((c) => c.templateId == templateId)) {
          for (final fid in fieldIds) {
            c.values.putIfAbsent(fid, () => defaults[fid]);
          }
          c.values.removeWhere((k, _) => !fieldIds.contains(k));
          c.hiddenFieldIds.removeWhere((fid) => !fieldIds.contains(fid));
          c.templateVersion = t.version;
          c.updatedAt = DateTime.now();
        }
        break;
      case ComponentKind.canvas:
        for (final c
            in _canvases.values.where((c) => c.templateId == templateId)) {
          c.templateVersion = t.version;
        }
        break;
      case ComponentKind.board:
        for (final b
            in _boards.values.where((b) => b.templateId == templateId)) {
          b.templateVersion = t.version;
        }
        break;
    }
    _changed();
  }

  // ---------------- cards ----------------

  /// Creates a card, or null when the spec §21 cap (999 cards) is reached —
  /// callers must surface the refusal to the user.
  SmartCard? instantiateCard(String templateId,
      {String? boardId,
      String? canvasId,
      String status = 'to_do',
      double x = 0,
      double y = 0,
      String? title}) {
    if (_cards.length >= maxCards) return null;
    final t = _templates[templateId];
    final bid = boardId ?? _activeBoardId!;
    final card = SmartCard(
      templateId: templateId,
      templateVersion: t?.version ?? 1,
      title: title ?? t?.name ?? 'Untitled',
      values: t == null ? {} : {for (final f in t.fields) f.id: f.defaultValue},
      boardId: bid,
      canvasId: canvasId,
      status: status,
      x: x,
      y: y,
      sortOrder: canvasId == null ? _endOfColumn(bid, status) : 0,
    );
    _cards[card.id] = card;
    if (canvasId != null) {
      _canvases[canvasId]?.cardIds.add(card.id);
    }
    _changed();
    return card;
  }

  /// Saves a ticker message as a note card in the active board.
  /// Returns the created card, or null if the card limit is reached.
  SmartCard? saveMessageAsCard(String text, {String? source}) {
    final title = text.length > 60 ? '${text.substring(0, 60)}...' : text;
    final card = instantiateCard(
      'note',
      title: title,
      status: 'to_do',
    );
    if (card != null) {
      card.values['content'] = text;
      if (source != null) card.values['source'] = source;
      _changed();
    }
    return card;
  }

  void updateCard(SmartCard card) {
    card.updatedAt = DateTime.now();
    _changed();
  }

  void deleteCard(String id) {
    final c = _cards.remove(id);
    if (c?.canvasId != null) {
      _canvases[c!.canvasId]?.cardIds.remove(id);
    }
    _changed();
  }

  SmartCard? duplicateCard(String id) {
    if (_cards.length >= maxCards) return null;
    final c = _cards[id];
    if (c == null) return null;
    final dup = SmartCard(
      templateId: c.templateId,
      templateVersion: c.templateVersion,
      title: '${c.title} copy',
      values: Map.of(c.values),
      hiddenFieldIds: Set.of(c.hiddenFieldIds),
      boardId: c.boardId,
      canvasId: c.canvasId,
      status: c.status,
      x: c.x + 16,
      y: c.y + 16,
      urgent: c.urgent,
      dueAt: c.dueAt,
      sortOrder: c.canvasId == null ? _endOfColumn(c.boardId, c.status) : 0,
      assignee: c.assignee,
      priority: c.priority,
      tags: List.of(c.tags),
      attachments: c.attachments
          .map((a) => CardAttachment(
              name: a.name,
              mime: a.mime,
              dataUrl: a.dataUrl,
              sizeBytes: a.sizeBytes))
          .toList(),
      embeddedCardIds: List.of(c.embeddedCardIds),
      triggers: List.of(c.triggers),
      inheritStatus: c.inheritStatus,
    );
    _cards[dup.id] = dup;
    if (dup.canvasId != null) {
      _canvases[dup.canvasId]?.cardIds.add(dup.id);
    }
    _changed();
    return dup;
  }

  /// Move a card between statuses, canvases, boards, or free positions.
  /// Spec §15: when the board's inheritColumnStatus behavior is on and the
  /// card's inherit flag is set, the card's Status field is rewritten to the
  /// new column's name on drop.
  void moveCard(String id,
      {String? status,
      String? canvasId,
      String? boardId,
      double? x,
      double? y}) {
    final c = _cards[id];
    if (c == null) return;
    if (canvasId != c.canvasId) {
      if (c.canvasId != null) {
        _canvases[c.canvasId]?.cardIds.remove(id);
      }
      if (canvasId != null) {
        _canvases[canvasId]?.cardIds.add(id);
      }
      c.canvasId = canvasId;
    }
    if (status != null) {
      final normalized = normalizeKanbanStatus(status);
      final changed = normalized != c.status;
      c.status = normalized;
      if (changed) _applyInheritStatus(c);
    }
    if (boardId != null) c.boardId = boardId;
    if (x != null) c.x = x;
    if (y != null) c.y = y;
    c.updatedAt = DateTime.now();
    _changed();
  }

  /// Spec §15 inherit: rewrite the card's "Status" field to the column label.
  void _applyInheritStatus(SmartCard c) {
    if (!c.inheritStatus) return;
    final board = _boards[c.boardId];
    if (board == null || !board.behavior('inheritColumnStatus')) return;
    final tpl = _templates[c.templateId];
    if (tpl == null) return;
    FieldDef? statusField;
    for (final f in tpl.fields) {
      if (f.label.toLowerCase() == 'status') {
        statusField = f;
        break;
      }
    }
    if (statusField == null) return;
    final label = _columnLabel(board, c.status);
    c.values[statusField.id] = label;
    // Keep the option list in sync so the new column stays selectable.
    if (!statusField.options.contains(label)) {
      statusField.options = [...statusField.options, label];
    }
  }

  /// Column label for a status key on a board (template columns setting).
  String _columnLabel(SmartBoard board, String statusKey) {
    final tpl = _templates[board.templateId];
    final cols = tpl?.settings['columns'];
    if (cols is List) {
      for (final col in cols) {
        final label = col.toString();
        if (label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_') ==
            statusKey) {
          return label;
        }
      }
    }
    return statusKey
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// Ordered column keys for a board, from its template settings.
  List<String> boardColumns(String boardId) {
    final board = _boards[boardId];
    final tpl = board == null ? null : _templates[board.templateId];
    final cols = tpl?.settings['columns'];
    if (cols is List && cols.isNotEmpty) {
      return cols
          .map((e) =>
              e.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'))
          .toList();
    }
    return const ['to_do', 'in_progress', 'done'];
  }

  /// Spec §4: add a new column label to the board's template settings.
  /// Returns the status key. No-op when the label already exists.
  String addBoardColumn(String boardId, String label) {
    final clean = label.trim();
    final board = _boards[boardId];
    final tpl = board == null ? null : _templates[board.templateId];
    if (clean.isEmpty || tpl == null) return '';
    final key = clean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final cols = tpl.settings['columns'];
    final labels = cols is List
        ? cols.map((e) => e.toString()).toList()
        : ['To Do', 'In Progress', 'Done'];
    if (!labels.any(
        (l) => l.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_') == key)) {
      labels.add(clean);
      tpl.settings['columns'] = labels;
      tpl.version++;
      _changed();
    }
    return key;
  }

  void setFieldValue(String cardId, String fieldId, dynamic value) {
    final c = _cards[cardId];
    if (c == null) return;
    c.values[fieldId] = value;
    // Spec §4: feed the autofill history for free-text-ish fields.
    final tpl = _templates[c.templateId];
    FieldDef? f;
    if (tpl != null) {
      for (final e in tpl.fields) {
        if (e.id == fieldId) f = e;
      }
    }
    if (f != null &&
        (f.kind == FieldKind.text || f.kind == FieldKind.url) &&
        value is String &&
        value.trim().isNotEmpty) {
      recordFieldHistory(c.templateId, f.label, value);
    }
    c.updatedAt = DateTime.now();
    _changed();
  }

  void setFieldHidden(String cardId, String fieldId, bool hidden) {
    final c = _cards[cardId];
    if (c == null) return;
    if (hidden) {
      c.hiddenFieldIds.add(fieldId);
    } else {
      c.hiddenFieldIds.remove(fieldId);
    }
    _changed();
  }

  // ---------------- canvases ----------------

  /// Creates a canvas, or null when the board already holds 10 (spec S3).
  SmartCanvas? instantiateCanvas(String templateId,
      {String? boardId, double x = 40, double y = 40, String? title}) {
    final bid = boardId ?? _activeBoardId!;
    if ((_boards[bid]?.canvasIds.length ?? 0) >= maxCanvasesPerBoard) {
      return null;
    }
    final t = _templates[templateId];
    final cv = SmartCanvas(
      templateId: templateId,
      templateVersion: t?.version ?? 1,
      title: title ?? t?.name ?? 'Untitled',
      boardId: bid,
      x: x,
      y: y,
    );
    _canvases[cv.id] = cv;
    _boards[bid]?.canvasIds.add(cv.id);
    _changed();
    return cv;
  }

  void updateCanvas(SmartCanvas cv) => _changed();

  void deleteCanvas(String id) {
    final cv = _canvases.remove(id);
    if (cv == null) return;
    _boards[cv.boardId]?.canvasIds.remove(id);
    // Cards inside fall back to the bare board, preserving their positions.
    for (final cardId in cv.cardIds) {
      final c = _cards[cardId];
      if (c != null) c.canvasId = null;
    }
    _changed();
  }

  void duplicateCanvas(String id) {
    final cv = _canvases[id]!;
    final dup = SmartCanvas(
      templateId: cv.templateId,
      templateVersion: cv.templateVersion,
      title: '${cv.title} copy',
      boardId: cv.boardId,
      x: cv.x + 24,
      y: cv.y + 24,
      width: cv.width,
      height: cv.height,
    );
    _canvases[dup.id] = dup;
    _boards[dup.boardId]?.canvasIds.add(dup.id);
    _changed();
  }

  void moveCanvas(String id, double x, double y) {
    final cv = _canvases[id];
    if (cv == null) return;
    cv.x = x;
    cv.y = y;
    _changed();
  }

  void resizeCanvas(String id, double width, double height) {
    final cv = _canvases[id];
    if (cv == null) return;
    cv.width = width.clamp(200, 1200);
    cv.height = height.clamp(160, 1200);
    _changed();
  }

  // ---------------- boards ----------------

  SmartBoard instantiateBoard(String templateId, {String? title}) {
    final t = _templates[templateId];
    final board = SmartBoard(
      templateId: templateId,
      templateVersion: t?.version ?? 1,
      title: title ?? t?.name ?? 'My Board',
    );
    _boards[board.id] = board;
    _activeBoardId = board.id;
    _changed();
    return board;
  }

  void setActiveBoard(String id) {
    if (_boards.containsKey(id)) {
      _activeBoardId = id;
      _changed();
    }
  }

  void renameBoard(String id, String title) {
    final b = _boards[id];
    if (b == null) return;
    b.title = title;
    _changed();
  }

  /// Persists a board-level setting (lanes, map options, …) — boards are
  /// otherwise edited inline, there is no settings screen.
  void setBoardSetting(String boardId, String key, dynamic value) {
    final b = _boards[boardId];
    if (b == null) return;
    b.settings[key] = value;
    _changed();
  }

  void deleteBoard(String id) {
    if (_boards.length <= 1) return; // always keep one work surface
    _boards.remove(id);
    final doomedCards =
        _cards.values.where((c) => c.boardId == id).map((c) => c.id).toList();
    for (final cid in doomedCards) {
      _cards.remove(cid);
    }
    final doomedCanvases = _canvases.values
        .where((c) => c.boardId == id)
        .map((c) => c.id)
        .toList();
    for (final cvid in doomedCanvases) {
      _canvases.remove(cvid);
    }
    if (_activeBoardId == id) _activeBoardId = _boards.keys.first;
    _changed();
  }

  // ---------------- spec §4: value history ----------------

  String _historyKey(String templateId, String label) => '$templateId::$label';

  /// Record a user-supplied value so dropdowns can suggest it later.
  void recordFieldHistory(String templateId, String label, String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    final k = _historyKey(templateId, label);
    final list = _fieldHistory.putIfAbsent(k, () => []);
    list.remove(v);
    list.insert(0, v);
    if (list.length > 12) list.removeRange(12, list.length);
    _changed();
  }

  /// Previously used values for a template field label, newest first.
  List<String> fieldHistory(String templateId, String label) =>
      List.unmodifiable(_fieldHistory[_historyKey(templateId, label)] ?? []);

  // ---------------- spec §7: due-date notifications ----------------

  /// Cards needing attention right now. Each entry is (card, isOverdue).
  /// Urgent cards due within the hour toast; any card past due red-alerts.
  List<(SmartCard, bool)> dueAlerts() {
    final now = DateTime.now();
    final out = <(SmartCard, bool)>[];
    for (final c in _cards.values) {
      final due = c.dueAt;
      if (due == null) continue;
      final diff = due.difference(now);
      if (diff.isNegative) {
        out.add((c, true));
      } else if (c.urgent && diff.inMinutes < 60) {
        out.add((c, false));
      }
    }
    return out;
  }

  /// Alert keys from the current [dueAlerts] that haven't been toasted yet.
  /// Marks them notified and prunes stale keys so a cleared condition can
  /// alert again later.
  List<(SmartCard, bool)> freshAlerts() {
    final current = dueAlerts();
    final liveKeys =
        current.map((e) => '${e.$1.id}:${e.$2 ? 'overdue' : 'soon'}').toSet();
    _notifiedAlerts.removeWhere((k) => !liveKeys.contains(k));
    final fresh = <(SmartCard, bool)>[];
    for (final e in current) {
      final key = '${e.$1.id}:${e.$2 ? 'overdue' : 'soon'}';
      if (_notifiedAlerts.add(key)) fresh.add(e);
    }
    if (fresh.isNotEmpty) _persist();
    return fresh;
  }

  // ---------------- spec §14: statistics ----------------

  /// Aggregates for the statistics panel.
  Map<String, dynamic> boardStats(String boardId) {
    final cards = _cards.values.where((c) => c.boardId == boardId).toList();
    final byPriority = <String, int>{};
    final byStatus = <String, int>{};
    final byType = <String, int>{};
    var urgent = 0;
    var withDeadline = 0;
    for (final c in cards) {
      byPriority[c.priority] = (byPriority[c.priority] ?? 0) + 1;
      byStatus[c.status] = (byStatus[c.status] ?? 0) + 1;
      final typeName = _templates[c.templateId]?.name ?? 'Unknown';
      byType[typeName] = (byType[typeName] ?? 0) + 1;
      if (c.urgent) urgent++;
      if (c.dueAt != null) withDeadline++;
    }
    return {
      'total': cards.length,
      'urgent': urgent,
      'withDeadline': withDeadline,
      'byPriority': byPriority,
      'byStatus': byStatus,
      'byType': byType,
    };
  }

  // ---------------- spec §12: multi-select bulk ops ----------------

  /// Bulk delete after the UI's confirmation step.
  void bulkDelete(Iterable<String> ids) {
    for (final id in ids.toList()) {
      final c = _cards.remove(id);
      if (c?.canvasId != null) {
        _canvases[c!.canvasId]?.cardIds.remove(id);
      }
    }
    _changed();
  }

  /// Bulk field edit for the multi-select "Edit" action.
  void bulkSet(Iterable<String> ids,
      {String? priority, bool? urgent, String? status}) {
    for (final id in ids) {
      final c = _cards[id];
      if (c == null) continue;
      if (priority != null) c.priority = priority;
      if (urgent != null) c.urgent = urgent;
      if (status != null) c.status = normalizeKanbanStatus(status);
      c.updatedAt = DateTime.now();
    }
    _changed();
  }

  /// Reorders a card within its board's flat order — used by the album,
  /// storyboard and vision views (spec §6). Kanban columns keep their own
  /// per-status order.
  void reorderBoardCard(String boardId, String cardId, int newIndex) {
    final ids = _cards.values
        .where((c) => c.boardId == boardId)
        .map((c) => c.id)
        .toList();
    if (!ids.remove(cardId)) return;
    ids.insert(newIndex.clamp(0, ids.length), cardId);
    final rest = <String, SmartCard>{};
    for (final e in _cards.entries) {
      if (e.value.boardId != boardId) rest[e.key] = e.value;
    }
    for (final id in ids) {
      rest[id] = _cards[id]!;
    }
    _cards
      ..clear()
      ..addAll(rest);
    _changed();
  }

  // ---------------- spec §16: embedded cards ----------------

  void embedCard(String cardId, String otherId) {
    final c = _cards[cardId];
    if (c == null || otherId == cardId || !_cards.containsKey(otherId)) return;
    if (!c.embeddedCardIds.contains(otherId)) {
      c.embeddedCardIds.add(otherId);
      _changed();
    }
  }

  void unembedCard(String cardId, String otherId) {
    final c = _cards[cardId];
    if (c == null) return;
    if (c.embeddedCardIds.remove(otherId)) _changed();
  }

  // ---------------- spec §18: auto triggers ----------------

  void setTriggers(String cardId, List<String> flags) {
    final c = _cards[cardId];
    if (c == null) return;
    c.triggers = flags.toList();
    _changed();
  }

  void toggleTrigger(String cardId, String flag) {
    final c = _cards[cardId];
    if (c == null) return;
    if (c.triggers.contains(flag)) {
      c.triggers.remove(flag);
    } else {
      c.triggers.add(flag);
    }
    _changed();
  }

  /// Evaluate card triggers. Called on status edits and on an hourly tick
  /// while the workspace is open.
  /// - 'done_final': when the card's Status field reads Done (or the kanban
  ///   status is already the final column), pin the kanban status to the
  ///   board's final column.
  /// - 'hourly_progress' (hourly tick only): advance one column forward.
  void applyTriggers({bool hourlyTick = false}) {
    var touched = false;
    for (final c in _cards.values) {
      if (c.triggers.isEmpty) continue;
      final cols = boardColumns(c.boardId);
      if (hourlyTick && c.triggers.contains('hourly_progress')) {
        final lastRun = c.lastTriggerRun;
        if (lastRun != null &&
            DateTime.now().difference(lastRun).inMinutes < 55) {
          continue;
        }
        final i = cols.indexOf(c.status);
        if (i >= 0 && i < cols.length - 1) {
          c.status = cols[i + 1];
          c.lastTriggerRun = DateTime.now();
          c.updatedAt = DateTime.now();
          touched = true;
        }
      }
      if (c.triggers.contains('done_final')) {
        final tpl = _templates[c.templateId];
        FieldDef? statusField;
        if (tpl != null) {
          for (final f in tpl.fields) {
            if (f.label.toLowerCase() == 'status') statusField = f;
          }
        }
        final fieldSaysDone =
            (c.values[statusField?.id]?.toString().toLowerCase() == 'done');
        if ((fieldSaysDone || c.status == cols.last) && c.status != cols.last) {
          c.status = cols.last;
          c.updatedAt = DateTime.now();
          touched = true;
        }
      }
    }
    if (touched) _changed();
  }

  // ---------------- spec §19: attachments ----------------

  void addAttachment(String cardId, CardAttachment attachment) {
    final c = _cards[cardId];
    if (c == null) return;
    c.attachments.add(attachment);
    c.updatedAt = DateTime.now();
    _changed();
  }

  void removeAttachment(String cardId, String attachmentId) {
    final c = _cards[cardId];
    if (c == null) return;
    c.attachments.removeWhere((a) => a.id == attachmentId);
    c.updatedAt = DateTime.now();
    _changed();
  }

  // ---------------- card detail fields ----------------

  void setAssignee(String cardId, String assignee) {
    final c = _cards[cardId];
    if (c == null) return;
    c.assignee = assignee;
    recordFieldHistory(c.templateId, 'assignee', assignee);
    c.updatedAt = DateTime.now();
    _changed();
  }

  void setTags(String cardId, List<String> tags) {
    final c = _cards[cardId];
    if (c == null) return;
    c.tags = tags.toList();
    for (final t in tags) {
      recordFieldHistory(c.templateId, 'tags', t);
    }
    c.updatedAt = DateTime.now();
    _changed();
  }

  void setPriority(String cardId, String priority) {
    final c = _cards[cardId];
    if (c == null) return;
    c.priority = priority;
    c.updatedAt = DateTime.now();
    _changed();
  }

  void setDueAt(String cardId, DateTime? dueAt) {
    final c = _cards[cardId];
    if (c == null) return;
    c.dueAt = dueAt;
    c.updatedAt = DateTime.now();
    _changed();
  }

  void setInheritStatus(String cardId, bool value) {
    final c = _cards[cardId];
    if (c == null) return;
    c.inheritStatus = value;
    _changed();
  }

  // ---------------- spec §11: board behaviors (inline) ----------------

  void setBoardBehavior(String boardId, String key, bool value) {
    final b = _boards[boardId];
    if (b == null) return;
    b.setBehavior(key, value);
    _changed();
  }

  // ---------------- spec S3/S4 §7.7: Genie type refactoring ----------------

  /// Reconfigure every instance of [fromTemplateId] as a subset of
  /// [toTemplateId]: instances keep values for fields whose labels match,
  /// gain the new type's defaults, and point at the new template.
  /// Returns the number of refactored cards.
  int retypeCards(String fromTemplateId, String toTemplateId) {
    final from = _templates[fromTemplateId];
    final to = _templates[toTemplateId];
    if (from == null || to == null || fromTemplateId == toTemplateId) return 0;
    final fromByLabel = {for (final f in from.fields) f.label: f};
    var count = 0;
    for (final c in _cards.values
        .where((c) => c.templateId == fromTemplateId)
        .toList()) {
      final next = <String, dynamic>{};
      for (final f in to.fields) {
        final old = fromByLabel[f.label];
        next[f.id] = (old != null && c.values.containsKey(old.id))
            ? c.values[old.id]
            : f.defaultValue;
      }
      c.values
        ..clear()
        ..addAll(next);
      c.hiddenFieldIds.removeWhere((fid) => !to.fields.any((f) => f.id == fid));
      c.templateId = toTemplateId;
      c.templateVersion = to.version;
      c.updatedAt = DateTime.now();
      count++;
    }
    if (count > 0) _changed();
    return count;
  }

  /// Reconfigure one card as [toTemplateId], keeping values for fields
  /// whose labels match the card's current type. Returns true on success.
  bool retypeCard(String cardId, String toTemplateId) {
    final c = _cards[cardId];
    final from = c == null ? null : _templates[c.templateId];
    final to = _templates[toTemplateId];
    if (c == null || from == null || to == null) return false;
    if (c.templateId == toTemplateId) return true;
    final fromByLabel = {for (final f in from.fields) f.label: f};
    final next = <String, dynamic>{};
    for (final f in to.fields) {
      final oldF = fromByLabel[f.label];
      next[f.id] = (oldF != null && c.values.containsKey(oldF.id))
          ? c.values[oldF.id]
          : f.defaultValue;
    }
    c.values
      ..clear()
      ..addAll(next);
    c.hiddenFieldIds.removeWhere((fid) => !to.fields.any((f) => f.id == fid));
    c.templateId = toTemplateId;
    c.templateVersion = to.version;
    c.updatedAt = DateTime.now();
    _changed();
    return true;
  }

  // ---------------- spec S3: persisted Genie history ----------------

  List<Map<String, String>> get genieHistory =>
      List.unmodifiable(_genieHistory);

  void geniePush(bool fromUser, String text) {
    _genieHistory.add({
      'fromUser': fromUser.toString(),
      'text': text,
      'at': DateTime.now().toIso8601String(),
    });
    if (_genieHistory.length > 200) {
      _genieHistory.removeRange(0, _genieHistory.length - 200);
    }
    _persistGenie();
  }

  void genieClearHistory() {
    _genieHistory.clear();
    _persistGenie();
  }
}
