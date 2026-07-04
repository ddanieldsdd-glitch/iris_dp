import '../../core/database/app_database.dart';
import 'storyboard_export_style.dart';

/// Modo de exportación de un grupo de planos.
enum StoryboardGroupExportMode {
  /// PDF de secuencia (storyboard o shot list).
  sequences,

  /// Cada plano con estilo individual (CLEAN / BASIC / DETAIL / SHOT PLAN).
  asShots,
}

/// Layout PDF al exportar secuencias.
enum StoryboardSequenceLayout {
  /// Apaisado 3×3, estilo storyboard clásico.
  storyboard,

  /// Vertical 4 planos/página con datos completos de cámara y notas.
  shotList,
}

extension StoryboardGroupExportModeX on StoryboardGroupExportMode {
  String get label => switch (this) {
        StoryboardGroupExportMode.sequences => 'EXPORT SEQUENCES',
        StoryboardGroupExportMode.asShots => 'EXPORT AS SHOTS',
      };
}

extension StoryboardSequenceLayoutX on StoryboardSequenceLayout {
  String get title => switch (this) {
        StoryboardSequenceLayout.storyboard => 'STORYBOARD',
        StoryboardSequenceLayout.shotList => 'SHOT LIST',
      };

  String get description => switch (this) {
        StoryboardSequenceLayout.storyboard =>
          'PDF apaisado estilo storyboard (SB), 9 planos por página.',
        StoryboardSequenceLayout.shotList =>
          'PDF vertical shot list (SL), 4 planos por página con datos '
          'completos de cámara, óptica y notas.',
      };

  /// Sufijo Artemis: `_SB` / `_SL`.
  String get artemisFileSuffix => switch (this) {
        StoryboardSequenceLayout.storyboard => 'SB',
        StoryboardSequenceLayout.shotList => 'SL',
      };

  String defaultFilename(Project project, Scene scene) {
    final safe =
        project.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final base = safe.isEmpty ? 'proyecto' : safe;
    return '${base}_Sc${scene.number}_$artemisFileSuffix.pdf';
  }
}

/// Resultado del diálogo de exportación de grupo.
class StoryboardGroupExportChoice {
  final StoryboardGroupExportMode mode;
  final StoryboardSequenceLayout? sequenceLayout;
  final StoryboardExportStyle? shotStyle;

  const StoryboardGroupExportChoice._({
    required this.mode,
    this.sequenceLayout,
    this.shotStyle,
  });

  factory StoryboardGroupExportChoice.sequences(
    StoryboardSequenceLayout layout,
  ) =>
      StoryboardGroupExportChoice._(
        mode: StoryboardGroupExportMode.sequences,
        sequenceLayout: layout,
      );

  factory StoryboardGroupExportChoice.asShots(StoryboardExportStyle style) =>
      StoryboardGroupExportChoice._(
        mode: StoryboardGroupExportMode.asShots,
        shotStyle: style,
      );

  String get exportLabel => switch (mode) {
        StoryboardGroupExportMode.sequences =>
          sequenceLayout?.artemisFileSuffix ?? 'SEC',
        StoryboardGroupExportMode.asShots => shotStyle?.title ?? 'PLANOS',
      };
}
