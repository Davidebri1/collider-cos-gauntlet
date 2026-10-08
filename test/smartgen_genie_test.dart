import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collider_flutter/features/smartgen/state/smartgen_store.dart';
import 'package:collider_flutter/features/smartgen/widgets/smart_genie_panel.dart';

const _taskTpl = 'builtin_card_task';
const _noteTpl = 'builtin_card_note';

Future<SmartGenStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  final store = SmartGenStore();
  await store.load();
  store.genieClearHistory();
  return store;
}

Widget _panel(SmartGenStore store,
        {bool pro = true, bool elite = false}) =>
    MaterialApp(
        home: Scaffold(
            body: SmartGeniePanel(
      store: store,
      isPro: pro,
      isElite: elite,
      onClose: () {},
      onMinimize: () {},
    )));

Future<void> _ask(WidgetTester t, String text) async {
  await t.enterText(find.byType(TextField), text);
  await t.testTextInput.receiveAction(TextInputAction.done);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('genie renders persisted conversation history', (t) async {
    final store = await _store();
    store.geniePush(true, 'Hello genie');
    store.geniePush(false, 'Hello human');

    await t.pumpWidget(_panel(store));
    await t.pumpAndSettle();

    expect(find.text('Hello genie'), findsOneWidget);
    expect(find.text('Hello human'), findsOneWidget);
  });

  testWidgets('genie new conversation clears persisted history', (t) async {
    final store = await _store();
    store.geniePush(true, 'Remember this');

    await t.pumpWidget(_panel(store));
    await t.pumpAndSettle();
    expect(find.text('Remember this'), findsOneWidget);

    // Two-tap inline confirmation: first tap arms, second tap executes.
    await t.tap(find.byIcon(Icons.add_comment_outlined));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    await t.tap(find.byIcon(Icons.warning_amber_rounded));
    await t.pumpAndSettle();

    expect(find.text('Remember this'), findsNothing);
    expect(store.genieHistory, isEmpty);
  });

  testWidgets('genie bulk marks all todo cards urgent', (t) async {
    final store = await _store();
    final board = store.activeBoard!;
    store.instantiateCard(_taskTpl,
        boardId: board.id, status: 'to_do', title: 'TodoOne');
    store.instantiateCard(_taskTpl,
        boardId: board.id, status: 'to_do', title: 'TodoTwo');
    store.instantiateCard(_taskTpl,
        boardId: board.id, status: 'done', title: 'DoneOne');

    await t.pumpWidget(_panel(store));
    await t.pumpAndSettle();
    await _ask(t, 'mark all todo cards urgent');

    final cards = store.boardCards(board.id);
    expect(cards.firstWhere((c) => c.title == 'TodoOne').urgent, isTrue);
    expect(cards.firstWhere((c) => c.title == 'TodoTwo').urgent, isTrue);
    expect(cards.firstWhere((c) => c.title == 'DoneOne').urgent, isFalse);
    expect(find.textContaining('Marked 2 cards urgent'), findsOneWidget);
  });

  testWidgets('genie bulk delete asks for confirmation', (t) async {
    final store = await _store();
    final board = store.activeBoard!;
    store.instantiateCard(_taskTpl,
        boardId: board.id, status: 'done', title: 'GoneOne');
    store.instantiateCard(_taskTpl,
        boardId: board.id, status: 'to_do', title: 'StaysOne');

    await t.pumpWidget(_panel(store));
    await t.pumpAndSettle();
    await _ask(t, 'delete all done cards');

    // Not deleted yet — confirmation pending.
    expect(
        store.boardCards(board.id).any((c) => c.title == 'GoneOne'), isTrue);
    expect(find.textContaining('Reply "yes" to confirm'), findsOneWidget);

    await _ask(t, 'yes');
    expect(
        store.boardCards(board.id).any((c) => c.title == 'GoneOne'), isFalse);
    expect(
        store.boardCards(board.id).any((c) => c.title == 'StaysOne'), isTrue);
    expect(find.textContaining('Deleted 1 card.'), findsOneWidget);
  });

  testWidgets('genie converts a single card to another type', (t) async {
    final store = await _store();
    final board = store.activeBoard!;
    store.instantiateCard(_taskTpl,
        boardId: board.id, status: 'to_do', title: 'ConvertMe');

    await t.pumpWidget(_panel(store));
    await t.pumpAndSettle();
    await _ask(t, 'convert ConvertMe to note');

    final card = store.boardCards(board.id)
        .firstWhere((c) => c.title == 'ConvertMe');
    expect(card.templateId, _noteTpl);
    expect(find.textContaining('is now a "Note" card'), findsOneWidget);
  });

  testWidgets('genie converts all cards of a type', (t) async {
    final store = await _store();
    final board = store.activeBoard!;
    store.instantiateCard(_taskTpl,
        boardId: board.id, status: 'to_do', title: 'BulkA');
    store.instantiateCard(_taskTpl,
        boardId: board.id, status: 'to_do', title: 'BulkB');

    await t.pumpWidget(_panel(store));
    await t.pumpAndSettle();
    await _ask(t, 'convert all task cards to notes');

    final cards = store.boardCards(board.id);
    expect(cards.where((c) => c.templateId == _noteTpl).length, 2);
    expect(find.textContaining('Converted 2 "Task" cards'), findsOneWidget);
  });

  testWidgets('genie reports context counts', (t) async {
    final store = await _store();
    final board = store.activeBoard!;
    store.instantiateCard(_taskTpl,
        boardId: board.id, status: 'to_do', title: 'Counted');

    await t.pumpWidget(_panel(store));
    await t.pumpAndSettle();
    await _ask(t, 'how many cards do I have');

    expect(find.textContaining('Context:'), findsOneWidget);
    expect(find.textContaining('card'), findsWidgets);
  });

  testWidgets('genie shows LOCAL status without an API key', (t) async {
    final store = await _store();
    await t.pumpWidget(_panel(store));
    await t.pumpAndSettle();
    // No --dart-define key in tests, so the panel must be honest: LOCAL.
    expect(find.text('LOCAL'), findsOneWidget);
  });

  testWidgets('elite /agent queues a tracked task card', (t) async {
    final store = await _store();
    final board = store.activeBoard!;

    await t.pumpWidget(_panel(store, elite: true));
    await t.pumpAndSettle();
    await _ask(t, '/agent fix the login bug');

    expect(
        store.boardCards(board.id)
            .any((c) => c.title == 'Agent: fix the login bug'),
        isTrue);
    expect(find.textContaining('Queued for your attached coding agent'),
        findsOneWidget);
  });

  testWidgets('non-pro bulk commands stay gated', (t) async {
    final store = await _store();
    await t.pumpWidget(_panel(store, pro: false));
    await t.pumpAndSettle();
    await _ask(t, 'mark all cards urgent');
    expect(find.textContaining('need Collider Pro'), findsOneWidget);
  });
}
