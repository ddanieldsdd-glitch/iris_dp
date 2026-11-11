import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/rental_queries.dart';
import 'package:iris_dp/core/sync/bundle_merge.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:iris_dp/core/sync/rental_bundle.dart';
import 'package:iris_dp/features/equipment/rentals/rental_import_models.dart';
import 'package:iris_dp/features/equipment/rentals/rental_import_service.dart';

ParsedReservation reservation({
  List<ParsedRentalItem>? items,
  String pickup = '2026-11-12T10:00',
}) => ParsedReservation(
  number: 'S100',
  pickupAt: pickup,
  returnAt: '2026-11-18T14:00',
  suggestedHouse: 'ESCAC',
  items:
      items ??
      const [
        ParsedRentalItem(
          name: 'KIT',
          quantity: 1,
          rawText: 'KIT',
          children: [
            ParsedRentalItem(name: 'Cable', quantity: 1, rawText: 'Cable'),
            ParsedRentalItem(name: 'Cable', quantity: 1, rawText: 'Cable'),
          ],
        ),
        ParsedRentalItem(name: 'Bandera', quantity: 2, rawText: 'Bandera'),
      ],
);

void main() {
  late AppDatabase db;
  late int projectId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
  });
  tearDown(() async => db.close());

  Future<String> save(ParsedReservation parsed) async {
    final service = RentalImportService(db);
    return service.apply(
      projectId: projectId,
      preview: await service.preview(projectId, parsed),
      title: 'Lista',
      houseName: 'ESCAC',
    );
  }

  test(
    'reimportar no duplica, conserva marcas y avisa de lo que cambia',
    () async {
      final uid = await save(reservation());
      var r = (await db.getRentalReservations(projectId)).single;
      var items = await db.watchRentalItems(projectId, uid).first;
      expect(items, hasLength(4));
      await db.setReservationPickedUp(r, at: 'A', device: 'Mac');
      final bandera = items.firstWhere((i) => i.name == 'Bandera');
      final kit = items.firstWhere((i) => i.name == 'KIT');
      await db.setRentalItemChecked(bandera, returning: false, at: 'B');

      final next = reservation(
        pickup: '2026-11-13T09:00',
        items: const [
          ParsedRentalItem(name: 'KIT', quantity: 2, rawText: 'KIT'),
          ParsedRentalItem(name: 'Nuevo', quantity: 1, rawText: 'Nuevo'),
        ],
      );
      final service = RentalImportService(db);
      final preview = await service.preview(projectId, next);
      expect(preview.isUpdate, isTrue);
      expect(preview.added, ['Nuevo']);
      expect(preview.changed, ['KIT']);
      expect(preview.removed, containsAll(['Bandera', 'Cable']));
      await service.apply(
        projectId: projectId,
        preview: preview,
        title: 'Lista',
        houseName: 'ESCAC',
      );

      r = (await db.getRentalReservations(projectId)).single;
      expect(r.pickedUpAt, 'A');
      expect(r.pickupAt, '2026-11-13T09:00');
      items = await db.watchRentalItems(projectId, uid).first;
      expect(items.firstWhere((i) => i.uid == kit.uid).quantity, 2);
      // Lo comprobado no desaparece: queda señalado.
      final kept = items.firstWhere((i) => i.uid == bandera.uid);
      expect(kept.removedFromSourceAt, isNotNull);
      expect(items.where((i) => i.name == 'Cable'), isEmpty);
    },
  );

  test(
    'lo añadido a mano y las fechas editadas sobreviven a reimportar',
    () async {
      final uid = await save(reservation());
      var r = (await db.getRentalReservations(projectId)).single;
      await db.addManualRentalItem(r, name: 'Gaffer negro', quantity: 3);
      await db.updateRentalReservationInfo(
        r,
        title: 'Lista ESCAC',
        pickupAt: '2026-11-12T08:30',
        returnAt: r.returnAt,
        notes: 'Llamar antes',
      );
      r = (await db.getRentalReservations(projectId)).single;
      expect(r.title, 'Lista ESCAC');
      expect(r.notes, 'Llamar antes');

      final service = RentalImportService(db);
      final preview = await service.preview(projectId, reservation());
      expect(preview.removed, isEmpty);
      await service.apply(
        projectId: projectId,
        preview: preview,
        title: 'Lista ESCAC',
        houseName: 'ESCAC',
      );
      final items = await db.watchRentalItems(projectId, uid).first;
      final manual = items.singleWhere((i) => i.name == 'Gaffer negro');
      expect(manual.quantity, 3);
      expect(manual.deletedAt, isNull);
      await db.softDeleteRentalItem(manual, 'X');
      expect(
        (await db.watchRentalItems(projectId, uid).first).map((i) => i.name),
        isNot(contains('Gaffer negro')),
      );
    },
  );

  test('el mismo PDF en dos aparatos da las mismas filas', () {
    final uid = rentalReservationUid('S100');
    expect(rentalReservationUid(' s100 '), uid);
    final a = RentalImportService.flatten(uid, reservation().items);
    final b = RentalImportService.flatten(uid, reservation().items);
    expect(a.map((i) => i.uid), b.map((i) => i.uid));
    expect(a.map((i) => i.uid).toSet(), hasLength(a.length));
  });

  test('un proyecto sin reservas no cambia su bundle', () async {
    final bundle = await ProjectContentBundle.export(db, projectId);
    expect(bundle.keys.where((k) => k.startsWith('rental')), isEmpty);
    expect(bundle['version'], 9);
  });

  test('viajan y se aplican por uid', () async {
    await save(reservation());
    final bundle = await RentalBundle.export(db, projectId);
    final otherId = await db.insertProject(ProjectsCompanion.insert(name: 'Q'));
    await RentalBundle.import(db, otherId, bundle);
    await RentalBundle.import(db, otherId, bundle);
    expect(await db.getRentalReservations(otherId), hasLength(1));
    final uid = rentalReservationUid('S100');
    expect(await db.watchRentalItems(otherId, uid).first, hasLength(4));
  });

  group('un aparato antiguo no se lleva las reservas', () {
    Future<Map<String, dynamic>> base() async {
      await save(reservation());
      return ProjectContentBundle.export(db, projectId);
    }

    List merged(Map<String, dynamic> cloud, Map<String, dynamic> local) {
      final result = BundleMerge.merge(
        baseLocal: local,
        baseCloud: local,
        local: local,
        cloud: cloud,
        newer: MergeSide.cloud,
      );
      return result.merged['rentalReservations'] as List;
    }

    test('nube sin la clave', () async {
      final local = await base();
      final cloud = Map<String, dynamic>.from(local)
        ..remove('rentalHouses')
        ..remove('rentalReservations')
        ..remove('rentalItems');
      expect(merged(cloud, local), hasLength(1));
    });

    test('nube con listas vacías', () async {
      final local = await base();
      final cloud = {
        ...local,
        'rentalHouses': [],
        'rentalReservations': [],
        'rentalItems': [],
      };
      expect(merged(cloud, local), hasLength(1));
    });

    test('una bajada sin la clave no borra nada', () async {
      final bundle = await base();
      bundle
        ..remove('rentalHouses')
        ..remove('rentalReservations')
        ..remove('rentalItems');
      await ProjectContentBundle.importBundle(db, projectId, bundle);
      expect(await db.getRentalReservations(projectId), hasLength(1));
    });
  });

  test('marcar en un lado y reimportar en otro conserva los dos', () async {
    await save(reservation());
    final base = await ProjectContentBundle.export(db, projectId);
    final r = (await db.getRentalReservations(projectId)).single;
    await db.setReservationPickedUp(r, at: 'A', device: 'iPhone');
    final local = await ProjectContentBundle.export(db, projectId);
    final cloud = {
      ...base,
      'rentalReservations': [
        for (final m in base['rentalReservations'] as List)
          {...(m as Map<String, dynamic>), 'notes': 'de la nube'},
      ],
    };
    final out =
        BundleMerge.merge(
              baseLocal: base,
              baseCloud: base,
              local: local,
              cloud: cloud,
              newer: MergeSide.cloud,
            ).merged['rentalReservations']
            as List;
    expect(out.single['pickedUpAt'], 'A');
    expect(out.single['notes'], 'de la nube');
  });

  test('un bundle más nuevo no se aplica', () async {
    final bundle = await ProjectContentBundle.export(db, projectId);
    bundle['version'] = 99;
    expect(
      () => ProjectContentBundle.assertReadable(bundle),
      throwsA(isA<BundleTooNewException>()),
    );
    expect(
      ProjectContentBundle.importBundle(db, projectId, bundle),
      throwsA(isA<BundleTooNewException>()),
    );
  });
}
