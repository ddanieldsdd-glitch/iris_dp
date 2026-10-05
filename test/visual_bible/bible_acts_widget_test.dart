import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_acts_widget.dart';
import 'package:iris_dp/shared/visual_bible/bible_cards.dart';

void main() {
  late List<BibleCard> acts;

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => BibleActsView(
              acts: acts,
              onChanged: (next) => setState(() => acts = next),
            ),
          ),
        ),
      ),
    ),
  );

  setUp(() {
    acts = const [
      BibleCard(
        kicker: 'calma',
        title: 'Orden',
        body: 'Planos fijos',
        imageIds: [7],
      ),
      BibleCard(title: 'Ruptura'),
    ];
  });

  testWidgets('cada acto lleva su número, su fase y un hueco de imagen', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(find.text('ACTO 1 · CALMA'), findsOneWidget);
    expect(find.text('ACTO 2'), findsOneWidget);
    // Sin ruta de imagen conocida, la tarjeta ofrece ponerla.
    expect(find.text('IMAGEN DEL ACTO'), findsNWidgets(2));
  });

  testWidgets('añadir un acto', (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.text('AÑADIR ACTO O PUNTO DE GIRO'));
    await tester.tap(find.text('AÑADIR ACTO O PUNTO DE GIRO'));
    await tester.pumpAndSettle();
    expect(find.text('Acto 3'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Título'), 'Cierre');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(acts.map((a) => a.title), ['Orden', 'Ruptura', 'Cierre']);
    expect(find.text('03'), findsOneWidget);
  });

  testWidgets('editar un acto conserva sus imágenes; se mueve y se elimina', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Orden'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mover después'));
    await tester.pumpAndSettle();
    expect(acts.map((a) => a.title), ['Ruptura', 'Orden']);
    expect(acts.last.imageIds, [7]);

    await tester.tap(find.text('Ruptura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(acts.map((a) => a.title), ['Orden']);
  });

  testWidgets('un punto de giro no se numera y conserva la identidad del acto', (
    tester,
  ) async {
    acts = const [
      BibleCard(id: 'a', title: 'Orden'),
      BibleCard(id: 'b', title: 'La carta'),
      BibleCard(id: 'c', title: 'Ruptura'),
    ];
    await pump(tester);
    await tester.tap(find.text('La carta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Punto de giro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(acts[1].turn, isTrue);
    expect(acts.map((a) => a.id), ['a', 'b', 'c']);
    expect(find.text('PUNTO DE GIRO'), findsOneWidget);
    expect(find.text('ACTO 2'), findsOneWidget, reason: 'el tercero es el 2');
    expect(find.text('ACTO 3'), findsNothing);
  });
}
