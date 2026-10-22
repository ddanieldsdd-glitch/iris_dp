import '../../core/settings/app_prefs.dart';
import 'visual_bible_export_config.dart';
import 'visual_bible_model.dart';

/// Ajustes de la biblia: con qué se abre la exportación la primera vez en
/// un proyecto. Después manda la última exportación de ese proyecto.
abstract final class BiblePrefs {
  static const exportMode = PrefKey<String>(
    'bible.exportMode',
    VisualBibleExportMode.full,
  );

  /// `saveFile` o `share`.
  static const exportDestination = PrefKey<String>(
    'bible.exportDestination',
    'saveFile',
  );

  static const all = <PrefKey>[exportMode, exportDestination];

  static VisualBibleExportConfig initialExportConfig(int projectId) {
    final p = AppPrefs.instance;
    final destination = VisualBibleExportDestination.values.firstWhere(
      (d) => d.name == p.get(exportDestination, projectId: projectId),
      orElse: () => VisualBibleExportDestination.saveFile,
    );
    return VisualBibleExportConfig.defaults(
      mode: p.get(exportMode, projectId: projectId),
      destination: destination,
    );
  }
}
