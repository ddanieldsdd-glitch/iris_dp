import '../../../core/utils/image_fingerprint.dart';
import '../../../core/database/app_database.dart';
import '../../../core/script/script_scene_matcher.dart';
import '../../../core/utils/scene_characters.dart';
import '../../../shared/rich_text/script_markup.dart';
import '../technical_script_settings.dart';
import 'docx_technical_script_reader.dart';

/// Cómo se aplica el documento en conjunto. Fija los valores por defecto de
/// todo lo demás; cada escena y cada plano pueden cambiarlos.
enum ImportMode {
  merge('Fusionar'),
  overwrite('Sobrescribir todo');

  final String label;
  const ImportMode(this.label);
}

/// Qué textos se quedan en un plano que está en los dos.
enum TextChoice {
  /// Los del documento.
  document('Documento'),

  /// Los nuestros; lo que tengamos vacío se rellena con el documento.
  ours('Nuestro');

  final String label;
  const TextChoice(this.label);
}

/// Qué pasa con las referencias del documento en un plano.
enum ReferenceMode {
  /// Las del documento pasan a principales; las nuestras quedan detrás.
  front('Delante'),

  /// Se añaden detrás; la principal sigue siendo la nuestra.
  back('Detrás'),

  /// Las nuestras se quitan y quedan solo las del documento.
  replace('Sustituir'),
  skip('No');

  final String label;
  const ReferenceMode(this.label);
}

/// Dónde entra la imagen de planta del documento.
enum PlanDestination {
  /// Boceto de la casilla Planta de cada plano que la lleva.
  shotSketch('Boceto del plano'),

  /// Boceto suelto en Plantas de cámara y luz, sin plano.
  looseSketch('Boceto suelto'),
  skip('No');

  final String label;
  const PlanDestination(this.label);
}

/// Qué enseña la casilla Planta después de importar.
enum PlanView {
  ours('Nuestra', ScriptPlanView.plan),
  document('Documento', ScriptPlanView.sketch),
  both('Las dos', ScriptPlanView.both);

  final String label;
  final ScriptPlanView scriptView;
  const PlanView(this.label, this.scriptView);
}

enum MatchStatus {
  added('nueva'),
  changed('cambios'),
  unchanged('igual'),
  onlyInApp('solo en la app');

  final String label;
  const MatchStatus(this.label);
}

/// Un campo que cambia: lo nuestro → lo del documento.
class FieldDiff {
  final String field;
  final String label;
  final String? ours;
  final String? document;

  const FieldDiff(this.field, this.label, this.ours, this.document);

  /// Lo nuestro está vacío: no es un conflicto, solo falta el dato.
  bool get fillsEmpty => ours == null || ours!.isEmpty;
}

class ShotMatch {
  final String key;
  final ImportedShot? imported;
  final Shot? existing;
  final List<FieldDiff> diffs;

  /// Referencias del documento que el plano aún no tiene (por huella).
  final List<ImportedImage> newReferences;

  /// Imagen de planta del documento, si el plano no la tiene ya.
  final ImportedImage? newPlan;

  const ShotMatch({
    required this.key,
    this.imported,
    this.existing,
    this.diffs = const [],
    this.newReferences = const [],
    this.newPlan,
  });

  int get number => imported?.number ?? existing!.number;

  MatchStatus get status {
    if (existing == null) return MatchStatus.added;
    if (imported == null) return MatchStatus.onlyInApp;
    if (diffs.isNotEmpty || newReferences.isNotEmpty || newPlan != null) {
      return MatchStatus.changed;
    }
    return MatchStatus.unchanged;
  }

  /// Hay algo que elegir: textos que chocan (no solo huecos que rellenar).
  bool get hasConflicts => diffs.any((d) => !d.fillsEmpty);
}

class SceneMatch {
  final String key;
  final ImportedScene? imported;
  final Scene? existing;
  final List<FieldDiff> headingDiffs;
  final List<ShotMatch> shots;

  const SceneMatch({
    required this.key,
    this.imported,
    this.existing,
    this.headingDiffs = const [],
    this.shots = const [],
  });

