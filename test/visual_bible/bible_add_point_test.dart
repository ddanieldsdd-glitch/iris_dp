import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_add_point.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/bible_widget_catalog.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

void main() {
  Future<BibleAddedPoint? Function()> open(
    WidgetTester tester, {
    String sectionId = 'custom_1',
    List<BibleSectionField>? fields,
  }) async {
    BibleAddedPoint? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => BibleAddPointTile(
              onTap: () async => result = await showBibleAddPointDialog(
                context,
                sectionId: sectionId,
                fields: fields ?? const [],
              ),
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
    await tester.ensureVisible(find.text('Paleta maestra'));
    await tester.tap(find.text('Paleta maestra'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Añadir'));
    await tester.pumpAndSettle();

    final added = result();
    expect(added!.field.label, 'Paleta maestra');
    expect(added.field.type, BibleSectionFieldType.palette);
    expect(added.field.widget, 'palette_master');
    expect(added.initialValue, isNull);
  });

  testWidgets('devuelve el punto con el nombre y el widget elegidos', (
    tester,
  ) async {
    final result = await open(tester);
    await tester.enterText(find.byType(TextField), 'Notas del foquista');
    await tester.ensureVisible(find.text('Datos técnicos'));
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

  testWidgets('ofrece los puntos de la pantalla que no están puestos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Dirección sin «Tono y atmósfera».
    final fields = BibleSectionFieldsConfig.defaultsFor(
      BibleSectionId.direction,
    ).where((f) => f.key != 'tone').toList();
    final result = await open(
      tester,
      sectionId: BibleSectionId.direction,
      fields: fields,
    );

    expect(find.text('DE ESTA PANTALLA'), findsOneWidget);
    expect(find.text('RECOMENDADOS PARA ESTA PANTALLA'), findsOneWidget);
    // Lo recomendado no se repite en su familia.
    expect(find.text('División por actos'), findsOneWidget);
    expect(find.text('COLOR'), findsOneWidget);
    expect(find.text('Key Frame'), findsNothing, reason: 'ya no existe');

    await tester.tap(find.text('Tono y atmósfera'));
    await tester.pump();
    // Un punto de la pantalla no pide nombre: conserva el suyo y su clave.
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Añadir'));
    await tester.pumpAndSettle();

    final added = result()!;
    expect(added.field.key, 'tone');
    expect(added.initialValue, isNull);
  });

  testWidgets('con todos los puntos puestos solo ofrece widgets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(
      tester,
      sectionId: BibleSectionId.workflow,
      fields: BibleSectionFieldsConfig.defaultsFor(BibleSectionId.workflow),
    );
    expect(find.text('DE ESTA PANTALLA'), findsNothing);
    expect(find.text('RECOMENDADOS PARA ESTA PANTALLA'), findsNothing);
    expect(find.text('Paleta compacta'), findsOneWidget);
  });
}
