import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collider_flutter/features/smartgen/models/smartgen_models.dart';
import 'package:collider_flutter/features/smartgen/state/smartgen_store.dart';
import 'package:collider_flutter/features/smartgen/widgets/component_drawer.dart';

const _taskTpl = 'builtin_card_task';

Future<SmartGenStore> _store() async {
  final store = SmartGenStore();
  await store.load();
  return store;
}

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
          body: SizedBox.fromSize(size: const Size(390, 844), child: child)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('bulkSet applies priority to multiple cards', () async {
    final store = await _store();
    final board = store.activeBoard!;
    final c1 = store.instantiateCard(_taskTpl, boardId: board.id, title: 'B1');
    final c2 = store.instantiateCard(_taskTpl, boardId: board.id, title: 'B2');
    expect(c1, isNotNull);
    expect(c2, isNotNull);

    store.bulkSet([c1!.id, c2!.id], priority: 'P0');

    expect(store.card(c1.id)!.priority, 'P0');
    expect(store.card(c2.id)!.priority, 'P0');
  });

  test('bulkSet applies urgent flag to multiple cards', () async {
    final store = await _store();
    final board = store.activeBoard!;
    final c1 = store.instantiateCard(_taskTpl, boardId: board.id, title: 'U1');
    expect(c1, isNotNull);

    store.bulkSet([c1!.id], urgent: true);

    expect(store.card(c1.id)!.urgent, isTrue);
  });

  test('bulkDelete removes multiple cards', () async {
    final store = await _store();
    final board = store.activeBoard!;
    final c1 = store.instantiateCard(_taskTpl, boardId: board.id, title: 'D1');
    final c2 = store.instantiateCard(_taskTpl, boardId: board.id, title: 'D2');
    expect(c1, isNotNull);
    expect(c2, isNotNull);

    store.bulkDelete([c1!.id, c2!.id]);

    expect(store.card(c1.id), isNull);
    expect(store.card(c2.id), isNull);
  });

  testWidgets('component drawer inline create type works', (t) async {
    final store = await _store();
    final before = store.templatesOf(ComponentKind.card).length;

    await t.pumpWidget(_wrap(ComponentDrawer(
      kind: ComponentKind.card,
      store: store,
      onClose: () {},
    )));
    await t.pumpAndSettle();

    // Tap "Create custom card type".
    await t.tap(find.textContaining('Create custom'));
    await t.pumpAndSettle();

    // Inline name field should appear (not a dialog).
    expect(find.byType(TextField), findsWidgets);
    expect(find.byType(Dialog), findsNothing);

    // Enter a name and submit.
    await t.enterText(find.byType(TextField).last, 'My Custom Type');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();

    // A new template should have been created.
    final after = store.templatesOf(ComponentKind.card).length;
    expect(after, before + 1);
    expect(
        store
            .templatesOf(ComponentKind.card)
            .any((e) => e.name == 'My Custom Type'),
        isTrue);
  });

  testWidgets('component drawer inline create cancels cleanly', (t) async {
    final store = await _store();
    final before = store.templatesOf(ComponentKind.card).length;

    await t.pumpWidget(_wrap(ComponentDrawer(
      kind: ComponentKind.card,
      store: store,
      onClose: () {},
    )));
    await t.pumpAndSettle();

    await t.tap(find.textContaining('Create custom'));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);

    // Cancel via the close icon.
    await t.tap(find.byIcon(Icons.close_rounded).last);
    await t.pumpAndSettle();

    // No template created, field dismissed.
    final after = store.templatesOf(ComponentKind.card).length;
    expect(after, before);
  });
}
