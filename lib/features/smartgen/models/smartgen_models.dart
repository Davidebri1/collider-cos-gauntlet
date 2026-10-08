import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Which component family a template / instance belongs to.
/// Mandatory and NOT user-extensible (per Smart Gen Summary).
enum ComponentKind { card, canvas, board }

/// Editable field control types. Users can change a property's control
/// type inline (e.g. status: dropdown -> toggle -> color).
/// Covers the spec's custom-field types: string/number/boolean/date/time/
////datetime map to text/number/toggle/date/time/datetime.
enum FieldKind {
  text,
  number,
  date,
  time,
  datetime,
  dropdown,
  toggle,
  color,
  url
}

String newId() => _uuid.v4();

/// Definition of a single editable property on a component template.
class FieldDef {
  final String id;
  String label;
  FieldKind kind;
  bool required;
  dynamic defaultValue;
  List<String> options; // dropdown choices

  FieldDef({
    String? id,
    required this.label,
    this.kind = FieldKind.text,
    this.required = false,
    this.defaultValue,
    List<String>? options,
  })  : id = id ?? newId(),
        options = options ?? [];

  FieldDef copy() => FieldDef(
        id: id,
        label: label,
        kind: kind,
        required: required,
        defaultValue: defaultValue,
        options: List.of(options),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'kind': kind.name,
        'required': required,
        'defaultValue': defaultValue?.toString(),
        'options': options,
      };

  factory FieldDef.fromJson(Map<String, dynamic> j) => FieldDef(
        id: j['id'] as String,
        label: j['label'] as String,
        kind: FieldKind.values.firstWhere((e) => e.name == j['kind'],
            orElse: () => FieldKind.text),
        required: j['required'] as bool? ?? false,
        defaultValue: j['defaultValue'],
        options: (j['options'] as List?)?.cast<String>() ?? [],
      );
}

/// A reusable type template (e.g. "Task card", "Notebook canvas", "Desk board").
/// Editing a template never touches instances until the user confirms the
/// "update deployed instances?" prompt.
class ComponentTemplate {
  final String id;
  final ComponentKind kind;
  String name;
  String typeKey; // stable key: 'task', 'notebook', 'desk', 'custom_...'
  String iconName; // material icon key for drawer thumbnail fallback
  List<FieldDef> fields;
  Map<String, dynamic> settings; // defaults: status options, colors, etc.
  int version;
  final bool isBuiltIn;

  ComponentTemplate({
    String? id,
    required this.kind,
    required this.name,
    required this.typeKey,
    this.iconName = 'widgets_rounded',
    List<FieldDef>? fields,
    Map<String, dynamic>? settings,
    this.version = 1,
    this.isBuiltIn = false,
  })  : id = id ?? newId(),
        fields = fields ?? [],
        settings = settings ?? {};

  ComponentTemplate copy() => ComponentTemplate(
        id: id,
        kind: kind,
        name: name,
        typeKey: typeKey,
        iconName: iconName,
        fields: fields.map((f) => f.copy()).toList(),
        settings: Map.of(settings),
        version: version,
        isBuiltIn: isBuiltIn,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'name': name,
        'typeKey': typeKey,
        'iconName': iconName,
        'fields': fields.map((f) => f.toJson()).toList(),
        'settings': settings.map((k, v) => MapEntry(k, v?.toString())),
        'version': version,
        'isBuiltIn': isBuiltIn,
      };

  factory ComponentTemplate.fromJson(Map<String, dynamic> j) =>
      ComponentTemplate(
        id: j['id'] as String,
        kind: ComponentKind.values.firstWhere((e) => e.name == j['kind']),
        name: j['name'] as String,
        typeKey: j['typeKey'] as String,
        iconName: j['iconName'] as String? ?? 'widgets_rounded',
        fields: (j['fields'] as List? ?? [])
            .map((f) => FieldDef.fromJson((f as Map).cast<String, dynamic>()))
            .toList(),
        settings: (j['settings'] as Map? ?? {}).cast<String, dynamic>(),
        version: j['version'] as int? ?? 1,
        isBuiltIn: j['isBuiltIn'] as bool? ?? false,
      );
}

