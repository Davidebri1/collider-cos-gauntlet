import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collider_flutter/features/smartgen/models/smartgen_models.dart';
import 'package:collider_flutter/features/smartgen/state/smartgen_store.dart';
import 'package:collider_flutter/features/smartgen/widgets/component_drawer.dart';
import 'package:collider_flutter/features/smartgen/widgets/smart_canvas_widget.dart';
import 'package:collider_flutter/features/smartgen/widgets/smart_card_widget.dart';
import 'package:collider_flutter/features/smartgen/widgets/smart_genie_panel.dart';

const _taskTpl = 'builtin_card_task';
const _canvasTpl = 'builtin_canvas_glass';

Future<SmartGenStore> _store() async {
  final store = SmartGenStore();
  await store.load();
  return store;
}

Widget _wrap(Widget child, {Size surface = const Size(390, 844)}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox.fromSize(size: surface, child: child),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('component drawer deploys a card instance onto the board',
      (t) async {
    final store = await _store();
    final board = store.activeBoard!;
    final before = store.boardCards(board.id).length;

    await t.pumpWidget(_wrap(ComponentDrawer(
      kind: ComponentKind.card,
      store: store,
      onClose: () {},
    )));
    await t.pumpAndSettle();

    // Each type tile advertises tap-to-deploy.
    final tiles = find.textContaining('tap to deploy');
    expect(tiles, findsWidgets);
    await t.tap(tiles.first);
    await t.pumpAndSettle();

    expect(store.boardCards(board.id).length, before + 1);
    expect(store.boardCards(board.id).last.title, startsWith('New '));
  });

  testWidgets('card menu duplicate creates a second card', (t) async {
    final store = await _store();
    final board = store.activeBoard!;
    final card = store.instantiateCard(_taskTpl,
        boardId: board.id, status: 'to_do', title: 'Ship it')!;

    await t.pumpWidget(_wrap(
      SmartCardWidget(
        card: card,
        template: store.template(card.templateId),
        store: store,
        kanbanMode: false,
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('Ship it'), findsOneWidget);

    await t.tap(find.byIcon(Icons.more_horiz_rounded));
    await t.pumpAndSettle();
    expect(find.text('Duplicate'), findsOneWidget);

    await t.tap(find.text('Duplicate'));
    await t.pumpAndSettle();

    final copies =
        store.boardCards(board.id).where((c) => c.title.startsWith('Ship it'));
    expect(copies.length, 2);
    expect(copies.map((c) => c.title).toSet(), {'Ship it', 'Ship it copy'});
  });

  testWidgets('canvas renders its title and an adopted card', (t) async {
    final store = await _store();
    final board = store.activeBoard!;
    final canvas = store.instantiateCanvas(_canvasTpl,
        boardId: board.id, title: 'Ideas')!;
    final card = store.instantiateCard(_taskTpl,
        boardId: board.id, status: 'to_do', title: 'Adopted')!;
    store.moveCard(card.id, canvasId: canvas.id, x: 8, y: 8);

    await t.pumpWidget(_wrap(
      SmartCanvasWidget(
        canvas: canvas,
        template: store.template(canvas.templateId),
        store: store,
        boardSize: const Size(390, 844),
      ),
      surface: const Size(390, 844),
    ));
    await t.pumpAndSettle();

    expect(find.text('Ideas'), findsWidgets);
    expect(find.text('Adopted'), findsOneWidget);
  });

  testWidgets('genie creates a card from natural language', (t) async {
    final store = await _store();
    final board = store.activeBoard!;

    await t.pumpWidget(_wrap(SmartGeniePanel(
      store: store,
      isPro: true,
      onClose: () {},
      onMinimize: () {},
    )));
    await t.pumpAndSettle();

    await t.enterText(
        find.byType(TextField), 'Create a task card called Launch plan');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();

    final created = store
        .boardCards(board.id)
        .where((c) => c.title == 'Launch plan');
    expect(created, isNotEmpty);
    expect(find.textContaining('Created "Launch plan"'), findsOneWidget);
  });

  testWidgets('genie moves a card between columns', (t) async {
    final store = await _store();
    final board = store.activeBoard!;
    store.instantiateCard(_taskTpl,
        boardId: board.id, status: 'to_do', title: 'Movable');

    await t.pumpWidget(_wrap(SmartGeniePanel(
      store: store,
      isPro: true,
      onClose: () {},
      onMinimize: () {},
    )));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), 'move Movable to done');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();

    final card = store
        .boardCards(board.id)
        .firstWhere((c) => c.title == 'Movable');
    expect(card.status, 'done');
    expect(find.textContaining('Moved "Movable"'), findsOneWidget);
  });
}