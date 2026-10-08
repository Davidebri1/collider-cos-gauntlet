import 'package:collider_flutter/features/smartgen/models/smartgen_models.dart';
import 'package:collider_flutter/features/smartgen/state/smartgen_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies durable kanban ordering: sortOrder assignment, setColumnOrder
/// persistence, the filtered-drag pipeline (HTML emits FULL column orders),
/// cross-column moves, and the persistence round-trip.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SmartGenStore> freshStore() async {
    final s = SmartGenStore();
    await s.load();
    return s;
  }

  String cardTemplateId(SmartGenStore s) => s
      .templatesOf(ComponentKind.card)
      .firstWhere((t) => t.typeKey == 'task')
      .id;

  group('kanban ordering', () {
    test('new cards append at end of column in creation order', () async {
      final s = await freshStore();
      final board = s.activeBoard!;
      final tpl = cardTemplateId(s);
      final a = s.instantiateCard(tpl, boardId: board.id, title: 'A')!;
      final b = s.instantiateCard(tpl, boardId: board.id, title: 'B')!;
      final c = s.instantiateCard(tpl, boardId: board.id, title: 'C')!;

      final cards = s.boardCards(board.id, status: 'to_do');
      expect(cards.map((e) => e.id).toList(), [a.id, b.id, c.id]);
      expect(a.sortOrder < b.sortOrder, isTrue);
      expect(b.sortOrder < c.sortOrder, isTrue);
    });

    test('setColumnOrder persists an exact reorder', () async {
      final s = await freshStore();
      final board = s.activeBoard!;
      final tpl = cardTemplateId(s);
      final a = s.instantiateCard(tpl, boardId: board.id, title: 'A')!;
      final b = s.instantiateCard(tpl, boardId: board.id, title: 'B')!;
      final c = s.instantiateCard(tpl, boardId: board.id, title: 'C')!;

      // Drag C to the top: HTML emits the full new column order.
      s.setColumnOrder(board.id, 'to_do', [c.id, a.id, b.id]);

      final cards = s.boardCards(board.id, status: 'to_do');
      expect(cards.map((e) => e.id).toList(), [c.id, a.id, b.id]);
      // 1024-spaced, no collisions.
      final orders = cards.map((e) => e.sortOrder).toList();
      expect(orders.toSet().length, 3);
      expect(orders, orderedEquals([1024.0, 2048.0, 3072.0]));
    });

    test('filtered drag emits full order: hidden cards keep correct positions',
        () async {
      final s = await freshStore();
      final board = s.activeBoard!;
      final tpl = cardTemplateId(s);
      final a = s.instantiateCard(tpl, boardId: board.id, title: 'A')!;
      final b = s.instantiateCard(tpl, boardId: board.id, title: 'B')!;
      final c = s.instantiateCard(tpl, boardId: board.id, title: 'C')!;
      final d = s.instantiateCard(tpl, boardId: board.id, title: 'D')!;
      // Only B is urgent; the 'urgent' pill shows just B, but the HTML view
      // now retains the full column [A, B, C, D].
      b.urgent = true;
      s.updateCard(b);

      // User drags B below C in the filtered view. HTML maps the visible
      // index through neighboring visible cards and emits the FULL order.
      s.setColumnOrder(board.id, 'to_do', [a.id, c.id, b.id, d.id]);

      final cards = s.boardCards(board.id, status: 'to_do');
      expect(
        cards.map((e) => e.id).toList(),
        [a.id, c.id, b.id, d.id],
      );
      final orders = cards.map((e) => e.sortOrder).toList();
      expect(orders.toSet().length, 4, reason: 'no sortOrder collisions');
    });

    test('cross-column move updates both columns', () async {
      final s = await freshStore();
      final board = s.activeBoard!;
      final tpl = cardTemplateId(s);
      final a = s.instantiateCard(tpl, boardId: board.id, title: 'A')!;
      final b = s.instantiateCard(tpl, boardId: board.id, title: 'B')!;
      final p = s.instantiateCard(tpl,
          boardId: board.id, status: 'in_progress', title: 'P')!;

      // Drag B from To Do to the top of in_progress (bridge sequence).
      s.moveCard(b.id, status: 'in_progress', canvasId: null);
      s.setColumnOrder(board.id, 'in_progress', [b.id, p.id]);
      s.setColumnOrder(board.id, 'to_do', [a.id]);

      expect(
        s.boardCards(board.id, status: 'to_do').map((e) => e.id).toList(),
        [a.id],
      );
      expect(
        s.boardCards(board.id, status: 'in_progress').map((e) => e.id).toList(),
        [b.id, p.id],
      );
      expect(s.card(b.id)!.status, 'in_progress');
    });

    test('setColumnOrder ignores ids outside the column', () async {
      final s = await freshStore();
      final board = s.activeBoard!;
      final tpl = cardTemplateId(s);
      final a = s.instantiateCard(tpl, boardId: board.id, title: 'A')!;
      final b = s.instantiateCard(tpl, boardId: board.id, title: 'B')!;

      s.setColumnOrder(board.id, 'to_do', ['nope', a.id, b.id, 'ghost']);
      final cards = s.boardCards(board.id, status: 'to_do');
      expect(cards.map((e) => e.id).toList(), [a.id, b.id]);
    });

    test('order survives a persistence round-trip', () async {
      final s = await freshStore();
      final board = s.activeBoard!;
      final tpl = cardTemplateId(s);
      final a = s.instantiateCard(tpl, boardId: board.id, title: 'A')!;
      final b = s.instantiateCard(tpl, boardId: board.id, title: 'B')!;
      final c = s.instantiateCard(tpl, boardId: board.id, title: 'C')!;
      s.setColumnOrder(board.id, 'to_do', [c.id, a.id, b.id]);

      final s2 = SmartGenStore();
      await s2.load();
      final cards = s2.boardCards(board.id, status: 'to_do');
      expect(
        cards.map((e) => e.id).toList(),
        [c.id, a.id, b.id],
      );
      expect(
        cards.map((e) => e.title).toList(),
        ['C', 'A', 'B'],
      );
    });

    test('duplicate lands at end of column', () async {
      final s = await freshStore();
      final board = s.activeBoard!;
      final tpl = cardTemplateId(s);
      final a = s.instantiateCard(tpl, boardId: board.id, title: 'A')!;
      final b = s.instantiateCard(tpl, boardId: board.id, title: 'B')!;
      final dup = s.duplicateCard(a.id)!;

      final cards = s.boardCards(board.id, status: 'to_do');
      expect(cards.map((e) => e.id).toList(), [a.id, b.id, dup.id]);
    });
  });
}
