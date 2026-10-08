import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collider_flutter/features/smartgen/models/smartgen_models.dart';
import 'package:collider_flutter/features/smartgen/state/smartgen_store.dart';
import 'package:collider_flutter/features/smartgen/widgets/sg_board_views.dart';

SmartGenStore _seedStore() {
  final store = SmartGenStore();
  final board =
      store.instantiateBoard('whiteboard_empty', title: 'Views');
  final c1 = store.instantiateCard('task',
      boardId: board.id, title: 'Alpha', status: 'to_do')!;
  c1.dueAt = DateTime(2026, 9, 22);
  c1.attachments = [
    CardAttachment(
        id: 'a1',
        name: 'img',
        mime: 'image/png',
        dataUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
  ];
  store.updateCard(c1);
  store.instantiateCard('task',
      boardId: board.id, title: 'Beta', status: 'done')!;
  store.instantiateCard('task', boardId: board.id, title: 'Gamma')!;
  return store;
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('SGCalendarView renders', (t) async {
    final store = _seedStore();
    final board = store.activeBoard!;
    await t.pumpWidget(_wrap(SGCalendarView(board: board, store: store)));
    await t.pumpAndSettle();
    expect(find.byType(SGCalendarView).evaluate().isNotEmpty, isTrue);
  });

  testWidgets('SGNotebookView renders', (t) async {
    final store = _seedStore();
    final board = store.activeBoard!;
    await t.pumpWidget(_wrap(SGNotebookView(board: board, store: store)));
    await t.pumpAndSettle();
    expect(find.byType(SGNotebookView).evaluate().isNotEmpty, isTrue);
  });

  testWidgets('SGAlbumView renders', (t) async {
    final store = _seedStore();
    final board = store.activeBoard!;
    await t.pumpWidget(_wrap(SGAlbumView(board: board, store: store)));
    await t.pumpAndSettle();
    expect(find.byType(SGAlbumView).evaluate().isNotEmpty, isTrue);
  });

  testWidgets('SGStoryboardView renders', (t) async {
    final store = _seedStore();
    final board = store.activeBoard!;
    await t.pumpWidget(_wrap(SGStoryboardView(board: board, store: store)));
    await t.pumpAndSettle();
    expect(find.byType(SGStoryboardView).evaluate().isNotEmpty, isTrue);
  });

  testWidgets('SGVisionBoardView renders', (t) async {
    final store = _seedStore();
    final board = store.activeBoard!;
    await t.pumpWidget(_wrap(SGVisionBoardView(board: board, store: store)));
    await t.pumpAndSettle();
    expect(find.byType(SGVisionBoardView).evaluate().isNotEmpty, isTrue);
  });

  testWidgets('SGSwimlaneView renders', (t) async {
    final store = _seedStore();
    final board = store.activeBoard!;
    await t.pumpWidget(_wrap(SGSwimlaneView(board: board, store: store)));
    await t.pumpAndSettle();
    expect(find.byType(SGSwimlaneView).evaluate().isNotEmpty, isTrue);
  });

  testWidgets('SGMapView US renders', (t) async {
    final store = _seedStore();
    final board = store.activeBoard!;
    await t.pumpWidget(_wrap(SGMapView(board: board, store: store)));
    await t.pumpAndSettle();
    expect(find.byType(SGMapView).evaluate().isNotEmpty, isTrue);
  });

  testWidgets('SGMapView world renders', (t) async {
    final store = _seedStore();
    final board = store.activeBoard!;
    await t.pumpWidget(
        _wrap(SGMapView(board: board, store: store, world: true)));
    await t.pumpAndSettle();
    expect(find.byType(SGMapView).evaluate().isNotEmpty, isTrue);
  });
}
