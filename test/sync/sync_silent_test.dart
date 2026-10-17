import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/device_label.dart';
import 'package:iris_dp/core/sync/project_content_sync_service.dart';
import 'package:iris_dp/core/sync/sync_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SyncPlanItem _item(SyncPlanAction action) =>
    SyncPlanItem(action: action, title: 'p', description: 'd');

void main() {
  group('qué se aplica sin preguntar', () {
    test('solo los conflictos y borrar aquí piden revisión', () {
      const review = {
        SyncPlanAction.conflict,
        SyncPlanAction.contentConflict,
        SyncPlanAction.deleteLocal,
      };
      for (final action in SyncPlanAction.values) {
        expect(
          _item(action).appliesSilently,
          !review.contains(action),
          reason: '$action',
        );
      }
    });

    test('la hoja recibe solo lo que hay que decidir', () {
      final plan = SyncPlan(
        items: [
          _item(SyncPlanAction.pullContentCloud),
          _item(SyncPlanAction.contentConflict),
          _item(SyncPlanAction.pushContentLocal),
          _item(SyncPlanAction.deleteLocal),
        ],
      );
      expect(plan.reviewItems.map((i) => i.action), [
        SyncPlanAction.contentConflict,
        SyncPlanAction.deleteLocal,
      ]);
      // Se presentan con su elección de siempre aunque la pasada las saltara.
      final skipped = plan.reviewItems.first
        ..choice = SyncResolutionChoice.skip;
      expect(
        skipped.copyWith(choice: skipped.defaultChoice).choice,
        SyncResolutionChoice.useLocal,
      );
    });
  });

  group('editado en…', () {
    test('describe cuándo y dónde', () {
      final now = DateTime(2026, 10, 17, 20);
      expect(
        CloudEdit(at: now.subtract(const Duration(minutes: 2)), device: 'iPad')
            .describe(now),
        'editado en iPad hace 2 min',
      );
      expect(CloudEdit(at: now).describe(now), 'editado ahora');
      expect(
        CloudEdit(at: now.subtract(const Duration(hours: 3)), device: 'Mac')
            .describe(now),
        'editado en Mac hace 3 h',
      );
    });

    test('sin la columna en Supabase se sube igual, sin el equipo', () async {
      SharedPreferences.setMockInitialValues({});
      hasDeviceColumn = true;
      addTearDown(() => hasDeviceColumn = true);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'p', cloudId: const Value('c1')),
      );

      final bodies = <Map<String, dynamic>>[];
      final client = SupabaseClient(
        'http://127.0.0.1:9',
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSJ9.test',
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          bodies.add(body);
          if (body.containsKey('updated_device')) {
            return http.Response(
              jsonEncode({
                'code': 'PGRST204',
                'message': "Could not find the 'updated_device' column of "
                    "'cloud_project_snapshots' in the schema cache",
                'details': null,
                'hint': null,
              }),
              400,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            jsonEncode([body]),
            201,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );

      await ProjectContentSyncService(db, client)
          .upload(projectId, 'c1', expectedCloudHash: null);

      expect(bodies, hasLength(2));
      expect(bodies.first.containsKey('updated_device'), isTrue);
      expect(bodies.last.containsKey('updated_device'), isFalse);
      expect(hasDeviceColumn, isFalse);
    });
  });
}
