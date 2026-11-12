import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../camera_plan/plan_renderer.dart' show PlanExportView;
import '../storyboard/shot_sheet_data.dart';
import '../storyboard/storyboard_export_style.dart';
import '../storyboard/storyboard_group_export_options.dart';
import '../technical_script/script_export_dialog.dart';
import '../technical_script/technical_script_settings.dart';
import 'export_selection.dart';

/// Cómo se reparte lo exportado en archivos.
enum ExportSplit {
  single('Un archivo'),
  perDay('Uno por jornada'),
  perScene('Uno por escena');

  final String label;
  const ExportSplit(this.label);
}

/// Las formas de sacar el storyboard.
enum StoryboardLook {
  grid6('Rejilla de 6', 'Viñeta grande, apaisado'),
  grid9('Rejilla de 9', 'Viñeta pequeña, apaisado'),
  shotList('Shot list', 'Cuatro planos por hoja con sus datos'),
  clean('Clean', 'Cada plano en su hoja, la imagen sola'),
  basic('Basic', 'Hoja por plano con encuadre y focal'),
  detail('Detail', 'Hoja por plano con cámara, paleta y notas'),
  shotPlan(
    'Shot plan',
    'La más completa: hoja por plano con guion, planta y sol',
  );

  final String label;
  final String hint;
  const StoryboardLook(this.label, this.hint);

  bool get isSheet => index >= StoryboardLook.clean.index;

  StoryboardGroupExportChoice choice(ShotImageSource source) => switch (this) {
    grid6 => StoryboardGroupExportChoice.sequences(
      StoryboardSequenceLayout.storyboard,
    ),
    grid9 => StoryboardGroupExportChoice.sequences(
      StoryboardSequenceLayout.storyboard,
      density: StoryboardGridDensity.nine,
    ),
    shotList => StoryboardGroupExportChoice.sequences(
      StoryboardSequenceLayout.shotList,
    ),
    clean => StoryboardGroupExportChoice.asShots(
      StoryboardExportStyle.clean,
      imageSource: source,
    ),
    basic => StoryboardGroupExportChoice.asShots(
      StoryboardExportStyle.basic,
      imageSource: source,
    ),
    detail => StoryboardGroupExportChoice.asShots(
      StoryboardExportStyle.detail,
      imageSource: source,
    ),
    shotPlan => StoryboardGroupExportChoice.asShots(
      StoryboardExportStyle.shotPlan,
      imageSource: source,
    ),
  };
}

T? _byName<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

/// Lo elegido en el centro de exportación que no es la selección. Se recuerda
/// por proyecto.
class ExportOptions {
  final ExportDocument document;
  final ExportScope scope;
  final ExportSplit split;
  final StoryboardLook look;
  final ShotImageSource imageSource;

  /// Planta de cámara y actores, de luz, o las dos.
  final PlanExportView planView;

  /// Con la luz que cae en el suelo; sin ella, solo los aparatos.
  final bool planBeams;

  /// La planta general de cada esquema al final del documento de planta.
  final bool planOverviews;

  /// Imagen de la portada del documento de planta, en lugar de la banda negra.
  final String? planCoverImage;

  /// Imagen detrás de las plantas, en lugar del fondo negro.
  final String? planBackdropImage;

  /// Índice en la portada del documento de planta.
  final bool planIndex;

  /// Documentos que abren con el plan de rodaje de sus jornadas. En el guion
  /// técnico es la portada de la jornada, cuando se exporta una sola.
  final Set<ExportDocument> scheduleFor;

  /// Previsión del tiempo en el plan de rodaje. El sol se queda: es luz.
  final bool withWeather;
  final ScriptExportOptions script;

  /// Este documento abre con el plan de rodaje.
  bool get withSchedule => scheduleFor.contains(document);

  const ExportOptions({
    this.document = ExportDocument.storyboard,
    this.scope = ExportScope.all,
    this.split = ExportSplit.single,
    this.look = StoryboardLook.grid6,
    this.imageSource = ShotImageSource.storyboard,
    this.planView = PlanExportView.both,
    this.planBeams = true,
    this.planOverviews = true,
    this.planCoverImage,
    this.planBackdropImage,
    this.planIndex = true,
    this.scheduleFor = const {ExportDocument.technicalScript},
    this.withWeather = true,
    this.script = const ScriptExportOptions(),
  });

