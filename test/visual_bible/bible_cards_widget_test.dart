import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_cards_widget.dart';
import 'package:iris_dp/shared/visual_bible/bible_cards.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  testWidgets('una tarjeta se edita, se mueve y se elimina desde su ficha', (tester) async {
    var cards = const [BibleCard(title: 'Cámara'), BibleCard(title: 'POV')];
    await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => BibleCardsWidget(
          cards: cards,
          onChanged: (next) => setState(() => cards = next),
        ),
      ),
    );

    // Tocar abre la ficha, con los campos editables directamente.
    await tester.tap(find.text('POV'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextField, 'POV'),
      'Punto de vista',
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(cards.map((c) => c.title), ['Cámara', 'Punto de vista']);

    await tester.tap(find.byTooltip('Mover antes'));
    await tester.pumpAndSettle();
    expect(cards.map((c) => c.title), ['Punto de vista', 'Cámara']);

    await tester.tap(find.byTooltip('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(cards.map((c) => c.title), ['Cámara']);
  });

  testWidgets('las etiquetas se añaden y se quitan', (tester) async {
    var tags = ['Tensión'];
    await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => BibleTagsWidget(
          tags: tags,
          onChanged: (next) => setState(() => tags = next),
        ),
      ),
    );
    await tester.tap(find.text('ETIQUETA'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Calma');
    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();
    expect(tags, ['Tensión', 'Calma']);
  });
}
