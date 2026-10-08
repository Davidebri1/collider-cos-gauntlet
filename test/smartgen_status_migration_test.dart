import 'dart:convert';

import 'package:collider_flutter/features/smartgen/models/smartgen_models.dart';
import 'package:collider_flutter/features/smartgen/state/smartgen_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression coverage for the kanban status key migration.
///
/// The board spec derives column keys from labels ("To Do" -> "to_do"), but
/// older code and persisted payloads used the shorthand "todo", which made
/// drawer-deployed and legacy cards silently disappear from the To Do
/// column. "to_do" is now canonical and every write path normalizes to it.
void main() {
  Future<SmartGenStore> freshStore() async {
    final s = SmartGenStore();
    await s.load();
    return s;
  }

  String cardTemplateId(SmartGenStore s) => s
      .templatesOf(ComponentKind.card)
      .firstWhere((t) => t.typeKey == 'task')
      .id;

  group('kanban status key migration', () {
    test('legacy persisted "todo" cards normalize to "to_do" on load',
        () async {
      final now = DateTime.now().toIso8601String();
      final legacy = jsonEncode({
        'templates': <dynamic>[],
        'cards': [
          {
            'id': 'legacy-1',
            'templateId': 'tpl',
            'templateVersion': 1,
            'title': 'Legacy A',
            'values': <String, dynamic>{},
            'hiddenFieldIds': <dynamic>[],
            'boardId': 'board-1',
            'canvasId': null,
            'status': 'todo',
            'x': 0,
            'y': 0,
            'urgent': false,
            'dueAt': null,
            'createdAt': now,
            'updatedAt': now,
            'sortOrder': 2048.0,
          },
          {
            'id': 'legacy-2',
            'templateId': 'tpl',
            'templateVersion': 1,
            'title': 'Legacy B',
            'values': <String, dynamic>{},
            'hiddenFieldIds': <dynamic>[],
            'boardId': 'board-1',
            'canvasId': null,
            'status': 'todo',
            'x': 0,
            'y': 0,
            'urgent': false,
            'dueAt': null,
            'createdAt': now,
            'updatedAt': now,
            'sortOrder': 4096.0,
          },
        ],
        'canvases': <dynamic>[],
        'boards': [
          {
            'id': 'board-1',
            'templateId': 'tpl-board',
            'templateVersion': 1,
            'title': 'Legacy Board',
            'canvasIds': <dynamic>[],
            'createdAt': now,
          },
        ],
        'hiddenBuiltins': <dynamic>[],
        'activeBoardId': 'board-1',
      });
      SharedPreferences.setMockInitialValues({'smartgen_store_v1': legacy});

      final s = SmartGenStore();
      await s.load();

      final visible = s.boardCards('board-1', status: 'to_do');
      expect(visible.map((e) => e.title).toList(), ['Legacy A', 'Legacy B']);
      expect(visible.map((e) => e.status).toSet(), {'to_do'});
      // Ordering survived the migration.
      expect(visible.map((e) => e.sortOrder).toList(),
          orderedEquals([2048.0, 4096.0]));
      // Nothing remains hidden under the legacy key.
      expect(s.boardCards('board-1', status: 'todo'), isEmpty);
    });

    test('SmartCard.fromJson migrates "todo" and keeps other keys intact', () {
      final now = DateTime.now().toIso8601String();
      Map<String, dynamic> jsonFor(String? status) => {
            'id': 'c',
            'templateId': 't',
            'templateVersion': 1,
            'title': 'X',
            'values': <String, dynamic>{},
            'hiddenFieldIds': <dynamic>[],
            'boardId': 'b',
            'canvasId': null,
            if (status != null) 'status': status,
            'x': 0,
            'y': 0,
            'urgent': false,
            'dueAt': null,
            'createdAt': now,
            'updatedAt': now,
            'sortOrder': 1024.0,
          };

      expect(SmartCard.fromJson(jsonFor('todo')).status, 'to_do');
      expect(SmartCard.fromJson(jsonFor('to_do')).status, 'to_do');
      expect(SmartCard.fromJson(jsonFor('in_progress')).status, 'in_progress');
      expect(SmartCard.fromJson(jsonFor('done')).status, 'done');
      // Missing status defaults to the canonical To Do key.
      expect(SmartCard.fromJson(jsonFor(null)).status, 'to_do');
    });

    test('instantiateCard without a status lands in the To Do column',
        () async {
      SharedPreferences.setMockInitialValues({});
      final s = await freshStore();
      final board = s.activeBoard!;
      final tpl = cardTemplateId(s);

      // Drawer deployment path: no status argument.
      final card = s.instantiateCard(tpl, boardId: board.id, title: 'New')!;
      expect(card.status, 'to_do');
      expect(
          s.boardCards(board.id, status: 'to_do').any((c) => c.id == card.id),
          isTrue);

      // Explicit legacy key is normalized too.
      final legacy = s.instantiateCard(tpl,
          boardId: board.id, status: 'todo', title: 'Old')!;
      expect(legacy.status, 'to_do');
    });

    test('migration is idempotent across a full save/load round-trip',
        () async {
      SharedPreferences.setMockInitialValues({});
      final s = await freshStore();
      final board = s.activeBoard!;
      final tpl = cardTemplateId(s);
      final a = s.instantiateCard(tpl, boardId: board.id, title: 'A')!;
      final b =
          s.instantiateCard(tpl, boardId: board.id, status: 'todo', title: 'B')!;
      s.setColumnOrder(board.id, 'to_do', [b.id, a.id]);

      final s2 = SmartGenStore();
      await s2.load();
      final cards = s2.boardCards(board.id, status: 'to_do');
      expect(cards.map((e) => e.id).toList(), [b.id, a.id]);
      expect(cards.every((c) => c.status == 'to_do'), isTrue);

      final raw = (await SharedPreferences.getInstance())
          .getString('smartgen_store_v1')!;
      expect(raw.contains('"status":"todo"'), isFalse);
      expect(raw.contains('"status":"to_do"'), isTrue);

      // A second reload is a no-op on keys and order.
      final s3 = SmartGenStore();
      await s3.load();
      expect(s3.boardCards(board.id, status: 'to_do').map((e) => e.id).toList(),
          [b.id, a.id]);
    });
  });
}