  String get label => imported?.label ?? existing!.label;

  String get heading {
    if (imported case final s?) {
      return '${s.label}. ${s.intExt}. ${s.location} - ${s.dayNight}';
    }
    return '${existing!.label}. ${existing!.locationCanonical}';
  }

  MatchStatus get status {
    if (existing == null) return MatchStatus.added;
    if (imported == null) return MatchStatus.onlyInApp;
    if (headingDiffs.isNotEmpty ||
        shots.any((s) => s.status != MatchStatus.unchanged)) {
      return MatchStatus.changed;
    }
    return MatchStatus.unchanged;
  }

  /// Imágenes de planta distintas del documento en esta escena.
  List<ImportedImage> get documentPlans {
    final seen = <String>{};
    return [
      for (final shot in shots)
        if (shot.newPlan case final plan? when seen.add(plan.hash)) plan,
    ];
  }
}

/// Decisiones de un nivel (todo, una escena o un plano). Nulo = hereda.
class ImportChoices {
  final TextChoice? text;
  final bool? addNew;
  final bool? deleteOnlyInApp;
  final ReferenceMode? references;
  final PlanDestination? planDestination;
  final PlanView? planView;

  const ImportChoices({
    this.text,
    this.addNew,
    this.deleteOnlyInApp,
    this.references,
    this.planDestination,
    this.planView,
  });

  static const none = ImportChoices();

  ImportChoices copyWith({
    TextChoice? text,
    bool? addNew,
    bool? deleteOnlyInApp,
    ReferenceMode? references,
    PlanDestination? planDestination,
    PlanView? planView,
  }) => ImportChoices(
    text: text ?? this.text,
    addNew: addNew ?? this.addNew,
    deleteOnlyInApp: deleteOnlyInApp ?? this.deleteOnlyInApp,
    references: references ?? this.references,
    planDestination: planDestination ?? this.planDestination,
    planView: planView ?? this.planView,
  );

  /// Lo de este nivel y, donde no decide, lo de [parent].
  ImportChoices over(ImportChoices parent) => ImportChoices(
    text: text ?? parent.text,
    addNew: addNew ?? parent.addNew,
    deleteOnlyInApp: deleteOnlyInApp ?? parent.deleteOnlyInApp,
    references: references ?? parent.references,
    planDestination: planDestination ?? parent.planDestination,
    planView: planView ?? parent.planView,
  );

  bool get isEmpty =>
      text == null &&
      addNew == null &&
      deleteOnlyInApp == null &&
      references == null &&
      planDestination == null &&
      planView == null;
}

/// Lo que se decide al final para un plano, ya sin herencias.
class ResolvedChoices {
  final TextChoice text;
  final bool addNew;
  final bool deleteOnlyInApp;
  final ReferenceMode references;
  final PlanDestination planDestination;
  final PlanView planView;

  const ResolvedChoices({
    required this.text,
    required this.addNew,
    required this.deleteOnlyInApp,
    required this.references,
    required this.planDestination,
    required this.planView,
  });
}

/// Todo lo que el usuario decide en la revisión.
class ImportDecisions {
  ImportMode mode;
  ImportChoices general;
  final Map<String, ImportChoices> scenes;
  final Map<String, ImportChoices> shots;

  /// Imágenes de referencia desmarcadas: `'<clave del plano>|<huella>'`.
  final Set<String> excludedReferences;

  ImportDecisions({
    this.mode = ImportMode.merge,
    this.general = ImportChoices.none,
    Map<String, ImportChoices>? scenes,
    Map<String, ImportChoices>? shots,
    Set<String>? excludedReferences,
  }) : scenes = scenes ?? {},
       shots = shots ?? {},
       excludedReferences = excludedReferences ?? {};

