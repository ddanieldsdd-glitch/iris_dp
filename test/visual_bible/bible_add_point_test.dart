import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_add_point.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';

void main() {
  Future<BibleSectionField? Function()> open(WidgetTester tester) async {
    BibleSectionField? result;
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

  testWidgets('no deja añadir un punto sin nombre', (tester) async {
    await open(tester);
    final add = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Añadir'),
    );
    expect(add.onPressed, isNull);
  });

  testWidgets('devuelve el punto con el nombre y el tipo elegidos',
      (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byType(TextField), 'Notas del foquista');
    await tester.tap(find.text('Datos técnicos'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Añadir'));
    await tester.pumpAndSettle();

    final point = result();
    expect(point, isNotNull);
    expect(point!.label, 'Notas del foquista');
    expect(point.type, BibleSectionFieldType.specs);
    expect(point.key, startsWith('field_'));
  });

  testWidgets('cancelar no añade nada', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result(), isNull);
  });
}
