import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collider_flutter/features/smartgen/models/smartgen_models.dart';
import 'package:collider_flutter/features/smartgen/state/smartgen_store.dart';
import 'package:collider_flutter/features/smartgen/widgets/smart_board_view.dart';

const _taskTpl = 'builtin_card_task';
const _canvasTpl = 'builtin_canvas_canvas';

Future<SmartGenStore> _store() async {
  final store = SmartGenStore();
  await store.load();
  return store;
}

/// A freeform (whiteboard) board — the only surface with the canvas navigator.
SmartBoard _freeformBoard(SmartGenStore store) =>
    store.instantiateBoard('builtin_board_whiteboard_empty', title: 'Whiteboard');

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('canvas navigator shows numbered chips and focuses a canvas',
      (t) async {
    final store = await _store();
    final board = _freeformBoard(store);
    final c1 = store.instantiateCanvas(_canvasTpl,
        boardId: board.id, title: 'Alpha')!;
    final c2 = store.instantiateCanvas(_canvasTpl,
        boardId: board.id, title: 'Beta')!;
    store.instantiateCard(_taskTpl,
        boardId: board.id, canvasId: c1.id, status: 'to_do', title: 'In Alpha');

    await t.pumpWidget(_wrap(SmartBoardView(
      board: board,
      template: store.template(board.templateId),
      store: store,
    )));
    await t.pumpAndSettle();

    // Navigator strip: overview chip + two numbered canvas chips.
    expect(find.byKey(const ValueKey('nav-overview')), findsOneWidget);
    expect(find.byKey(ValueKey('nav-canvas-${c1.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('nav-canvas-${c2.id}')), findsOneWidget);

    // Tap the first canvas chip -> focused full-bleed page with its cards.
    await t.tap(find.byKey(ValueKey('nav-canvas-${c1.id}')));
    await t.pumpAndSettle();
    expect(find.text('In Alpha'), findsOneWidget);
    expect(find.text('1 card'), findsOneWidget);

    // Back to overview via the Board chip.
    await t.tap(find.byKey(const ValueKey('nav-overview')));
    await t.pumpAndSettle();
    expect(find.byKey(ValueKey('nav-canvas-${c2.id}')), findsOneWidget);
  });

  _surfaceTests();

  testWidgets('ten-canvas cap refuses the eleventh canvas', (t) async {
    final store = await _store();
    final board = _freeformBoard(store);
    for (var i = 0; i < 10; i++) {
      expect(store.instantiateCanvas(_canvasTpl, boardId: board.id, title: 'C$i'),
          isNotNull);
    }
    expect(store.instantiateCanvas(_canvasTpl, boardId: board.id), isNull);
  });
}

void _surfaceTests() {
  testWidgets('desk board paints a wood surface', (t) async {
    final store = await _store();
    final board =
        store.instantiateBoard('builtin_board_desk', title: 'My Desk');
    await t.pumpWidget(_wrap(SmartBoardView(
      board: board,
      template: store.template(board.templateId),
      store: store,
    )));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('surface-wood')), findsOneWidget);
  });

  testWidgets('workbench paints a metal surface', (t) async {
    final store = await _store();
    final board =
        store.instantiateBoard('builtin_board_workbench', title: 'Bench');
    await t.pumpWidget(_wrap(SmartBoardView(
      board: board,
      template: store.template(board.templateId),
      store: store,
    )));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('surface-metal')), findsOneWidget);
  });
}
