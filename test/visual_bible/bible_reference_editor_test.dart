import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_references_deck.dart';
import 'package:iris_dp/shared/visual_bible/bible_reference.dart';

void main() {
  Future<({List<BibleReference> changes, List<bool> deleted})> pump(
    WidgetTester tester, {
    BibleReference initial = const BibleReference(),
    List<int>? picked,
  }) async {
    final changes = <BibleReference>[];
    final deleted = <bool>[];
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BibleReferenceEditor(
                      kinds: kDirectionReferenceKinds,
                      copy: BibleReferencesCopy.direction,
                      initial: initial,
                      imagePaths: const {7: '/no/existe/a.png', 9: '/no/b.png'},
                      onChanged: changes.add,
                      onDelete: () => deleted.add(true),
                      onPickImages: (_) async => picked,
                    ),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return (changes: changes, deleted: deleted);
  }

  testWidgets('se edita en el sitio y guarda solo tras una pausa', (
    tester,
  ) async {
    final r = await pump(tester);
    expect(find.text('GUARDADO'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'El peso del entorno');
    await tester.pump();
    expect(find.text('GUARDANDO…'), findsOneWidget);
    expect(r.changes, isEmpty);

    await tester.pump(const Duration(milliseconds: 600));
    expect(r.changes.single.title, 'El peso del entorno');
    expect(find.text('GUARDADO'), findsOneWidget);
  });

  testWidgets('el tipo se guarda al momento y conserva el resto', (
    tester,
  ) async {
    final r = await pump(
      tester,
      initial: const BibleReference(title: 'Antes', why: 'Porque sí'),
    );
    await tester.tap(find.text('Puesta en escena'));
    await tester.pump();
    expect(r.changes.single.kind, 'Puesta en escena');
    expect(r.changes.single.title, 'Antes');
    expect(r.changes.single.why, 'Porque sí');
  });

  testWidgets('añadir imágenes y cambiar la portada', (tester) async {
    final r = await pump(tester, picked: [7, 9]);
    await tester.tap(find.text('AÑADIR IMÁGENES'));
    await tester.pumpAndSettle();
    expect(r.changes.last.imageIds, [7, 9]);
    expect(r.changes.last.imageId, 7);
    expect(find.text('PORTADA'), findsOneWidget);
  });

  testWidgets('al cerrar guarda lo que estaba pendiente', (tester) async {
    final r = await pump(tester);
    await tester.enterText(find.byType(TextField).first, 'Sin esperar');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(r.changes.single.title, 'Sin esperar');
  });

  testWidgets('eliminar pide confirmación y no guarda después', (tester) async {
    final r = await pump(tester, initial: const BibleReference(title: 'X'));
    await tester.enterText(find.byType(TextField).first, 'Cambio');
    await tester.pump();
    await tester.tap(find.byTooltip('Eliminar referencia'));
    await tester.pumpAndSettle();
    // La pausa de guardado puede cumplirse mientras el diálogo está abierto.
    final savedBefore = r.changes.length;
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(r.deleted, [true]);
    expect(r.changes.length, savedBefore, reason: 'no guarda tras eliminar');
  });
}
