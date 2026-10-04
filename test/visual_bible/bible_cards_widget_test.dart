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

  testWidgets('los actos se numeran y se pueden añadir', (tester) async {
    var cards = const [
      BibleCard(kicker: 'CALMA', title: 'Orden', body: 'Planos fijos'),
      BibleCard(title: 'Ruptura'),
    ];
    await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => BibleCardsWidget(
          cards: cards,
          acts: true,
          layout: BibleCardsLayout.columns,
          onChanged: (next) => setState(() => cards = next),
        ),
      ),
    );

    expect(find.text('ACTO 1 · CALMA'), findsOneWidget);
    expect(find.text('ACTO 2'), findsOneWidget);

    await tester.tap(find.text('AÑADIR ACTO'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Título'), 'Cierre');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(cards.length, 3);
    expect(cards.last.title, 'Cierre');
    expect(find.text('ACTO 3'), findsOneWidget);
  });

  testWidgets('una tarjeta se puede mover y eliminar', (tester) async {
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

    await tester.tap(find.text('POV'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mover antes'));
    await tester.pumpAndSettle();
    expect(cards.map((c) => c.title), ['POV', 'Cámara']);

    await tester.tap(find.text('Cámara'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(cards.map((c) => c.title), ['POV']);
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
