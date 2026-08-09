import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:iris_dp/core/sync/sync_plan.dart';

void main() {
  group('SyncPlan smoke', () {
    test('SyncPlanItem elige resolución por defecto según acción', () {
      expect(
        SyncPlanItem(
          action: SyncPlanAction.pushNewLocal,
          title: 'Nuevo',
          description: 'Subir',
        ).choice,
        SyncResolutionChoice.useLocal,
      );
      expect(
        SyncPlanItem(
          action: SyncPlanAction.importFromCloud,
          title: 'Importar',
          description: 'Descargar',
        ).choice,
        SyncResolutionChoice.useCloud,
      );
      expect(
        SyncPlanItem(
          action: SyncPlanAction.contentConflict,
          title: 'Conflicto',
          description: 'Elegir',
        ).choice,
        SyncResolutionChoice.useLocal,
      );
    });

    test('SyncPlan detecta conflictos y cuenta pendientes', () {
      final plan = SyncPlan(
        items: [
          SyncPlanItem(
            action: SyncPlanAction.pushNewLocal,
            title: 'A',
            description: 'Subir A',
          ),
          SyncPlanItem(
            action: SyncPlanAction.contentConflict,
            title: 'B',
            description: 'Conflicto B',
            localContentSummary: ContentSyncSummary.fromJson({
              'sceneCount': 1,
              'shotCount': 0,
              'locationSiteCount': 0,
              'locationSetCount': 0,
              'shootDocumentCount': 0,
              'equipmentCount': 0,
            }),
            cloudContentSummary: ContentSyncSummary.fromJson({
              'sceneCount': 2,
              'shotCount': 0,
              'locationSiteCount': 0,
              'locationSetCount': 0,
              'shootDocumentCount': 0,
              'equipmentCount': 0,
            }),
          ),
          SyncPlanItem(
            action: SyncPlanAction.pullContentCloud,
            title: 'C',
            description: 'Omitir C',
            choice: SyncResolutionChoice.skip,
          ),
        ],
      );

      expect(plan.hasConflicts, isTrue);
      expect(plan.pendingCount, 2);
      expect(plan.isEmpty, isFalse);
    });

    test('contentConflict con resúmenes distintos requiere revisión', () {
      final item = SyncPlanItem(
        action: SyncPlanAction.contentConflict,
        title: 'Proyecto — contenido',
        description: 'Contenido distinto',
        localContentSummary: ContentSyncSummary.fromJson({
          'sceneCount': 3,
          'shotCount': 1,
          'locationSiteCount': 0,
          'locationSetCount': 0,
          'shootDocumentCount': 0,
          'equipmentCount': 0,
        }),
        cloudContentSummary: ContentSyncSummary.fromJson({
          'sceneCount': 3,
          'shotCount': 4,
          'locationSiteCount': 0,
          'locationSetCount': 0,
          'shootDocumentCount': 0,
          'equipmentCount': 0,
        }),
      );

      expect(item.isContentSync, isTrue);
      expect(item.requiresReview, isTrue);
    });
  });
}
