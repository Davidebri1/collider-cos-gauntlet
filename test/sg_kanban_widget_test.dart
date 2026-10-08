import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collider_flutter/features/smartgen/screens/smartgen_screen.dart';
import 'package:collider_flutter/features/smartgen/state/smartgen_store.dart';
import 'package:collider_flutter/features/smartgen/widgets/sg_kanban.dart';

const _taskTpl = 'builtin_card_task';

Future<SmartGenStore> _seededStore() async {
  final store = SmartGenStore();
  await store.load();
  final board = store.activeBoard!;
  store.instantiateCard(_taskTpl,
      boardId: board.id, status: 'to_do', title: 'Alpha')!;
  final b = store.instantiateCard(_taskTpl,
      boardId: board.id, status: 'to_do', title: 'Beta')!;
  b.urgent = true;
  store.updateCard(b);
  store.instantiateCard(_taskTpl,
      boardId: board.id, status: 'to_do', title: 'Gamma')!;
  return store;
}

Widget _kanban(SmartGenStore store,
    {String cardFilter = 'all', String searchQuery = ''}) {
  final board = store.activeBoard!;
  return MaterialApp(
    home: Scaffold(
      body: SGKanbanBoard(
        board: board,
        template: store.template(board.templateId),
        store: store,
        cardFilter: cardFilter,
        searchQuery: searchQuery,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('SmartGenScreen composes toolbar, rail, filter bar, board',
      (t) async {
    await t.pumpWidget(
        ChangeNotifierProvider.value(
            value: await _seededStore(),
            child: MaterialApp(
                home: Scaffold(body: SmartGenScreen(onClose: () {})))));
    await t.pumpAndSettle();

    expect(find.text('My Board'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.text('Cards'), findsOneWidget);
    expect(find.text('Genie'), findsOneWidget);
    // The default board is "Kanban with Swimlanes", so the screen shows the
    // swimlane surface with its default lane. Classic kanban columns are
    // covered by the SGKanbanBoard tests below.
    expect(find.text('General'), findsOneWidget);
  });

  testWidgets('urgent filter renders only urgent cards', (t) async {
    final store = await _seededStore();
    await t.pumpWidget(_kanban(store, cardFilter: 'urgent'));
    await t.pumpAndSettle();

    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Gamma'), findsNothing);
  });

  testWidgets('search filters rendered cards', (t) async {
    final store = await _seededStore();
    await t.pumpWidget(_kanban(store, searchQuery: 'gam'));
    await t.pumpAndSettle();

    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
  });

  testWidgets('tapping a card title renames it inline', (t) async {
    final store = await _seededStore();
    await t.pumpWidget(_kanban(store));
    await t.pumpAndSettle();

    await t.tap(find.text('Alpha'));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await t.enterText(find.byType(TextField), 'Alpha 2');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();

    expect(find.text('Alpha 2'), findsOneWidget);
    final renamed =
        store.boardCards(store.activeBoard!.id, status: 'to_do').firstWhere(
      (c) => c.title == 'Alpha 2',
    );
    expect(renamed.title, 'Alpha 2');
  });

  /// Long-presses [title], then drops it onto the center of the [gapIndex]-th
  /// visible drop gap of the first column. Gap geometry is measured after
  /// the drag arms (gaps expand), so the pointer lands on a real target.
  Future<void> dragToGap(
      WidgetTester t, String title, int gapIndex) async {
    final gesture = await t.startGesture(t.getCenter(find.text(title)));
    await t.pump(const Duration(milliseconds: 350)); // past 220ms delay
    final gapCenter = t.getCenter(
      find.byType(DragTarget<SGDragData>).at(gapIndex),
    );
    await gesture.moveTo(gapCenter);
    await t.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await t.pumpAndSettle();
  }

  testWidgets('long-press drag reorders within a column', (t) async {
    final store = await _seededStore();
    await t.pumpWidget(_kanban(store));
    await t.pumpAndSettle();

    // Gap 2 sits below Beta: dropping Alpha there yields Beta, Alpha, Gamma.
    await dragToGap(t, 'Alpha', 2);

    final order = store
        .boardCards(store.activeBoard!.id, status: 'to_do')
        .map((c) => c.title)
        .toList();
    expect(order, ['Beta', 'Alpha', 'Gamma']);
  });

  testWidgets('filtered drag keeps hidden cards in place', (t) async {
    final store = await _seededStore();
    // Only Beta (urgent) is visible; drop it on the trailing gap.
    await t.pumpWidget(_kanban(store, cardFilter: 'urgent'));
    await t.pumpAndSettle();

    expect(find.text('Beta'), findsOneWidget);
    await dragToGap(t, 'Beta', 1);

    // Full order: Beta moves to the end; hidden Alpha/Gamma are untouched.
    final order = store
        .boardCards(store.activeBoard!.id, status: 'to_do')
        .map((c) => c.title)
        .toList();
    expect(order, ['Alpha', 'Gamma', 'Beta']);
  });
}
