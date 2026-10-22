import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_table_widget.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/bible_widget_catalog.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_table.dart';

void main() {
  test('la tabla conserva una celda por columna y sabe si está vacía', () {
    final table = BibleTableValue.decode(
      '{"columns":["Formato","Códec"],"rows":[["ARRIRAW"],["","" ]]}',
    );
    expect(table.rows.first, ['ARRIRAW', '']);
    expect(table.filledRows.length, 1);
    expect(table.isEmpty, isFalse);

    final wider = table.addColumn('fps');
    expect(wider.rows.first.length, 3);
    final back = BibleTableValue.decode(wider.withCell(0, 2, '75').encode());
    expect(back.rows.first, ['ARRIRAW', '', '75']);
    expect(back.removeColumn(1).rows.first, ['ARRIRAW', '75']);

    expect(BibleTableValue.decode('no es json').isEmpty, isTrue);
    expect(
      BibleTableValue.decode(BibleTableValue.initial(const ['A'])).isEmpty,
      isTrue,
    );
  });

  test('un medidor saca su número y su sitio en la escala', () {
    const temp = BibleMeter(label: 'Temp', value: '5600 K', min: 2000, max: 10000);
    expect(temp.number, 5600);
    expect(temp.fraction, closeTo(0.45, 0.001));
    expect(const BibleMeter(value: '1/4', min: 0, max: 1).fraction, 0.25);
    expect(const BibleMeter(value: '8:1', min: 1, max: 16).number, 8);
    // Sin escala o sin número no hay barra.
    expect(const BibleMeter(value: '5600 K').fraction, isNull);
    expect(const BibleMeter(value: 'Dura', min: 0, max: 1).fraction, isNull);

    final round = BibleMeter.listFrom(BibleMeter.encode([temp]));
    expect(round.single.max, 10000);
    expect(round.single.value, '5600 K');
  });

  test('tabla y medidores están en el catálogo, en Datos', () {
    final table = BibleWidgetCatalog.byId('table')!;
    expect(table.type, BibleSectionFieldType.table);
    expect(table.category, BibleWidgetCategory.data);
    expect(BibleWidgetCatalog.byId('meters')!.type, BibleSectionFieldType.meters);
  });

  testWidgets('la tabla se escribe en el sitio y añade filas', (tester) async {
    BibleTableValue? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: BibleTableWidget(
            value: const BibleTableValue(columns: ['Formato', 'fps']),
            onChanged: (v) => saved = v,
          ),
        ),
      ),
    );
    await tester.tap(find.text('AÑADIR FILA'));
    await tester.pump();
    expect(saved!.rows.length, 1);

    await tester.enterText(find.byType(TextFormField).at(2), 'ARRIRAW 4.6K');
    await tester.pump(const Duration(milliseconds: 500));
    expect(saved!.rows.first.first, 'ARRIRAW 4.6K');
    expect(tester.takeException(), isNull);
  });

  testWidgets('un medidor con escala enseña su barra', (tester) async {
    List<BibleMeter>? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: BibleMetersWidget(
            meters: const [
              BibleMeter(label: 'TEMP', value: '5600 K', min: 2000, max: 10000),
              BibleMeter(label: 'CALIDAD', value: 'Dura'),
            ],
            onChanged: (v) => saved = v,
          ),
        ),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.text('AÑADIR DATO'));
    await tester.pump();
    expect(saved!.length, 3);
    expect(tester.takeException(), isNull);
  });
}