  /// Planos que entran en la vista previa: los justos para ver cómo sale,
  /// sin esperar al documento entero.
  int get previewShots => switch (document) {
    ExportDocument.storyboard => look.isSheet ? 6 : 18,
    ExportDocument.shootingPlan => 8,
    ExportDocument.technicalScript => 24,
  };

  ExportOptions copyWith({
    ExportDocument? document,
    ExportScope? scope,
    ExportSplit? split,
    StoryboardLook? look,
    ShotImageSource? imageSource,
    PlanExportView? planView,
    bool? planBeams,
    bool? planOverviews,
    String? planCoverImage,
    bool clearPlanCoverImage = false,
    String? planBackdropImage,
    bool clearPlanBackdropImage = false,
    bool? planIndex,
    Set<ExportDocument>? scheduleFor,
    bool? withWeather,
    ScriptExportOptions? script,
  }) => ExportOptions(
    document: document ?? this.document,
    scope: scope ?? this.scope,
    split: split ?? this.split,
    look: look ?? this.look,
    imageSource: imageSource ?? this.imageSource,
    planView: planView ?? this.planView,
    planBeams: planBeams ?? this.planBeams,
    planOverviews: planOverviews ?? this.planOverviews,
    planCoverImage: clearPlanCoverImage
        ? null
        : planCoverImage ?? this.planCoverImage,
    planBackdropImage: clearPlanBackdropImage
        ? null
        : planBackdropImage ?? this.planBackdropImage,
    planIndex: planIndex ?? this.planIndex,
    scheduleFor: scheduleFor ?? this.scheduleFor,
    withWeather: withWeather ?? this.withWeather,
    script: script ?? this.script,
  );

  /// Pone o quita el plan de rodaje en el documento elegido.
  ExportOptions withScheduleSet(bool on) => copyWith(
    scheduleFor: on
        ? {...scheduleFor, document}
        : ({...scheduleFor}..remove(document)),
  );

  Map<String, dynamic> toJson() => {
    'document': document.name,
    'scope': scope.name,
    'split': split.name,
    'look': look.name,
    'imageSource': imageSource.name,
    'planView': planView.name,
    'planBeams': planBeams,
    'planOverviews': planOverviews,
    'planCoverImage': planCoverImage,
    'planBackdropImage': planBackdropImage,
    'planIndex': planIndex,
    'scheduleFor': [for (final d in scheduleFor) d.name],
    'withWeather': withWeather,
    'script': script.toJson(),
  };

  factory ExportOptions.fromJson(Map<String, dynamic> json) {
    const d = ExportOptions();
    final script = json['script'];
    final schedule = json['scheduleFor'];
    return ExportOptions(
      document: _byName(ExportDocument.values, json['document']) ?? d.document,
      scope: _byName(ExportScope.values, json['scope']) ?? d.scope,
      split: _byName(ExportSplit.values, json['split']) ?? d.split,
      look: _byName(StoryboardLook.values, json['look']) ?? d.look,
      imageSource:
          _byName(ShotImageSource.values, json['imageSource']) ?? d.imageSource,
      planView:
          _byName(PlanExportView.values, json['planView']) ??
          // Lo guardado antes del selector: «Con luz» eran las dos juntas.
          (json['planWithLight'] == false ? PlanExportView.stage : d.planView),
      planBeams: json['planBeams'] != false,
      planOverviews: json['planOverviews'] != false,
      planCoverImage: json['planCoverImage'] as String?,
      planBackdropImage: json['planBackdropImage'] as String?,
      planIndex: json['planIndex'] != false,
      scheduleFor: schedule is List
          ? {for (final name in schedule) ?_byName(ExportDocument.values, name)}
          : d.scheduleFor,
      withWeather: json['withWeather'] != false,
      script: script is Map
          ? ScriptExportOptions.fromJson(Map<String, dynamic>.from(script))
          : d.script,
    );
  }

  static String _key(int projectId) => 'iris_export_center_$projectId';

  /// Lo último de este proyecto; la primera vez, lo del guion técnico.
  static Future<ExportOptions> load(
    int projectId,
    TechnicalScriptSettings screen,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(projectId));
      if (raw != null) {
        return ExportOptions.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      }
    } catch (_) {
      // Ilegible: se parte de cero.
    }
    return ExportOptions(script: await savedScriptExportOptions(screen));
  }

  Future<void> save(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(projectId), jsonEncode(toJson()));
  }
}