/// Canonical kanban status key for the "To Do" column.
///
/// The board specification derives column keys from column labels
/// ("To Do" -> "to_do"), but older code and persisted data used the short
/// hand key "todo". This normalizes both the default and legacy payloads to
/// the spec-derived key so cards can never silently vanish from the column.
String normalizeKanbanStatus(String? raw) {
  // Canonical form matches the kanban column-key derivation:
  // lowercase, non-alphanumerics become underscores.
  final s = (raw ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (s == 'todo' || s == 'to_do' || s.isEmpty) return 'to_do';
  return s;
}

/// A file attached to a card. Stored as a data URL in the card payload
/// (spec §19). Images render thumbnails, videos render a player, other
/// files render icon + name.
class CardAttachment {
  final String id;
  String name;
  String mime;
  String dataUrl;
  int sizeBytes;

  CardAttachment({
    String? id,
    required this.name,
    this.mime = 'application/octet-stream',
    this.dataUrl = '',
    this.sizeBytes = 0,
  }) : id = id ?? newId();

  bool get isImage => mime.startsWith('image/');
  bool get isVideo => mime.startsWith('video/');

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mime': mime,
        'dataUrl': dataUrl,
        'sizeBytes': sizeBytes,
      };

  factory CardAttachment.fromJson(Map<String, dynamic> j) => CardAttachment(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'file',
        mime: j['mime'] as String? ?? 'application/octet-stream',
        dataUrl: j['dataUrl'] as String? ?? '',
        sizeBytes: j['sizeBytes'] as int? ?? 0,
      );
}

/// A deployed card instance. Lives directly on a board or inside a canvas.
class SmartCard {
  final String id;
  String templateId;
  int templateVersion;
  String title;
  Map<String, dynamic> values; // fieldId -> value (JSON-persisted)
  Set<String> hiddenFieldIds; // grayed out, moved to back of card
  String boardId;
  String? canvasId; // null = directly on board
  String status; // kanban column key
  double x, y; // free-form position (canvas / whiteboard)
  bool urgent;
  DateTime? dueAt;
  DateTime createdAt;
  DateTime updatedAt;

  /// Kanban column ordering. Fractional positions survive drags; cards are
  /// sorted by this before falling back to creation time (so cards created
  /// before this field existed keep their old relative order).
  double sortOrder;

  // ---- spec §3 fields, first-class so search/stats/triggers are reliable ----
  String assignee;
  String priority; // P0..P3
  List<String> tags;
  List<CardAttachment> attachments;
  List<String> embeddedCardIds;

  /// Spec §18: stored as a comma-separated string in the payload.
  /// Known flags: 'done_final', 'hourly_progress'.
  List<String> triggers;

  /// Spec §15: when true and the board's inheritColumnStatus behavior is on,
  /// dropping the card in a column rewrites its status to the column name.
  bool inheritStatus;
  DateTime? lastTriggerRun;

  SmartCard({
    String? id,
    required this.templateId,
    this.templateVersion = 1,
    this.title = 'Untitled',
    Map<String, dynamic>? values,
    Set<String>? hiddenFieldIds,
    required this.boardId,
    this.canvasId,
    this.status = 'to_do',
    this.x = 0,
    this.y = 0,
    this.urgent = false,
    this.dueAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.sortOrder = 0,
    this.assignee = '',
    this.priority = 'P2',
    List<String>? tags,
    List<CardAttachment>? attachments,
    List<String>? embeddedCardIds,
    List<String>? triggers,
    this.inheritStatus = false,
    this.lastTriggerRun,
  })  : id = id ?? newId(),
        values = values ?? {},
        hiddenFieldIds = hiddenFieldIds ?? {},
        tags = tags ?? [],
        attachments = attachments ?? [],
        embeddedCardIds = embeddedCardIds ?? [],
        triggers = triggers ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now() {
    // Normalize legacy keys (e.g. persisted 'todo') to the spec key.
    status = normalizeKanbanStatus(status);
  }

