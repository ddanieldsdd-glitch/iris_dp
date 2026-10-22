import 'package:flutter/foundation.dart' show compute;

import '../../../core/utils/image_fingerprint.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/database/local_database_backup.dart';
import '../../../core/script/script_scene_matcher.dart';
import '../../../core/utils/media_storage.dart';
import '../../../core/utils/scene_characters.dart';
import '../../../core/utils/scene_format.dart';
import '../../../core/utils/shot_reference_import.dart';
import '../../camera_plan/floor_plan_repository.dart';
import '../technical_script_settings.dart';
import 'docx_technical_script_reader.dart';
import 'technical_script_import_plan.dart';

/// Compara [document] con el guion técnico del proyecto: lee lo que hay y las
/// huellas de las imágenes que ya tiene cada plano.
Future<TechnicalScriptImportPlan> prepareTechnicalScriptImport({
  required AppDatabase db,
  required int projectId,
  required ImportedTechnicalScript document,
  Map<String, int?> pairing = const {},
}) async {
  final scenes = await db.watchScenesForProject(projectId).first;
  final shotsByScene = <int, List<Shot>>{};
  final referenceHashes = <int, Set<String>>{};
  final planHashes = <int, Set<String>>{};
  for (final scene in scenes) {
    final shots = await db.watchShotsForScene(scene.id).first;
    shotsByScene[scene.id] = shots;
    for (final shot in shots) {
      final refs = await db.watchReferencesForShot(shot.id).first;
      referenceHashes[shot.id] = {
        for (final path in referenceImagesOf(shot, refs)) ...[
          if (await _hashOf(path) case final hash?) hash,
          if (await _visualOf(path) case final visual?) 'v:$visual',
        ],
      };
      planHashes[shot.id] = {
        for (final path in planSketchesOf(shot)) ...[
          if (await _hashOf(path) case final hash?) hash,
          if (await _visualOf(path) case final visual?) 'v:$visual',
        ],
      };
    }
  }
  return buildTechnicalScriptImportPlan(
    document: document,
    scenes: scenes,
    shotsByScene: shotsByScene,
    referenceHashes: referenceHashes,
    planHashes: planHashes,
    pairing: pairing,
  );
}

final _hashCache = <String, String>{};

Future<String?> _hashOf(String path) async {
  final file = File(path);
  if (!file.existsSync()) return null;
  final key = '$path|${file.lengthSync()}|${file.lastModifiedSync()}';
  if (_hashCache[key] case final hash?) return hash;
  final hash = sha1.convert(await file.readAsBytes()).toString();
  return _hashCache[key] = hash;
}

final _visualCache = <String, String?>{};

/// Huella visual de una imagen de la app, fuera del hilo de la pantalla
/// (las referencias pueden ser fotos grandes).
Future<String?> _visualOf(String path) async {
  final file = File(path);
  if (!file.existsSync()) return null;
  final key = '$path|${file.lengthSync()}|${file.lastModifiedSync()}';
  if (_visualCache.containsKey(key)) return _visualCache[key];
  final visual = await compute(visualFingerprintOfFile, path);
  return _visualCache[key] = visual;
}

/// Lo que hizo la importación, para contárselo al usuario.
class TechnicalScriptImportResult {
  int scenesAdded = 0;
  int shotsAdded = 0;
  int shotsUpdated = 0;
  int scenesDeleted = 0;
  int shotsDeleted = 0;
  int referencesAdded = 0;
  int plansAdded = 0;
  int looseSketches = 0;

  /// Copia de la base hecha antes de escribir; nula en tests.
  String? backupPath;

  String get summary => [
    if (scenesAdded > 0) '$scenesAdded escenas nuevas',
    if (shotsAdded > 0) '$shotsAdded planos nuevos',
    if (shotsUpdated > 0) '$shotsUpdated planos actualizados',
    if (referencesAdded > 0) '$referencesAdded referencias',
    if (plansAdded > 0) '$plansAdded plantas',
    if (looseSketches > 0) '$looseSketches bocetos sueltos',
    if (scenesDeleted > 0) '$scenesDeleted escenas borradas',
    if (shotsDeleted > 0) '$shotsDeleted planos borrados',
  ].join(' · ');
}

