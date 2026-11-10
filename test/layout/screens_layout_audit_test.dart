import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/core/update/app_release.dart';
import 'package:iris_dp/core/update/update_available_banner.dart';
import 'package:iris_dp/core/widgets/app_button.dart';
import 'package:iris_dp/features/equipment/rentals/rental_import_models.dart';
import 'package:iris_dp/features/equipment/rentals/rental_import_service.dart';
import 'package:iris_dp/features/equipment/rentals/rentals_tab.dart';
import 'package:iris_dp/features/locations/locations_screen.dart';
import 'package:iris_dp/features/shoot_documents/shoot_calendar.dart';
import 'package:iris_dp/features/shoot_documents/shoot_calendar_screen.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_on_set.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_screen.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_timeline.dart';
import 'package:iris_dp/features/shoot_documents/shoot_days_board.dart';
import 'package:iris_dp/features/shoot_documents/shoot_documents_screen.dart';

import '../helpers/layout_audit.dart';

const _sizes = {
  'iPhone': auditIphone,
  'iPad': auditIpad,
  'escritorio': auditDesktop,
};

void main() {
  late AppDatabase db;
  late int projectId;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Kebab Khaled con nombre largo'),
      );
      final siteId = await db.insertSite(
        LocationSitesCompanion.insert(
          projectId: projectId,
          name: 'RESTAURANTE KEBAB DE LA CALLE MAYOR DE TERRASSA',
        ),
      );
      for (final name in ['COCINA TRASERA DEL LOCAL', 'SALÓN']) {
        await db.insertLocation(
          LocationBasePlansCompanion.insert(
            projectId: projectId,
            locationName: name,
            siteId: Value(siteId),
          ),
        );
      }
      await db.insertShootDocument(
        ShootDocumentsCompanion.insert(
          projectId: projectId,
          name: 'Jornada 1 · Interior del restaurante, noche larga',
          shootDate: const Value('2026-11-13'),
          kind: const Value('technical_day'),
        ),
      );
    });
  }

  Future<void> pumpScreen(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.dark, home: child),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Desmontar antes de cerrar la base: si no, sus consultas vivas la cuelgan.
  Future<void> auditAndUnmount(WidgetTester tester) async {
    final error = tester.takeException();
    final problems = layoutProblems(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    expect(error, isNull);
    expect(problems, isEmpty);
  }

  for (final e in _sizes.entries) {
    testWidgets('banner de actualización · ${e.key}', (tester) async {
      setAuditSize(tester, e.value);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Column(
              children: [
                UpdateAvailableCard(
                  release: const AppRelease(
                    platform: 'ios',
                    version: '1.7.4',
                    buildNumber: 35,
                    downloadUrl: 'https://example.test/iris.ipa',
                  ),
                  actions: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppButton(label: 'Actualizar', onTap: () {}),
                      AppButton(label: 'Más tarde', onTap: () {}),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expectCleanLayout(tester);
    });

    testWidgets('localizaciones · ${e.key}', (tester) async {
      setAuditSize(tester, e.value);
      await seed(tester);
      await pumpScreen(tester, LocationsScreen(projectId: projectId));
      await auditAndUnmount(tester);
    });

    testWidgets('localización ubicada con un set abierto · ${e.key}', (
      tester,
    ) async {
      setAuditSize(tester, e.value);
      await seed(tester);
      await tester.runAsync(() async {
        final site = (await db.watchSitesForProject(projectId).first).single;
        await db.setSitePlace(
          site.id,
          latitude: 41.5632,
          longitude: 2.0089,
          placeLabel: 'Terrassa, Barcelona, Cataluña, España, con nombre largo',
        );
      });
      await pumpScreen(tester, LocationsScreen(projectId: projectId));
      final set = find.text('COCINA TRASERA DEL LOCAL').first;
      await tester.ensureVisible(set);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(set, warnIfMissed: false);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await auditAndUnmount(tester);
    });

    for (final (name, screen) in <(String, Widget Function(int, int))>[
      (
        'jornada',
        (p, d) => ShootDayScreen(projectId: p, documentId: d),
      ),
      ('plan de rodaje', (p, _) => ShootDaysBoardScreen(projectId: p)),
      (
        'en set con franjas',
        (p, d) => ShootDayOnSetScreen(projectId: p, documentId: d, title: 'J1'),
      ),
    ]) {
      testWidgets('$name · ${e.key}', (tester) async {
        setAuditSize(tester, e.value);
        await seed(tester);
        late int dayId;
        await tester.runAsync(() async {
          final site = (await db.watchSitesForProject(projectId).first).single;
          await db.setSitePlace(
            site.id,
            latitude: 41.56,
            longitude: 2.0,
            placeLabel: 'Terrassa, Barcelona, Cataluña, España, nombre largo',
          );
          final day =
              (await db.getShootDocumentsForProject(projectId)).single;
          dayId = day.id;
          await db.updateShootDocument(
            day.copyWith(
              locationSiteId: Value(site.id),
              shootFromTime: const Value('08:00'),
              shootToTime: const Value('20:00'),
            ),
          );
          final sceneId = await db.insertScene(
            ScenesCompanion.insert(
              projectId: projectId,
              number: 1,
              name: 'SALÓN',
              locationCanonical: 'INT. SALÓN DEL KEBAB MUY LARGO - NOCHE',
              locationPureName: 'SALÓN DEL KEBAB MUY LARGO',
            ),
          );
          for (final n in [1, 2, 3]) {
            final shotId = await db.insertShot(
              ShotsCompanion.insert(
                sceneId: sceneId,
                projectId: projectId,
                number: n,
                framing: const Value('Plano general con un nombre bien largo'),
              ),
            );
            await db.insertShootDocumentBlock(
              ShootDocumentBlocksCompanion.insert(
                documentId: dayId,
                blockType: 'shot',
                sortOrder: Value(n),
                sceneId: Value(sceneId),
                shotId: Value(shotId),
              ),
            );
          }
          await ShootDayScheduleService(db).addStrip(
            dayId,
            const ShootStripDraft(
              strip: ShootStrip(
                kind: ShootStripKind.move,
                from: '13:30',
                to: '15:00',
              ),
              label: 'Cambio de localización con un nombre largo',
              note: 'Aclaración larga para el equipo de cámara y de eléctricos',
            ),
          );
        });
        await pumpScreen(tester, screen(projectId, dayId));
        await auditAndUnmount(tester);
      });
    }

    testWidgets('reservas · ${e.key}', (tester) async {
      setAuditSize(tester, e.value);
      await seed(tester);
      await tester.runAsync(() async {
        final service = RentalImportService(db);
        await service.apply(
          projectId: projectId,
          preview: await service.preview(
            projectId,
            const ParsedReservation(
              number: 'S1',
              pickupAt: '2099-11-12T10:00',
              returnAt: '2099-11-18T14:00',
              sourceStatus: 'Presupuesto',
              items: [
                ParsedRentalItem(
                  section: 'CÁMARA Y OTRAS COSAS CON NOMBRE LARGO',
                  name: 'CÁMARA CON UN NOMBRE LARGUÍSIMO DE VERDAD (C)',
                  quantity: 1,
                  rawText: '',
                  children: [
                    ParsedRentalItem(
                      groupLabel: 'Maleta 1 (Nanlite FS-300C)',
                      name: 'CABLE ALIMENTACIÓN 2 PINS A BAT 24V',
                      quantity: 1,
                      serial: 'K1.71310.0-8562',
                      rawText: '',
                    ),
                  ],
                ),
                ParsedRentalItem(name: 'BNC', quantity: 3, rawText: ''),
              ],
            ),
          ),
          title: 'Lista de cámara de la reserva grande',
          houseName: 'ESCAC',
          contact: '+34 000 000 000 https://material.appsescac.com/',
        );
      });
      await pumpScreen(
        tester,
        Scaffold(body: RentalsTab(projectId: projectId)),
      );
      expect(find.textContaining('Lista de cámara'), findsWidgets);
      await auditAndUnmount(tester);
    });

    for (final month in [false, true]) {
      testWidgets('calendario ${month ? 'mes' : 'semana'} · ${e.key}', (
        tester,
      ) async {
        setAuditSize(tester, e.value);
        await seed(tester);
        final day = DateTime.now().add(const Duration(days: 1));
        final date = shootCalendarDate(day);
        await tester.runAsync(() async {
          final doc = (await db.getShootDocumentsForProject(projectId)).single;
          await db.updateShootDocument(
            doc.copyWith(
              shootDate: Value(date),
              shootFromTime: const Value('20:00'),
              shootToTime: const Value('04:00'),
            ),
          );
          final service = ShootDayScheduleService(db);
          for (final (kind, from, to) in [
            (ShootStripKind.setup, '20:00', '21:30'),
            (ShootStripKind.meal, '20:30', '21:00'),
            (ShootStripKind.note, null, null),
          ]) {
            await service.addStrip(
              doc.id,
              ShootStripDraft(
                strip: ShootStrip(kind: kind, from: from, to: to),
                label: 'Una franja con un nombre realmente largo',
              ),
            );
          }
          final rentals = RentalImportService(db);
          await rentals.apply(
            projectId: projectId,
            preview: await rentals.preview(
              projectId,
              ParsedReservation(
                number: 'S1',
                pickupAt: '${date}T10:00',
                returnAt: '${date}T14:00',
                sourceStatus: 'Presupuesto',
                items: const [
                  ParsedRentalItem(name: 'BNC', quantity: 3, rawText: ''),
                ],
              ),
            ),
            title: 'Lista de cámara de la reserva grande',
            houseName: 'ESCAC',
            contact: '',
          );
        });
        await pumpScreen(
          tester,
          ShootCalendarScreen(projectId: projectId),
        );
        if (month && find.text('Mes').evaluate().isNotEmpty) {
          await tester.tap(find.text('Mes'));
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.textContaining('Lista de cámara'), findsWidgets);
        await auditAndUnmount(tester);
      });
    }

    testWidgets('documentos de rodaje · ${e.key}', (tester) async {
      setAuditSize(tester, e.value);
      await seed(tester);
      await pumpScreen(
        tester,
        ShootDocumentsScreen(
          projectId: projectId,
          projectName: 'Kebab Khaled con nombre largo',
        ),
      );
      await auditAndUnmount(tester);
    });
  }
}
