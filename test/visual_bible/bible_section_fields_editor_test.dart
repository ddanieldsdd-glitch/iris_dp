import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_section_fields_editor.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required String sectionId,
    required List<BibleSectionField> fields,
  }) async {
    tester.view.physicalSize = const Size(520, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: BibleSectionFieldsEditor(
              bibleId: 1,
              embedded: true,
              definition: BibleSectionDefinition(
                id: sectionId,
                bibleId: 1,
                groupId: 'narrative',
                label: 'Pantalla',
                iconKey: 'article',
                sortOrder: 0,
                isBuiltIn: !sectionId.startsWith('custom_'),
                isHidden: false,
                template: 'standard',
                contentJson: BibleSectionFieldsConfig.encode(fields),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('lista los puntos con su nombre y sin cambiar de tipo', (
    tester,
  ) async {
    final defaults = BibleSectionFieldsConfig.defaultsFor(
      BibleSectionId.direction,
    );
    await pump(
      tester,
      sectionId: BibleSectionId.direction,
      fields: [
        defaults.firstWhere((f) => f.key == 'tone').copyWith(label: 'Mi tono'),
        const BibleSectionField(
          key: 'field_1',
          label: 'Paleta de noche',
          type: BibleSectionFieldType.palette,
        ),
      ],
    );

    // El nombre que puso el usuario, no el de fábrica.
    expect(find.text('Mi tono'), findsOneWidget);
    // Cada punto se nombra por lo que es, no como texto genérico.
    expect(
      find.textContaining('Punto de la pantalla · Puntos con título'),
      findsOneWidget,
    );
    expect(find.text('Paleta de noche'), findsOneWidget);
    expect(find.textContaining('Color · Paleta compacta'), findsOneWidget);

    expect(find.byTooltip('Cambiar tipo'), findsNothing);
    expect(find.byTooltip('Renombrar'), findsNWidgets(2));
    expect(find.byTooltip('Quitar'), findsNWidgets(2));
    expect(find.text('Añadir punto'), findsOneWidget);
    expect(find.text('Restablecer pantalla'), findsOneWidget);
    for (final gone in ['Stitch', 'módulo', 'sub-apartado']) {
      expect(find.textContaining(gone), findsNothing, reason: gone);
    }
  });

  testWidgets('quitar pide confirmación y explica qué se pierde', (
    tester,
  ) async {
    await pump(
      tester,
      sectionId: BibleSectionId.direction,
      fields: const [
        BibleSectionField(key: 'tone', label: 'Tono y atmósfera'),
        BibleSectionField(key: 'field_1', label: 'Nota propia'),
      ],
    );

    await tester.tap(find.byTooltip('Quitar').last);
    await tester.pumpAndSettle();
    expect(find.text('Quitar «Nota propia»'), findsOneWidget);
    expect(find.textContaining('Se borra con su contenido'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Nota propia'), findsOneWidget);

    await tester.tap(find.byTooltip('Quitar').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('su contenido se conserva'), findsOneWidget);
  });

  testWidgets('una pantalla personalizada no ofrece restablecer', (
    tester,
  ) async {
    await pump(
      tester,
      sectionId: 'custom_1',
      fields: const [BibleSectionField(key: 'body', label: 'Contenido')],
    );
    expect(find.text('Restablecer pantalla'), findsNothing);
    expect(find.text('Añadir punto'), findsOneWidget);
  });

  testWidgets('avisa de lo que la pantalla no pinta: «Sin vincular»', (
    tester,
  ) async {
    // Localización se pinta con bloques propios: sus puntos no se ven.
    await pump(
      tester,
      sectionId: BibleSectionId.location,
      fields: const [BibleSectionField(key: 'notes', label: 'Notas')],
    );
    expect(find.text('SIN VINCULAR'), findsOneWidget);
    expect(find.text('· Notas'), findsOneWidget);
    expect(find.text('· Ubicación, sol y meteorología'), findsOneWidget);
    expect(find.textContaining('· no se ve'), findsOneWidget);

    // Una pantalla con todo pintado no enseña el aviso.
    await pump(
      tester,
      sectionId: BibleSectionId.direction,
      fields: BibleSectionFieldsConfig.defaultsFor(BibleSectionId.direction),
    );
    expect(find.text('SIN VINCULAR'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
