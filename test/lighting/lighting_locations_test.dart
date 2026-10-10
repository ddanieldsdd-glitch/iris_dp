import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/services/lighting_narrative_cards_service.dart';
import 'package:iris_dp/features/visual_bible/widgets/lighting/lighting_locations_block.dart';
import 'package:iris_dp/shared/visual_bible/lighting_metrics.dart';
import 'package:iris_dp/shared/visual_bible/narrative_card_kind.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/snapshot.dart';

void main() {
  testWidgets('cada localización sale una vez, con sus sets dentro', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await loadSnapshotFonts();
    tester.view.physicalSize = const Size(1300, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // La base no se cierra: con consultas vivas el cierre deja el test
    // esperando. Es una base en memoria.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    late int projectId;
    late int bibleId;
    late int siteId;
    await tester.runAsync(() async {
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
      bibleId = (await db.ensureVisualBibleForProject(projectId)).id;
      final raval = await db.ensureSiteAndSet(
        projectId: projectId,
        siteName: 'CALLE RAVAL',
        setName: 'CALLE RAVAL',
      );
      siteId = raval.site.id;
      await db.ensureSiteAndSet(
        projectId: projectId,
        siteName: 'CALLE RAVAL',
        setName: 'PORTAL',
      );
      await db.ensureSiteAndSet(
        projectId: projectId,
        siteName: 'KEBAB KHALED',
        setName: 'KEBAB KHALED',
      );
      await LightingNarrativeCardsService.ensureSeeded(
        db: db,
        bibleId: bibleId,
        projectId: projectId,
      );
      // La localización entera ya tiene luz pensada.
      final card = (await db.select(db.visualBibleNarrativeCards).get())
          .firstWhere(
            (c) =>
                c.kind == NarrativeCardKind.locationLight &&
                c.locationBasePlanId == raval.set.id,
          );
      await db.updateNarrativeCard(
        card.copyWith(
          body: const Value('Sodio de farola y sombras largas'),
          metaJson: Value(
            jsonEncode({
              'light': const LightingMetrics(kelvin: 2100, ratio: 8).toJson(),
            }),
          ),
        ),
      );
    });

    Widget host(Widget child) => ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.pumpWidget(
      host(LightingLocationsBlock(projectId: projectId, bibleId: bibleId)),
    );
    await settle();
    expect(tester.takeException(), isNull);

    // Dos localizaciones, no tres fichas: PORTAL va dentro de CALLE RAVAL.
    expect(find.text('CALLE RAVAL'), findsOneWidget);
    expect(find.text('KEBAB KHALED'), findsOneWidget);
    expect(find.text('PORTAL'), findsNothing);
    expect(find.textContaining('1 set'), findsOneWidget);
    expect(find.text('2100 K'), findsOneWidget);
    expect(find.text('8:1'), findsOneWidget);
    expect(find.textContaining('Sin desarrollar'), findsOneWidget);

    // La página de la localización: sus dos sets, uno debajo de otro.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: LightingSitePage(
            projectId: projectId,
            bibleId: bibleId,
            siteId: siteId,
            globalMetrics: const LightingMetrics(kelvin: 5600, ratio: 2),
          ),
        ),
      ),
    );
    await settle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('toda la localización'), findsOneWidget);
    expect(find.text('PORTAL'), findsOneWidget);
    // Lo que la ficha ya tenía sale en sus puntos nuevos.
    expect(find.text('Sodio de farola y sombras largas'), findsOneWidget);
    expect(find.text('2100 K'), findsWidgets);
    // Cada set es una ficha completa, con su plantilla de puntos.
    for (final point in [
      'CÓMO LA IMAGINAMOS',
      'LA LUZ DEL LUGAR',
      'DE DÍA',
      'DE NOCHE',
      'PALETA DE ESTA LUZ',
      'FUENTES Y APARATOS',
      'PROBLEMAS Y SOLUCIONES',
    ]) {
      expect(find.text(point), findsNWidgets(2), reason: point);
    }
    expect(find.byTooltip('Opciones del punto'), findsWidgets);

    // Escribir en un punto de un set lo guarda en su ficha y no en la otra.
    await tester.enterText(
      find
          .byWidgetPredicate(
            (w) =>
                w is TextField &&
                (w.decoration?.hintText ?? '').startsWith('Cómo entra el sol'),
          )
          .first,
      'Sol rasante hasta las 11',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await settle();
    late List<VisualBibleNarrativeCard> cards;
    await tester.runAsync(
      () async => cards = await db.select(db.visualBibleNarrativeCards).get(),
    );
    final withDay = cards
        .where((c) => (c.metaJson ?? '').contains('Sol rasante hasta las 11'))
        .toList();
    expect(withDay.length, 1);
    expect(withDay.single.body, 'Sodio de farola y sombras largas');

    await saveSnapshot(tester, 'luz_localizacion');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
