import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../camera_plan/camera_plan_screen.dart';
import '../equipment/equipment_screen.dart';
import '../locations/locations_screen.dart';
import '../luka_export/luka_bridge_screen.dart';
import '../script_import/script_import_screen.dart';
import '../shoot_documents/shoot_documents_screen.dart';
import '../storyboard/storyboard_screen.dart';
import '../technical_script/technical_script_screen.dart';
import '../visual_bible/visual_bible_screen.dart';
import 'project_hub_destinations.dart';

/// Router declarativo del hub de proyecto (Fase 9).
abstract final class ProjectHubRouter {
  ProjectHubRouter._();

  static Widget screenFor({
    required ProjectHubDestinationId id,
    required Project project,
  }) =>
      switch (id) {
        ProjectHubDestinationId.scriptImport =>
          ScriptImportScreen(projectId: project.id),
        ProjectHubDestinationId.locations =>
          LocationsScreen(projectId: project.id),
        ProjectHubDestinationId.cameraPlans =>
          CameraPlanScreen(projectId: project.id),
        ProjectHubDestinationId.technicalScript =>
          TechnicalScriptScreen(projectId: project.id),
        ProjectHubDestinationId.dailyOrder => ShootDocumentsScreen(
            projectId: project.id,
            projectName: project.name,
            projectStatus: project.status,
          ),
        ProjectHubDestinationId.equipment =>
          EquipmentScreen(projectId: project.id),
        ProjectHubDestinationId.storyboard =>
          StoryboardScreen(projectId: project.id),
        ProjectHubDestinationId.lukaBridge => LukaBridgeScreen(
            projectId: project.id,
            projectName: project.name,
          ),
        ProjectHubDestinationId.lookBible =>
          VisualBibleScreen(projectId: project.id),
      };

  static Future<void> open({
    required BuildContext context,
    required ProjectHubDestination destination,
    required Project project,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => screenFor(id: destination.id, project: project),
      ),
    );
  }

  static bool reloadStatsAfterVisit(ProjectHubDestinationId id) =>
      id == ProjectHubDestinationId.scriptImport ||
      id == ProjectHubDestinationId.cameraPlans;

  static bool reloadVisualsAfterVisit(ProjectHubDestinationId id) => true;
}