  /// Notebook pages: the first long text field's value split on '---'.
  List<String> notebookPages(Map<String, FieldDef> fieldsById) {
    for (final entry in values.entries) {
      final f = fieldsById[entry.key];
      if (f == null) continue;
      final label = f.label.toLowerCase();
      final text = entry.value?.toString() ?? '';
      if (text.contains('---') &&
          (label.contains('note') ||
              label.contains('body') ||
              label.contains('entry') ||
              label.contains('descript') ||
              label.contains('content'))) {
        return text
            .split(RegExp(r'\n?---\n?'))
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'templateVersion': templateVersion,
        'title': title,
        'values': values.map((k, v) => MapEntry(k, v?.toString())),
        'hiddenFieldIds': hiddenFieldIds.toList(),
        'boardId': boardId,
        'canvasId': canvasId,
        'status': status,
        'x': x,
        'y': y,
        'urgent': urgent,
        'dueAt': dueAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'sortOrder': sortOrder,
        'assignee': assignee,
        'priority': priority,
        'tags': tags,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'embeddedCardIds': embeddedCardIds,
        'triggers': triggers.join(','),
        'inheritStatus': inheritStatus,
        'lastTriggerRun': lastTriggerRun?.toIso8601String(),
      };

  factory SmartCard.fromJson(Map<String, dynamic> j) => SmartCard(
        id: j['id'] as String,
        templateId: j['templateId'] as String,
        templateVersion: j['templateVersion'] as int? ?? 1,
        title: j['title'] as String? ?? 'Untitled',
        values: (j['values'] as Map? ?? {}).cast<String, dynamic>(),
        hiddenFieldIds:
            ((j['hiddenFieldIds'] as List?) ?? []).cast<String>().toSet(),
        boardId: j['boardId'] as String,
        canvasId: j['canvasId'] as String?,
        status: normalizeKanbanStatus(j['status'] as String?),
        x: (j['x'] as num? ?? 0).toDouble(),
        y: (j['y'] as num? ?? 0).toDouble(),
        urgent: j['urgent'] as bool? ?? false,
        dueAt: j['dueAt'] != null ? DateTime.parse(j['dueAt'] as String) : null,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        sortOrder: (j['sortOrder'] as num? ?? 0).toDouble(),
        assignee: j['assignee'] as String? ?? '',
        priority: j['priority'] as String? ?? 'P2',
        tags: ((j['tags'] as List?) ?? []).cast<String>(),
        attachments: ((j['attachments'] as List?) ?? [])
            .map((a) =>
                CardAttachment.fromJson((a as Map).cast<String, dynamic>()))
            .toList(),
        embeddedCardIds: ((j['embeddedCardIds'] as List?) ?? []).cast<String>(),
        triggers: ((j['triggers'] as String?) ?? '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        inheritStatus: j['inheritStatus'] as bool? ?? false,
        lastTriggerRun: j['lastTriggerRun'] != null
            ? DateTime.parse(j['lastTriggerRun'] as String)
            : null,
      );
}

/// A deployed canvas instance: a container sitting on a board, holding cards.
class SmartCanvas {
  final String id;
  String templateId;
  int templateVersion;
  String title;
  String boardId;
  double x, y, width, height;
  List<String> cardIds; // z-ordered
  DateTime createdAt;

  SmartCanvas({
    String? id,
    required this.templateId,
    this.templateVersion = 1,
    this.title = 'Untitled',
    required this.boardId,
    this.x = 40,
    this.y = 40,
    this.width = 320,
    this.height = 420,
    List<String>? cardIds,
    DateTime? createdAt,
  })  : id = id ?? newId(),
        cardIds = cardIds ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'templateVersion': templateVersion,
        'title': title,
        'boardId': boardId,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'cardIds': cardIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SmartCanvas.fromJson(Map<String, dynamic> j) => SmartCanvas(
        id: j['id'] as String,
        templateId: j['templateId'] as String,
        templateVersion: j['templateVersion'] as int? ?? 1,
        title: j['title'] as String? ?? 'Untitled',
        boardId: j['boardId'] as String,
        x: (j['x'] as num? ?? 40).toDouble(),
        y: (j['y'] as num? ?? 40).toDouble(),
        width: (j['width'] as num? ?? 320).toDouble(),
        height: (j['height'] as num? ?? 420).toDouble(),
        cardIds: ((j['cardIds'] as List?) ?? []).cast<String>(),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// A deployed board instance: the work surface (desk/table) holding cards
/// and canvases. Exactly one board is active in the Smart Gen view.
///
/// [behaviors] holds the board behavior toggles (spec §11, managed inline
/// on the board toolbar — no settings panel): inheritColumnStatus,
/// urgentAutoCalendar, autoSort, autoFilterComplete, autoArrange.
class SmartBoard {
  final String id;
  String templateId;
  int templateVersion;
  String title;
  List<String> canvasIds;
  Map<String, bool> behaviors;
  Map<String, dynamic> settings; // per-board instance settings (lanes, …)
  DateTime createdAt;

  SmartBoard({
    String? id,
    required this.templateId,
    this.templateVersion = 1,
    this.title = 'My Board',
    List<String>? canvasIds,
    Map<String, bool>? behaviors,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
  })  : id = id ?? newId(),
        canvasIds = canvasIds ?? [],
        behaviors = behaviors ?? {},
        settings = settings ?? {},
        createdAt = createdAt ?? DateTime.now();

  bool behavior(String key) => behaviors[key] ?? false;
  void setBehavior(String key, bool value) => behaviors[key] = value;

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'templateVersion': templateVersion,
        'title': title,
        'canvasIds': canvasIds,
        'behaviors': behaviors,
        'settings': settings,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SmartBoard.fromJson(Map<String, dynamic> j) => SmartBoard(
        id: j['id'] as String,
        templateId: j['templateId'] as String,
        title: j['title'] as String? ?? 'My Board',
        templateVersion: j['templateVersion'] as int? ?? 1,
        canvasIds: ((j['canvasIds'] as List?) ?? []).cast<String>(),
        behaviors: ((j['behaviors'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), v == true)),
        settings:
            (j['settings'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ??
                {},
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
