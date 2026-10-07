import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/files/file_blobs.dart';

/// One Smart Gen card.
class KanbanCard {
  final String id;
  String title;
  String notes;
  int column; // index into KanbanStore.columns
  int color; // index into the card palette
  double rank; // order inside a column, highest first
  bool collapsed; // Nimo collapsed shape: one grid unit, title only
  String image; // FileBlobs id of the cover photo, '' = none
  final int createdMs;
  int updatedMs;

  KanbanCard({
    required this.id,
    this.title = '',
    this.notes = '',
    this.column = 0,
    this.color = 0,
    double? rank,
    this.collapsed = false,
    this.image = '',
    required this.createdMs,
    required this.updatedMs,
  }) : rank = rank ?? createdMs.toDouble();

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'col': column,
        'color': color,
        'rank': rank,
        if (collapsed) 'min': true,
        if (image.isNotEmpty) 'img': image,
        'at': createdMs,
        'up': updatedMs,
      };

  static KanbanCard? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    if (id is! String) return null;
    final at = (j['at'] as num?)?.toInt() ?? 0;
    return KanbanCard(
      id: id,
      title: (j['title'] as String?) ?? '',
      notes: (j['notes'] as String?) ?? '',
      column: ((j['col'] as num?)?.toInt() ?? 0).clamp(0, KanbanStore.columns.length - 1),
      color: (j['color'] as num?)?.toInt() ?? 0,
      rank: (j['rank'] as num?)?.toDouble() ?? at.toDouble(),
      collapsed: j['min'] == true,
      image: (j['img'] as String?) ?? '',
      createdMs: at,
      updatedMs: (j['up'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The user's local Kanban board (map rows 23-25, D54). Only cards the user
/// made: no samples. Saved as one JSON document through [FileBlobs]
/// (IndexedDB on web, a file in the app's documents on iOS / Android), so it
/// is there after a reload or a restart. Every change is undoable (the
/// Keynote ornament's undo / redo, v8.4).
class KanbanStore extends ChangeNotifier {
  KanbanStore._();
  static final KanbanStore instance = KanbanStore._();

  static const List<String> columns = ['To Do', 'Doing', 'Done'];
  static const int paletteSize = 5;
  static const String _blobId = 'smartgen/kanban.json';

  final List<KanbanCard> _cards = [];
  final List<String> _undo = [];
  final List<String> _redo = [];
  bool _loaded = false;
  Future<void>? _loading;

  bool get loaded => _loaded;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  List<KanbanCard> get all => List.unmodifiable(_cards);

  KanbanCard? byId(String? id) {
    if (id == null) return null;
    for (final c in _cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Cards in [column], highest rank (newest / brought to front) first.
  List<KanbanCard> inColumn(int column) {
    final l = _cards.where((c) => c.column == column).toList()..sort((a, b) => b.rank.compareTo(a.rank));
    return l;
  }

  int count(int column) => _cards.where((c) => c.column == column).length;

  Future<void> init() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final b = await FileBlobs.get(_blobId);
      if (b != null && b.isNotEmpty) _restore(utf8.decode(b));
    } catch (e) {
      debugPrint('KanbanStore: ignored unreadable board: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  String _snapshot() => jsonEncode({'v': 2, 'cards': [for (final c in _cards) c.toJson()]});

  void _restore(String doc) {
    final j = jsonDecode(doc);
    final list = j is Map ? j['cards'] : null;
    if (list is List) {
      _cards
        ..clear()
        ..addAll(list.map(KanbanCard.fromJson).whereType<KanbanCard>());
    }
  }

  Future<void> _save() async {
    await FileBlobs.put(_blobId, Uint8List.fromList(utf8.encode(_snapshot())));
  }

  /// Records the state before a change (for undo) and clears redo.
  void _checkpoint() {
    _undo.add(_snapshot());
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
  }

  Future<void> _commit() async {
    notifyListeners();
    await _save();
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    _redo.add(_snapshot());
    _restore(_undo.removeLast());
    await _commit();
  }

  Future<void> redo() async {
    if (_redo.isEmpty) return;
    _undo.add(_snapshot());
    _restore(_redo.removeLast());
    await _commit();
  }

  KanbanCard add(int column) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _checkpoint();
    final c = KanbanCard(id: 'k$now', column: column, color: _cards.length % paletteSize, createdMs: now, updatedMs: now);
    _cards.add(c);
    notifyListeners();
    // Saved once it has a title (an untitled card is dropped, see [edit]).
    return c;
  }

  Future<void> edit(KanbanCard c, {String? title, String? notes}) async {
    final t = title?.trim() ?? c.title;
    final n = notes?.trim() ?? c.notes;
    if (t.isEmpty && n.isEmpty && c.image.isEmpty) {
      await remove(c, record: false);
      return;
    }
    if (t == c.title && n == c.notes) {
      notifyListeners();
      await _save();
      return;
    }
    c.title = t;
    c.notes = n;
    c.updatedMs = DateTime.now().millisecondsSinceEpoch;
    await _commit();
  }

  Future<void> move(KanbanCard c, int column) async {
    if (c.column == column) return;
    _checkpoint();
    c.column = column;
    c.rank = DateTime.now().millisecondsSinceEpoch.toDouble();
    c.updatedMs = DateTime.now().millisecondsSinceEpoch;
    await _commit();
  }

  Future<void> recolor(KanbanCard c, int color) async {
    if (c.color == color) return;
    _checkpoint();
    c.color = color % paletteSize;
    await _commit();
  }

  Future<void> setCollapsed(Iterable<KanbanCard> cards, bool v) async {
    final l = cards.where((c) => c.collapsed != v).toList();
    if (l.isEmpty) return;
    _checkpoint();
    for (final c in l) {
      c.collapsed = v;
    }
    await _commit();
  }

  /// Layer order (row 25 "Layer"): to the top or the bottom of its column.
  Future<void> toFront(KanbanCard c) async {
    final col = inColumn(c.column);
    if (col.isEmpty || col.first.id == c.id) return;
    _checkpoint();
    c.rank = col.first.rank + 1;
    await _commit();
  }

  Future<void> toBack(KanbanCard c) async {
    final col = inColumn(c.column);
    if (col.isEmpty || col.last.id == c.id) return;
    _checkpoint();
    c.rank = col.last.rank - 1;
    await _commit();
  }

  Future<KanbanCard> duplicate(KanbanCard c) async {
    _checkpoint();
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = KanbanCard(
      id: 'k$now',
      title: c.title,
      notes: c.notes,
      column: c.column,
      color: c.color,
      rank: c.rank + 0.5,
      collapsed: c.collapsed,
      image: c.image,
      createdMs: now,
      updatedMs: now,
    );
    _cards.add(d);
    await _commit();
    return d;
  }

  /// Cover photo (ornament "photo"): stored as its own blob.
  Future<void> setImage(KanbanCard c, Uint8List? bytes) async {
    _checkpoint();
    if (bytes == null) {
      c.image = '';
    } else {
      final id = 'smartgen/img/${c.id}-${DateTime.now().millisecondsSinceEpoch}';
      await FileBlobs.put(id, bytes);
      c.image = id;
    }
    c.updatedMs = DateTime.now().millisecondsSinceEpoch;
    await _commit();
  }

  Future<void> remove(KanbanCard c, {bool record = true}) async {
    if (record) _checkpoint();
    _cards.removeWhere((x) => x.id == c.id);
    await _commit();
  }

  /// The board as Markdown (toolbar share: copied to the clipboard).
  String toMarkdown() {
    final b = StringBuffer('# Smart Gen\n');
    for (var i = 0; i < columns.length; i++) {
      b.writeln('\n## ${columns[i]}');
      for (final c in inColumn(i)) {
        b.writeln('- ${c.title.isEmpty ? '(untitled)' : c.title}');
        if (c.notes.isNotEmpty) b.writeln('  ${c.notes.replaceAll('\n', '\n  ')}');
      }
    }
    return b.toString();
  }
}
