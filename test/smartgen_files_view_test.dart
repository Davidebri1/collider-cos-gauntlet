import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collider_flutter/features/smartgen/models/smartgen_models.dart';
import 'package:collider_flutter/features/smartgen/state/smartgen_store.dart';
import 'package:collider_flutter/features/smartgen/widgets/sg_board_views.dart';

Future<SmartGenStore> _store() async {
  final store = SmartGenStore();
  await store.load();
  return store;
}

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox.fromSize(size: const Size(390, 844), child: child),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<SmartGenStore> _seeded() async {
    final store = await _store();
    final board = store.activeBoard!;
    final c1 = store.instantiateCard('builtin_card_note',
        boardId: board.id, title: 'Site photos')!;
    store.addAttachment(
        c1.id,
        CardAttachment(
            name: 'b_facade.png',
            mime: 'image/png',
            dataUrl: 'data:image/png;base64,AAA',
            sizeBytes: 2000));
    store.addAttachment(
        c1.id,
        CardAttachment(
            name: 'a_plan.pdf',
            mime: 'application/pdf',
            sizeBytes: 5000));
    final c2 = store.instantiateCard('builtin_card_note',
        boardId: board.id, title: 'Contracts')!;
    store.addAttachment(
        c2.id,
        CardAttachment(
            name: 'c_budget.csv', mime: 'text/csv', sizeBytes: 100));
    return store;
  }

  testWidgets('files explorer lists every attachment with a count',
      (t) async {
    final store = await _seeded();
    final board = store.activeBoard!;
    await t.pumpWidget(_wrap(SGFilesView(board: board, store: store)));
    await t.pumpAndSettle();

    expect(find.text('Files · 3'), findsOneWidget);
    // Numbered sidebar entries.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    // Default sort is by name: a_plan.pdf first.
    expect(find.text('a_plan.pdf'), findsWidgets);
  });

  testWidgets('files explorer selecting a thumbnail updates the stage',
      (t) async {
    final store = await _seeded();
    final board = store.activeBoard!;
    await t.pumpWidget(_wrap(SGFilesView(board: board, store: store)));
    await t.pumpAndSettle();

    // Tap the second thumbnail (b_facade.png in name order).
    await t.tap(find.text('2'));
    await t.pumpAndSettle();
    // Stage eyebrow reflects the selection.
    expect(find.textContaining('2 of 3'), findsOneWidget);
  });

  testWidgets('files explorer duplicate then undo restores the count',
      (t) async {
    final store = await _seeded();
    final board = store.activeBoard!;
    await t.pumpWidget(_wrap(SGFilesView(board: board, store: store)));
    await t.pumpAndSettle();
    expect(find.text('Files · 3'), findsOneWidget);

    // Duplicate via the bottom toolbar.
    await t.tap(find.byTooltip('Duplicate'));
    await t.pumpAndSettle();
    expect(find.text('Files · 4'), findsOneWidget);

    // Undo restores.
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(find.text('Files · 3'), findsOneWidget);

    // Redo re-applies.
    await t.tap(find.byTooltip('Redo'));
    await t.pumpAndSettle();
    expect(find.text('Files · 4'), findsOneWidget);
  });

  testWidgets('files explorer delete removes the attachment', (t) async {
    final store = await _seeded();
    final board = store.activeBoard!;
    await t.pumpWidget(_wrap(SGFilesView(board: board, store: store)));
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('Delete'));
    await t.pumpAndSettle();
    expect(find.text('Files · 2'), findsOneWidget);
  });

  testWidgets('files explorer grid toggle switches layout', (t) async {
    final store = await _seeded();
    final board = store.activeBoard!;
    await t.pumpWidget(_wrap(SGFilesView(board: board, store: store)));
    await t.pumpAndSettle();

    // Sidebar visible initially.
    expect(find.text('1'), findsOneWidget);
    await t.tap(find.byTooltip('Toggle grid'));
    await t.pumpAndSettle();
    // Grid shows names; sidebar numbers are gone.
    expect(find.text('1'), findsNothing);
    expect(find.text('a_plan.pdf'), findsOneWidget);
  });

  testWidgets('files explorer empty state offers add', (t) async {
    final store = await _store();
    final board = store.activeBoard!;
    await t.pumpWidget(_wrap(SGFilesView(board: board, store: store)));
    await t.pumpAndSettle();

    expect(find.text('No files yet'), findsOneWidget);
    expect(find.text('Add file'), findsOneWidget);
  });

  testWidgets('files explorer sort by type groups under category headers',
      (t) async {
    final store = await _seeded();
    final board = store.activeBoard!;
    await t.pumpWidget(_wrap(SGFilesView(board: board, store: store)));
    await t.pumpAndSettle();

    await t.tap(find.text('Files · 3'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sort by type'));
    await t.pumpAndSettle();

    expect(find.text('IMAGE'), findsWidgets);
    expect(find.text('PDF'), findsWidgets);
    expect(find.text('DATA'), findsWidgets);
  });
}
