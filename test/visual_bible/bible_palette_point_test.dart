import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_palette_widget.dart';
import 'package:iris_dp/shared/visual_bible/bible_palette.dart';

void main() {
  testWidgets('el menú del punto elige qué se muestra', (tester) async {
    var value = const BiblePaletteValue(
      colors: [BiblePaletteColor(hex: '#112233', name: 'Azul')],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => BiblePalettePoint(
                  projectId: 1,
                  bibleId: 1,
                  sectionId: 'concept',
                  label: 'Paleta maestra',
                  icon: Icons.palette_outlined,
                  value: value,
                  onChanged: (next) => setState(() => value = next),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('#112233'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    // Mostrar el texto.
    await tester.tap(find.byTooltip('Qué se muestra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Texto'));
    await tester.pumpAndSettle();
    expect(value.show, {BiblePalettePart.palette, BiblePalettePart.text});
    expect(find.byType(TextField), findsOneWidget);

    // Ocultar la paleta: desaparece de la vista, no del valor.
    await tester.tap(find.byTooltip('Qué se muestra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paleta'));
    await tester.pumpAndSettle();
    expect(find.text('#112233'), findsNothing);
    expect(value.colors, hasLength(1));

    // La última parte visible no se puede ocultar.
    await tester.tap(find.byTooltip('Qué se muestra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Texto').last);
    await tester.pumpAndSettle();
    expect(value.show, {BiblePalettePart.text});
  });
}