  /// Lo que pone el modo cuando nadie decide otra cosa.
  ImportChoices get modeDefaults => switch (mode) {
    ImportMode.merge => const ImportChoices(
      text: TextChoice.ours,
      addNew: true,
      deleteOnlyInApp: false,
      references: ReferenceMode.back,
      planDestination: PlanDestination.shotSketch,
      planView: PlanView.both,
    ),
    ImportMode.overwrite => const ImportChoices(
      text: TextChoice.document,
      addNew: true,
      deleteOnlyInApp: true,
      references: ReferenceMode.front,
      planDestination: PlanDestination.shotSketch,
      planView: PlanView.both,
    ),
  };

  ImportChoices forScene(String sceneKey) =>
      (scenes[sceneKey] ?? ImportChoices.none).over(general.over(modeDefaults));

  ResolvedChoices forShot(String sceneKey, String shotKey) {
    final c = (shots[shotKey] ?? ImportChoices.none).over(forScene(sceneKey));
    return ResolvedChoices(
      text: c.text!,
      addNew: c.addNew!,
      deleteOnlyInApp: c.deleteOnlyInApp!,
      references: c.references!,
      planDestination: c.planDestination!,
      planView: c.planView!,
    );
  }

  bool includesReference(String shotKey, ImportedImage image) =>
      !excludedReferences.contains('$shotKey|${image.hash}');

  void toggleReference(String shotKey, ImportedImage image) {
    final id = '$shotKey|${image.hash}';
    if (!excludedReferences.remove(id)) excludedReferences.add(id);
  }

  /// Cambia una decisión en todo; quita las excepciones de ese campo para
  /// que el atajo general se vea aplicado de verdad.
  void setGeneral(ImportChoices Function(ImportChoices) edit) {
    general = edit(general);
  }

  void setScene(String key, ImportChoices Function(ImportChoices) edit) {
    final next = edit(scenes[key] ?? ImportChoices.none);
    next.isEmpty ? scenes.remove(key) : scenes[key] = next;
  }

  void setShot(String key, ImportChoices Function(ImportChoices) edit) {
    final next = edit(shots[key] ?? ImportChoices.none);
    next.isEmpty ? shots.remove(key) : shots[key] = next;
  }
}

/// Resultado de comparar el documento con el guion técnico del proyecto.
class TechnicalScriptImportPlan {
  final ImportedTechnicalScript document;
  final List<SceneMatch> scenes;

  const TechnicalScriptImportPlan({
    required this.document,
    required this.scenes,
  });

  /// El proyecto no tenía guion técnico: todo es nuevo, sin conflictos.
  bool get isFresh => scenes.every((s) => s.existing == null);

  Iterable<ShotMatch> get _allShots => scenes.expand((s) => s.shots);

  int get newScenes =>
      scenes.where((s) => s.status == MatchStatus.added).length;
  int get onlyInAppScenes =>
      scenes.where((s) => s.status == MatchStatus.onlyInApp).length;
  int get newShots => scenes
      .where((s) => s.existing != null)
      .expand((s) => s.shots)
      .where((s) => s.status == MatchStatus.added)
      .length;
  int get changedShots =>
      _allShots.where((s) => s.existing != null && s.diffs.isNotEmpty).length;
  int get onlyInAppShots => scenes
      .where((s) => s.imported != null)
      .expand((s) => s.shots)
      .where((s) => s.status == MatchStatus.onlyInApp)
      .length;
  int get newReferences =>
      _allShots.fold(0, (sum, s) => sum + s.newReferences.length);
  int get newPlans => scenes.fold(0, (sum, s) => sum + s.documentPlans.length);
}

