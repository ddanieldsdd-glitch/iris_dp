import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_add_point.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/bible_widget_catalog.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';

void main() {
  Future<BibleAddedPoint? Function()> open(WidgetTester tester) async {
    BibleAddedPoint? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => BibleAddPointTile(
              onTap: () async =>
                  result = await showBibleAddPointDialog(context),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('AÑADIR PUNTO'));
    await tester.pumpAndSettle();
    return () => result;
  }

  testWidgets('sin nombre, el punto toma el del widget elegido', (
    tester,
  ) async {
    final result = await open(tester);
    await tester.tap(find.text('Paleta de color'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Añadir'));
    await tester.pumpAndSettle();

    final added = result();
    expect(added!.field.label, 'Paleta de color');
    expect(added.field.type, BibleSectionFieldType.palette);
    expect(added.initialValue, isNull);
  });

  testWidgets('devuelve el punto con el nombre y el widget elegidos', (
    tester,
  ) async {
    final result = await open(tester);
    await tester.enterText(find.byType(TextField), 'Notas del foquista');
    await tester.tap(find.text('Datos técnicos'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Añadir'));
    await tester.pumpAndSettle();

    final added = result();
    expect(added, isNotNull);
    expect(added!.field.label, 'Notas del foquista');
    expect(added.field.type, BibleSectionFieldType.specs);
    expect(added.field.key, startsWith('field_'));
  });

  testWidgets('las referencias nacen con su preajuste', (tester) async {
    final result = await open(tester);
    await tester.ensureVisible(find.text('Referencias narrativas'));
    await tester.tap(find.text('Referencias narrativas'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Añadir'));
    await tester.pumpAndSettle();

    final added = result()!;
    expect(added.field.type, BibleSectionFieldType.referenceDeck);
    expect(
      BibleReferenceDeckValue.decode(added.initialValue).preset,
      BibleReferencePreset.narrative,
    );
  });

  testWidgets('cancelar no añade nada', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result(), isNull);
  });
}