/// Escribe en el proyecto lo decidido en la revisión.
///
/// [generalPlanView] es lo que la casilla Planta enseña en general: solo se
/// guarda una excepción en los planos cuya vista elegida sea otra.
Future<TechnicalScriptImportResult> applyTechnicalScriptImport({
  required AppDatabase db,
  required int projectId,
  required TechnicalScriptImportPlan plan,
  required ImportDecisions decisions,
  ScriptPlanView generalPlanView = ScriptPlanView.both,
}) async {
  final result = TechnicalScriptImportResult()
    ..backupPath = await LocalDatabaseBackup.create(
      db,
      label: 'antes-de-importar-guion',
    );
  final sets = await db.watchLocationsForProject(projectId).first;
  // Imagen ya guardada por huella: la planta de una escena se escribe una vez.
  final storedPlans = <String, String>{};
  // Bocetos sueltos que ya están (de una importación anterior).
  final looseByHash = <String, int>{
    for (final setup in await db.getLightSetupsForProject(projectId))
      if (setup.sketchImagePath case final path?)
        if (await _hashOf(path) case final hash?) hash: setup.id,
  };
  final touchedScenes = <int>{};
  var addedScenes = false;

  for (final match in plan.scenes) {
    final sceneChoices = decisions.forScene(match.key);
    final imported = match.imported;

    // Escena solo en la app.
    if (imported == null) {
      if (sceneChoices.deleteOnlyInApp == true && match.existing != null) {
        await db.deleteScene(match.existing!.id);
        result.scenesDeleted++;
      }
      continue;
    }

    Scene scene;
    if (match.existing case final existing?) {
      scene = existing;
      // La letra de una escena partida (13 → 13A) entra siempre: si no, la
      // 13B nueva quedaría junto a una 13 sin letra.
      final split = match.headingDiffs
          .where((d) => d.field == 'label')
          .firstOrNull;
      if (split != null &&
          !existing.scriptLinked &&
          imported.suffix != null &&
          existing.number == imported.number) {
        scene = existing.copyWith(numberSuffix: Value(imported.suffix));
        await db.updateScene(scene);
      }
      if (sceneChoices.text == TextChoice.document && !existing.scriptLinked) {
        scene = await _applyHeading(db, scene, match.headingDiffs);
      }
      await _mergeSceneCharacters(db, scene, imported.characters);
    } else {
      if (sceneChoices.addNew == false) continue;
      scene = await _createScene(db, projectId, imported, sets);
      result.scenesAdded++;
      addedScenes = true;
    }
    touchedScenes.add(scene.id);

    for (final shotMatch in match.shots) {
      final choices = decisions.forShot(match.key, shotMatch.key);
      final doc = shotMatch.imported;
      if (doc == null) {
        if (choices.deleteOnlyInApp && shotMatch.existing != null) {
          await db.deleteShot(shotMatch.existing!.id);
          result.shotsDeleted++;
        }
        continue;
      }

      Shot shot;
      if (shotMatch.existing case final existing?) {
        final fields = [
          for (final diff in shotMatch.diffs)
            if (choices.text == TextChoice.document || diff.fillsEmpty) diff,
        ];
        if (fields.isNotEmpty) {
          await db.updateShotFields(existing.id, _shotFields(fields, doc));
          result.shotsUpdated++;
        }
        shot = (await db.getShotById(existing.id))!;
      } else {
        if (!choices.addNew) continue;
        final id = await db.insertShot(
          ShotsCompanion.insert(
            sceneId: scene.id,
            projectId: projectId,
            number: doc.number,
            framing: Value(doc.framing),
            lens: Value(doc.lens),
            angle: Value(doc.angle),
            movement: Value(doc.movement),
            fStop: Value(doc.fStop),
            action: Value(doc.action),
            notes: Value(doc.notes),
            charactersJson: Value(encodeSceneCharacters(doc.characters)),
            sortOrder: Value(doc.number),
          ),
        );
        shot = (await db.getShotById(id))!;
        result.shotsAdded++;
      }

      result.referencesAdded += await _applyReferences(db, shot, [
        for (final ref
            in shotMatch.existing == null
                ? doc.references
                : shotMatch.newReferences)
          if (decisions.includesReference(shotMatch.key, ref)) ref,
      ], shotMatch.existing == null ? ReferenceMode.back : choices.references);

      final planImage = shotMatch.existing == null
          ? doc.plans.firstOrNull
          : shotMatch.newPlan;
      if (planImage != null) {
        switch (choices.planDestination) {
          case PlanDestination.shotSketch:
            final known = storedPlans[planImage.hash];
            if (known != null) {
              await addShotPlanSketchPath(db: db, shot: shot, path: known);
            } else {
              storedPlans[planImage.hash] = await importShotPlanSketch(
                db: db,
                shot: shot,
                sourceBytes: planImage.bytes,
                fileName: planImage.fileName,
              );
              result.plansAdded++;
            }
          case PlanDestination.looseSketch:
            if (!looseByHash.containsKey(planImage.hash)) {
              looseByHash[planImage.hash] = await _createLooseSketch(
                db,
                scene,
                planImage,
              );
              result.looseSketches++;
            }
          case PlanDestination.skip:
            break;
        }
      }

      await _setPlanView(
        db,
        shot,
        choices.planView.scriptView,
        generalPlanView,
      );
    }
  }

  for (final sceneId in touchedScenes) {
    await _orderShotsByNumber(db, sceneId);
  }
  if (addedScenes) await _orderScenesByNumber(db, projectId);
  await db.touchProjectContent(projectId);
  return result;
}