/// Compara [document] con las escenas y planos del proyecto.
///
/// [referenceHashes] y [planHashes] son las huellas de las imágenes que cada
/// plano ya tiene, para no volver a meter las mismas al reimportar.
/// [pairing] corrige a mano el emparejamiento: etiqueta de la escena del
/// documento → id de la escena del proyecto (nulo = escena nueva).
TechnicalScriptImportPlan buildTechnicalScriptImportPlan({
  required ImportedTechnicalScript document,
  required List<Scene> scenes,
  required Map<int, List<Shot>> shotsByScene,
  Map<int, Set<String>> referenceHashes = const {},
  Map<int, Set<String>> planHashes = const {},
  Map<String, int?> pairing = const {},
}) {
  final byLabel = <String, Scene>{};
  final byHeading = <String, List<Scene>>{};
  for (final scene in scenes) {
    byLabel.putIfAbsent(scene.label, () => scene);
    byHeading
        .putIfAbsent(
          scriptHeadingKey(
            intExt: scene.intExt,
            location: scene.locationPureName.isNotEmpty
                ? scene.locationPureName
                : scene.locationCanonical,
            dayNight: scene.dayNight,
          ),
          () => [],
        )
        .add(scene);
  }

  final used = <int>{};
  final matched = <ImportedScene, Scene?>{};
  // Primero los emparejamientos a mano y por número; luego, por cabecera.
  for (final imported in document.scenes) {
    if (pairing.containsKey(imported.label)) {
      final id = pairing[imported.label];
      final scene = id == null
          ? null
          : scenes.where((s) => s.id == id).firstOrNull;
      matched[imported] = scene;
      if (scene != null) used.add(scene.id);
      continue;
    }
    final scene = byLabel[imported.label];
    if (scene != null && !used.contains(scene.id)) {
      matched[imported] = scene;
      used.add(scene.id);
    }
  }
  // Una escena partida en el documento (13A, 13B) frente a la nuestra sin
  // letra (13): la primera parte es la nuestra; las demás entran nuevas.
  for (final imported in document.scenes) {
    if (matched.containsKey(imported) || imported.suffix == null) continue;
    final scene = scenes
        .where(
          (s) =>
              s.number == imported.number &&
              s.numberSuffix == null &&
              !used.contains(s.id),
        )
        .firstOrNull;
    if (scene == null) continue;
    matched[imported] = scene;
    used.add(scene.id);
  }
  // Por cabecera, solo con escenas del mismo número o con un número que el
  // documento ya no tiene (renumeradas): si no, 13B se pegaba a la 15 por
  // ser también INT. KEBAB - NOCHE.
  final docNumbers = {for (final s in document.scenes) s.number};
  for (final imported in document.scenes) {
    if (matched.containsKey(imported)) continue;
    final candidates =
        byHeading[scriptHeadingKey(
          intExt: imported.intExt,
          location: imported.location,
          dayNight: imported.dayNight,
        )];
    final scene = candidates
        ?.where(
          (s) =>
              !used.contains(s.id) &&
              (s.number == imported.number || !docNumbers.contains(s.number)),
        )
        .firstOrNull;
    matched[imported] = scene;
    if (scene != null) used.add(scene.id);
  }

  final result = <SceneMatch>[];
  for (final imported in document.scenes) {
    final existing = matched[imported];
    final key = 'doc:${imported.label}';
    result.add(
      SceneMatch(
        key: key,
        imported: imported,
        existing: existing,
        headingDiffs: existing == null
            ? const []
            : _headingDiffs(existing, imported),
        shots: _matchShots(
          sceneKey: key,
          imported: imported,
          existing: existing == null
              ? const []
              : shotsByScene[existing.id] ?? const [],
          referenceHashes: referenceHashes,
          planHashes: planHashes,
        ),
      ),
    );
  }
  for (final scene in scenes) {
    if (used.contains(scene.id)) continue;
    result.add(
      SceneMatch(
        key: 'app:${scene.id}',
        existing: scene,
        shots: [
          for (final shot in shotsByScene[scene.id] ?? const <Shot>[])
            ShotMatch(key: 'app:${shot.id}', existing: shot),
        ],
      ),
    );
  }
  return TechnicalScriptImportPlan(document: document, scenes: result);
}

