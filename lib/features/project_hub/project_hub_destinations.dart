import 'package:flutter/material.dart';

/// Identificadores de módulos accesibles desde el hub del proyecto.
enum ProjectHubDestinationId {
  scriptImport,
  locations,
  cameraPlans,
  technicalScript,
  dailyOrder,
  equipment,
  storyboard,
  lukaBridge,
  lookBible,
}

/// Estadísticas ligeras mostradas en subtítulos del hub.
class ProjectHubStats {
  final int sceneCount;
  final int planCount;
  final String projectStatus;

  const ProjectHubStats({
    required this.sceneCount,
    required this.planCount,
    this.projectStatus = 'preproduction',
  });

  bool get hasScenes => sceneCount > 0;
  bool get isShooting => projectStatus == 'shooting';
}

/// Destino del hub: metadatos de tarjeta + disponibilidad.
class ProjectHubDestination {
  final ProjectHubDestinationId id;
  final IconData icon;
  final String title;
  final String Function(ProjectHubStats stats) subtitle;
  final Color accentColor;
  final bool Function(ProjectHubStats stats) isAvailable;
  final bool Function(ProjectHubStats stats) highlight;
  final bool Function() visible;

  const ProjectHubDestination({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.isAvailable = _alwaysAvailable,
    this.highlight = _neverHighlight,
    this.visible = _alwaysVisible,
  });

  static bool _alwaysAvailable(ProjectHubStats _) => true;
  static bool _neverHighlight(ProjectHubStats _) => false;
  static bool _alwaysVisible() => true;
}

/// Catálogo único de módulos del hub (activos y planificados).
List<ProjectHubDestination> buildProjectHubDestinations() {
  return [
    ProjectHubDestination(
      id: ProjectHubDestinationId.scriptImport,
      icon: Icons.menu_book_outlined,
      title: 'Guion literario',
      subtitle: (s) => s.hasScenes
          ? '${s.sceneCount} escena${s.sceneCount == 1 ? '' : 's'} · PDF, DOCX, Fountain'
          : 'Importa el guion para empezar',
      accentColor: const Color(0xFFFF9F0A),
      highlight: (s) => !s.hasScenes,
    ),
    ProjectHubDestination(
      id: ProjectHubDestinationId.locations,
      icon: Icons.location_city_outlined,
      title: 'Localizaciones',
      subtitle: (_) =>
          'Plano maestro, sets, galerías y escenas vinculadas',
      accentColor: const Color(0xFF64D2FF),
    ),
    ProjectHubDestination(
      id: ProjectHubDestinationId.cameraPlans,
      icon: Icons.grid_on_outlined,
      title: 'Plantas de cámara',
      subtitle: (s) => s.planCount > 0
          ? '${s.planCount} plano${s.planCount == 1 ? '' : 's'} con planta · blocking cenital'
          : 'Por localización, set y plano',
      accentColor: const Color(0xFF30D158),
    ),
    ProjectHubDestination(
      id: ProjectHubDestinationId.technicalScript,
      icon: Icons.table_rows_outlined,
      title: 'Guion técnico',
      subtitle: (_) => 'Planos, encuadres y export PDF',
      accentColor: const Color(0xFF0A84FF),
    ),
    ProjectHubDestination(
      id: ProjectHubDestinationId.dailyOrder,
      icon: Icons.description_outlined,
      title: 'Documentos para el rodaje',
      subtitle: (_) =>
          'Tu referencia en set — guion, planos, personajes y refs visuales',
      accentColor: const Color(0xFFBF5AF2),
      isAvailable: (_) => true,
      highlight: (s) => s.isShooting,
    ),
    ProjectHubDestination(
      id: ProjectHubDestinationId.equipment,
      icon: Icons.inventory_2_outlined,
      title: 'Equipo',
      subtitle: (_) => 'Cámaras, ópticas y luces del catálogo',
      accentColor: const Color(0xFFFF453A),
    ),
    ProjectHubDestination(
      id: ProjectHubDestinationId.storyboard,
      icon: Icons.view_comfy_outlined,
      title: 'Storyboard',
      subtitle: (s) => s.hasScenes
          ? 'Referencia visual por plano · Artemis y fotos'
          : 'Monta el storyboard cuando haya planos',
      accentColor: const Color(0xFF5AC8FA),
    ),
    ProjectHubDestination(
      id: ProjectHubDestinationId.lukaBridge,
      icon: Icons.view_in_ar_outlined,
      title: 'Unreal / LUKA Bridge',
      subtitle: (_) => 'Exportar escena a UE5 · Gaussian Splat + LUKA',
      accentColor: const Color(0xFFFFD60A),
    ),
    ProjectHubDestination(
      id: ProjectHubDestinationId.lookBible,
      icon: Icons.auto_stories_outlined,
      title: 'Biblia de Fotografía',
      subtitle: (_) =>
          'Lookbook + manual operativo: color, luz, óptica y moodboard',
      accentColor: const Color(0xFFFF6B6B),
    ),
  ];
}