// ── Escenas ────────────────────────────────────

Future<Scene> _createScene(
  AppDatabase db,
  int projectId,
  ImportedScene doc,
  List<LocationBasePlan> sets,
) async {
  final intExt = doc.intExt.isEmpty ? 'INT' : doc.intExt;
  final dayNight = doc.dayNight.isEmpty ? 'DÍA' : doc.dayNight;
  final location = doc.location.isEmpty ? 'SIN LUGAR' : doc.location;
  final key = _fold(location);
  final set = sets.where((s) => _fold(s.locationName) == key).firstOrNull;
  final id = await db.insertScene(
    ScenesCompanion.insert(
      projectId: projectId,
      number: doc.number,
      numberSuffix: Value(doc.suffix),
      name: formatSceneDefaultName(
        intExt: intExt,
        dayNight: dayNight,
        location: location,
      ),
      locationCanonical: formatSceneMetaLine(
        intExt: intExt,
        dayNight: dayNight,
        location: location,
      ),
      locationPureName: location,
      locationId: Value(set?.id),
      locationSiteId: Value(set?.siteId),
      intExt: Value(intExt),
      dayNight: Value(dayNight),
      charactersJson: Value(encodeSceneCharacters(doc.characters)),
      sortOrder: Value(doc.number),
    ),
  );
  return (await db.getSceneById(id))!;
}

Future<Scene> _applyHeading(
  AppDatabase db,
  Scene scene,
  List<FieldDiff> diffs,
) async {
  if (diffs.isEmpty) return scene;
  String pick(String field, String ours) =>
      diffs.where((d) => d.field == field).firstOrNull?.document ?? ours;
  final intExt = pick('intExt', scene.intExt);
  final dayNight = pick('dayNight', scene.dayNight);
  final location = pick('location', scene.locationPureName);
  final canonical = formatSceneMetaLine(
    intExt: intExt,
    dayNight: dayNight,
    location: location,
  );
  final autoName = isAutoGeneratedSceneName(
    name: scene.name,
    intExt: scene.intExt,
    dayNight: scene.dayNight,
    location: scene.locationPureName,
  );
  final updated = scene.copyWith(
    intExt: intExt,
    dayNight: dayNight,
    locationPureName: location,
    locationCanonical: canonical,
    name: autoName ? canonical : scene.name,
    scriptHeadingKey: Value(
      scene.scriptHeadingKey == null
          ? null
          : scriptHeadingKey(
              intExt: intExt,
              location: location,
              dayNight: dayNight,
            ),
    ),
  );
  await db.updateScene(updated);
  return updated;
}

Future<void> _mergeSceneCharacters(
  AppDatabase db,
  Scene scene,
  List<String> characters,
) async {
  final current = decodeSceneCharacters(scene.charactersJson);
  final known = {for (final c in current) c.toUpperCase()};
  final missing = [
    for (final c in characters)
      if (!known.contains(c.toUpperCase())) c,
  ];
  if (missing.isEmpty) return;
  await db.updateScene(
    scene.copyWith(
      charactersJson: Value(encodeSceneCharacters([...current, ...missing])),
    ),
  );
}

/// Orden de las escenas por número y letra (13, 13A, 13B, 14).
Future<void> _orderScenesByNumber(AppDatabase db, int projectId) async {
  final scenes = [...await db.watchScenesForProject(projectId).first]
    ..sort((a, b) {
      final byNumber = a.number.compareTo(b.number);
      if (byNumber != 0) return byNumber;
      return (a.numberSuffix ?? '').compareTo(b.numberSuffix ?? '');
    });
  for (var i = 0; i < scenes.length; i++) {
    if (scenes[i].sortOrder == i) continue;
    await db.updateScene(scenes[i].copyWith(sortOrder: i));
  }
}

// ── Planos ─────────────────────────────────────