List<ShotMatch> _matchShots({
  required String sceneKey,
  required ImportedScene imported,
  required List<Shot> existing,
  required Map<int, Set<String>> referenceHashes,
  required Map<int, Set<String>> planHashes,
}) {
  final byNumber = <int, Shot>{};
  for (final shot in existing) {
    byNumber.putIfAbsent(shot.number, () => shot);
  }
  final used = <int>{};
  final result = <ShotMatch>[];
  for (final shot in imported.shots) {
    final match = byNumber[shot.number];
    final mine = match != null && used.add(match.id) ? match : null;
    final haveRefs = mine == null
        ? const <String>{}
        : referenceHashes[mine.id] ?? const {};
    final havePlans = mine == null
        ? const <String>{}
        : planHashes[mine.id] ?? const {};
    final plan = shot.plans.firstOrNull;
    result.add(
      ShotMatch(
        key: '$sceneKey/${shot.number}',
        imported: shot,
        existing: mine,
        diffs: mine == null ? const [] : shotDiffs(mine, shot),
        newReferences: [
          for (final ref in shot.references)
            if (!alreadyHaveImage(haveRefs, ref)) ref,
        ],
        newPlan: plan != null && !alreadyHaveImage(havePlans, plan)
            ? plan
            : null,
      ),
    );
  }
  for (final shot in existing) {
    if (used.contains(shot.id)) continue;
    result.add(ShotMatch(key: 'app:${shot.id}', existing: shot));
  }
  result.sort((a, b) => a.number.compareTo(b.number));
  return result;
}

/// ¿Ya tiene el plano esta imagen? Por su contenido exacto o, si el Word
/// la trae recomprimida, porque se ve igual. [have] lleva las huellas
/// exactas y las visuales con `v:` delante.
bool alreadyHaveImage(Set<String> have, ImportedImage image) {
  if (have.contains(image.hash)) return true;
  final visual = image.visual;
  if (visual == null) return false;
  for (final h in have) {
    if (h.startsWith('v:') && sameImage(h.substring(2), visual)) return true;
  }
  return false;
}

List<FieldDiff> _headingDiffs(Scene ours, ImportedScene doc) {
  final location = ours.locationPureName.isNotEmpty
      ? ours.locationPureName
      : ours.locationCanonical;
  return [
    // 13 → 13A: el documento la ha partido.
    if (ours.number == doc.number && ours.label != doc.label)
      FieldDiff('label', 'Número', ours.label, doc.label),
    if (!_same(ours.intExt, doc.intExt))
      FieldDiff('intExt', 'Int/Ext', ours.intExt, doc.intExt),
    if (doc.location.isNotEmpty && !_same(location, doc.location))
      FieldDiff('location', 'Lugar', location, doc.location),
    if (doc.dayNight.isNotEmpty && !_same(ours.dayNight, doc.dayNight))
      FieldDiff('dayNight', 'Momento', ours.dayNight, doc.dayNight),
  ];
}

/// Campos de texto del plano que cambian. Un campo vacío en el documento no
/// cuenta: el documento no dice nada sobre él.
List<FieldDiff> shotDiffs(Shot ours, ImportedShot doc) {
  String? plain(String? text) {
    final value = scriptMarkupToPlain(text).trim();
    return value.isEmpty ? null : value;
  }

  final ourCharacters = decodeSceneCharacters(ours.charactersJson);
  return [
    for (final (field, label, mine, theirs) in [
      ('framing', 'Encuadre', plain(ours.framing), doc.framing),
      ('lens', 'Lente', ours.lens, doc.lens),
      ('angle', 'Ángulo', ours.angle, doc.angle),
      ('movement', 'Movimiento', ours.movement, doc.movement),
      ('fStop', 'F', ours.fStop, doc.fStop),
      ('action', 'Acción', plain(ours.action), doc.action),
      ('notes', 'Apuntes', plain(ours.notes), doc.notes),
    ])
      if (theirs != null && !_same(mine, theirs))
        FieldDiff(field, label, mine, theirs),
    if (doc.characters.isNotEmpty && !_sameSet(ourCharacters, doc.characters))
      FieldDiff(
        'characters',
        'Personajes',
        ourCharacters.isEmpty ? null : ourCharacters.join(', '),
        doc.characters.join(', '),
      ),
  ];
}

bool _same(String? a, String? b) =>
    (a ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase() ==
    (b ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

bool _sameSet(List<String> a, List<String> b) =>
    a
        .map((e) => e.trim().toUpperCase())
        .toSet()
        .containsAll(b.map((e) => e.trim().toUpperCase())) &&
    a.length == b.length;
