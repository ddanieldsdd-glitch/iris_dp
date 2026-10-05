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

  /// Deja pasar la pausa de guardado de la ficha.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  testWidgets('añadir un acto abre su ficha y se guarda al escribir', (
    tester,
  ) async {
    await pump(tester);
    await tester.ensureVisible(find.text('AÑADIR ACTO O PUNTO DE GIRO'));
    await tester.tap(find.text('AÑADIR ACTO O PUNTO DE GIRO'));
    await tester.pumpAndSettle();
    // Es una página, no un diálogo: no hay «Guardar».
    expect(find.text('Guardar'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextField, 'Título del acto'),
      'Cierre',
    );
    await settle(tester);
    expect(acts.map((a) => a.title), ['Orden', 'Ruptura', 'Cierre']);
    expect(acts.last.id, isNotEmpty, reason: 'nace con identidad');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('03'), findsOneWidget);
  });

  testWidgets('una ficha nueva que se deja vacía no añade nada', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('AÑADIR ACTO O PUNTO DE GIRO'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(acts.length, 2);
  });

  testWidgets('la ficha desarrolla el acto con puntos', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Orden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AÑADIR PUNTO'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'De qué trata'),
      'La luz de la cocina',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Desarróllalo aquí…'),
      'Fluorescente verdoso',
    );
    await settle(tester);
    expect(acts.first.points.single.title, 'La luz de la cocina');
    expect(acts.first.points.single.body, 'Fluorescente verdoso');
    expect(acts.first.imageIds, [7], reason: 'conserva sus imágenes');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('· La luz de la cocina'), findsOneWidget);
  });

  testWidgets('un acto se mueve y se elimina desde su ficha', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Orden'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mover después'));
    await tester.pumpAndSettle();
    expect(acts.map((a) => a.title), ['Ruptura', 'Orden']);
    expect(acts.last.imageIds, [7]);

    await tester.tap(find.byTooltip('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(acts.map((a) => a.title), ['Ruptura']);
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
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(acts[1].turn, isTrue);
    expect(acts.map((a) => a.id), ['a', 'b', 'c']);
    expect(find.text('PUNTO DE GIRO'), findsOneWidget);
    expect(find.text('ACTO 2'), findsOneWidget, reason: 'el tercero es el 2');
    expect(find.text('ACTO 3'), findsNothing);
  });
}