ShotsCompanion _shotFields(List<FieldDiff> fields, ImportedShot doc) {
  bool has(String field) => fields.any((d) => d.field == field);
  return ShotsCompanion(
    framing: has('framing') ? Value(doc.framing) : const Value.absent(),
    lens: has('lens') ? Value(doc.lens) : const Value.absent(),
    angle: has('angle') ? Value(doc.angle) : const Value.absent(),
    movement: has('movement') ? Value(doc.movement) : const Value.absent(),
    fStop: has('fStop') ? Value(doc.fStop) : const Value.absent(),
    action: has('action') ? Value(doc.action) : const Value.absent(),
    notes: has('notes') ? Value(doc.notes) : const Value.absent(),
    charactersJson: has('characters')
        ? Value(encodeSceneCharacters(doc.characters))
        : const Value.absent(),
  );
}

/// Planos en el orden de su número; el número del documento se respeta.
Future<void> _orderShotsByNumber(AppDatabase db, int sceneId) async {
  final shots = [...await db.watchShotsForScene(sceneId).first]
    ..sort((a, b) {
      final byNumber = a.number.compareTo(b.number);
      return byNumber != 0 ? byNumber : a.sortOrder.compareTo(b.sortOrder);
    });
  for (var i = 0; i < shots.length; i++) {
    if (shots[i].sortOrder == i) continue;
    await db.updateShotFields(shots[i].id, ShotsCompanion(sortOrder: Value(i)));
  }
}

Future<int> _applyReferences(
  AppDatabase db,
  Shot shot,
  List<ImportedImage> images,
  ReferenceMode mode,
) async {
  if (images.isEmpty || mode == ReferenceMode.skip) return 0;
  if (mode == ReferenceMode.replace) {
    for (final ref in await db.watchReferencesForShot(shot.id).first) {
      await db.deleteShotReference(ref.id);
    }
    await db.updateShotFields(
      shot.id,
      const ShotsCompanion(referenceImagePath: Value(null)),
    );
    shot = (await db.getShotById(shot.id))!;
  }
  final added = <String>[];
  for (final image in images) {
    final current = (await db.getShotById(shot.id))!;
    added.add(
      await importShotReferenceImage(
        db: db,
        shot: current,
        sourceBytes: image.bytes,
        fileName: image.fileName,
        source: ShotReferenceSource.document,
        keepPrimary: true,
      ),
    );
  }
  if (mode == ReferenceMode.front) {
    // Las del documento delante, en su orden; las nuestras, detrás.
    final refs = await db.watchReferencesForShot(shot.id).first;
    final ordered = [
      for (final path in added) ...refs.where((r) => r.imagePath == path),
      ...refs.where((r) => !added.contains(r.imagePath)),
    ];
    await db.setShotReferenceOrder([for (final r in ordered) r.id]);
    await db.updateShotFields(
      shot.id,
      ShotsCompanion(referenceImagePath: Value(added.first)),
    );
  }
  return added.length;
}

Future<void> _setPlanView(
  AppDatabase db,
  Shot shot,
  ScriptPlanView view,
  ScriptPlanView general,
) async {
  final current = ScriptPlanView.of(shot.cellStylesJson, general);
  if (current == view) return;
  Map<String, dynamic> styles = {};
  try {
    final decoded = jsonDecode(shot.cellStylesJson ?? '{}');
    if (decoded is Map) styles = Map<String, dynamic>.from(decoded);
  } catch (_) {}
  if (view == general) {
    styles.remove(ScriptPlanView.shotKey);
  } else {
    styles[ScriptPlanView.shotKey] = view.name;
  }
  await db.updateShotFields(
    shot.id,
    ShotsCompanion(
      cellStylesJson: Value(styles.isEmpty ? null : jsonEncode(styles)),
    ),
  );
}

/// Boceto suelto en Plantas de cámara y luz con la imagen de planta del
/// documento, en el set de la escena. No se asocia a ningún plano.
Future<int> _createLooseSketch(
  AppDatabase db,
  Scene scene,
  ImportedImage image,
) async {
  final taken = {
    for (final s in await db.getLightSetupsForProject(scene.projectId)) s.name,
  };
  var name = 'Boceto · Esc ${scene.label} (documento)';
  for (var i = 2; taken.contains(name); i++) {
    name = 'Boceto · Esc ${scene.label} (documento $i)';
  }
  final setup = await FloorPlanRepository(db).createLightSetup(
    projectId: scene.projectId,
    setId: scene.locationId,
    siteId: scene.locationId == null ? scene.locationSiteId : null,
    name: name,
    status: 'boceto',
    origin: 'documento',
  );
  final path = await MediaStorage.writeProjectFileBytes(
    projectId: scene.projectId,
    subfolder: 'plantas',
    bytes: Uint8List.fromList(image.bytes),
    fileName: 'boceto_${setup.id}_${image.fileName}',
  );
  await db.updateLightSetup(setup.copyWith(sketchImagePath: Value(path)));
  return setup.id;
}

String _fold(String text) =>
    scriptHeadingKey(intExt: '', location: text, dayNight: '');
