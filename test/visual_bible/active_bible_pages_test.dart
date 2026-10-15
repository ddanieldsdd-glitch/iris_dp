import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/active_bible_pages.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';

void main() {
  const fields = [
    BibleSectionField(key: 'mosaic', label: 'Cómo la imaginamos'),
    BibleSectionField(key: 'how', label: 'La luz del lugar'),
  ];

  test('la ficha se anuncia al abrirse y se quita al cerrarse', () {
    final pages = ActiveBiblePages();
    final page = ActiveBiblePage(
      id: 'a',
      title: 'CALLE RAVAL',
      fields: fields,
      onFieldsChanged: (_, {dropValues = const {}}) {},
    );
    pages.show(page);
    pages.show(page);
    expect(pages.state, hasLength(1));
    pages.hide('a');
    expect(pages.state, isEmpty);
  });

  testWidgets('el panel enseña los widgets de la ficha y los cambia', (
    tester,
  ) async {
    List<BibleSectionField>? changed;
    Set<String>? dropped;
    final page = ActiveBiblePage(
      id: 'a',
      title: 'CALLE RAVAL',
      fields: fields,
      onFieldsChanged: (next, {dropValues = const {}}) {
        changed = next;
        dropped = dropValues;
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: ActiveBiblePagesPanel(pages: [page]),
            ),
          ),
        ),
      ),
    );
    expect(find.text('WIDGETS DE ESTA FICHA · CALLE RAVAL'), findsOneWidget);
    expect(find.text('Cómo la imaginamos'), findsOneWidget);
    expect(find.text('La luz del lugar'), findsOneWidget);

    await tester.tap(find.byTooltip('Opciones del widget').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subir'));
    await tester.pumpAndSettle();
    expect(changed!.map((f) => f.key), ['how', 'mosaic']);

    await tester.tap(find.byTooltip('Opciones del widget').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar de la ficha'));
    await tester.pumpAndSettle();
    expect(changed!.map((f) => f.key), ['how']);
    expect(dropped, {'mosaic'});
    expect(tester.takeException(), isNull);
  });
}
