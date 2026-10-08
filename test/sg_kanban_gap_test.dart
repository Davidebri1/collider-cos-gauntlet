import 'package:flutter_test/flutter_test.dart';
import 'package:collider_flutter/features/smartgen/models/smartgen_models.dart';
import 'package:collider_flutter/features/smartgen/widgets/sg_kanban.dart';

SmartCard _card(String id, {String status = 'to_do', bool urgent = false}) =>
    SmartCard(
      id: id,
      templateId: 't',
      boardId: 'b',
      status: status,
      title: id,
      urgent: urgent,
    );

List<String> _ids(List<SmartCard> cards) => cards.map((c) => c.id).toList();

void main() {
  group('insertAtVisibleGap', () {
    test('unfiltered drop inserts in the middle', () {
      final a = _card('a'), b = _card('b'), c = _card('c'), x = _card('x');
      final order = insertAtVisibleGap(
        full: [a, b, c],
        visible: [a, b, c],
        dragged: x,
        visibleGap: 1,
      );
      expect(_ids(order), ['a', 'x', 'b', 'c']);
    });

    test('same-column reorder moves card within full order', () {
      final a = _card('a'), b = _card('b'), c = _card('c');
      final order = insertAtVisibleGap(
        full: [a, b, c],
        visible: [a, b, c],
        dragged: c,
        visibleGap: 0,
      );
      expect(_ids(order), ['c', 'a', 'b']);
    });

    test('filtered drop keeps hidden cards in place', () {
      // Only urgent cards visible; dropping among them must not disturb
      // the hidden ones interleaved in the full order.
      final h1 = _card('h1');
      final v1 = _card('v1', urgent: true);
      final h2 = _card('h2');
      final v2 = _card('v2', urgent: true);
      final x = _card('x', urgent: true);
      final order = insertAtVisibleGap(
        full: [h1, v1, h2, v2],
        visible: [v1, v2],
        dragged: x,
        visibleGap: 1, // before v2 in the visible list
      );
      expect(_ids(order), ['h1', 'v1', 'h2', 'x', 'v2']);
    });

    test('filtered drop at end appends after last full card', () {
      final h1 = _card('h1');
      final v1 = _card('v1', urgent: true);
      final x = _card('x', urgent: true);
      final order = insertAtVisibleGap(
        full: [h1, v1],
        visible: [v1],
        dragged: x,
        visibleGap: 1,
      );
      expect(_ids(order), ['h1', 'v1', 'x']);
    });

    test('drop into empty column appends', () {
      final x = _card('x');
      final order = insertAtVisibleGap(
        full: [],
        visible: [],
        dragged: x,
        visibleGap: 0,
      );
      expect(_ids(order), ['x']);
    });

    test('anchor missing from full order falls back to append', () {
      final a = _card('a');
      final ghost = _card('ghost');
      final x = _card('x');
      final order = insertAtVisibleGap(
        full: [a],
        visible: [ghost],
        dragged: x,
        visibleGap: 0,
      );
      expect(_ids(order), ['a', 'x']);
    });
  });
}
