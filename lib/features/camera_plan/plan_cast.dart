import 'dart:convert';
import 'dart:ui';

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/character_colors.dart';
import '../../core/utils/project_cast_settings.dart';
import 'camera_plan_constants.dart';
import '../../core/utils/scene_color.dart';

/// Un sujeto del reparto: lo que ya está en plantas y lo que propone el guion.
class CastMember {
  final String key;
  final String name;
  final Color color;

  /// Sale en alguna planta del proyecto.
  final bool inPlans;

  /// Lo propone el guion literario: número de escenas en las que aparece.
  final int scriptScenes;
  final bool hidden;

  const CastMember({
    required this.key,
    required this.name,
    required this.color,
    this.inPlans = false,
    this.scriptScenes = 0,
    this.hidden = false,
  });

  bool get fromScript => scriptScenes > 0;
}

/// El reparto completo del proyecto, con lo decidido sobre él.
class CastRoster {
  final List<CastMember> members;
  final ProjectCastSettings settings;

  /// Nombres de los quitados, para poder recuperarlos.
  final Map<String, String> removedNames;

  const CastRoster({
    this.members = const [],
    this.settings = const ProjectCastSettings(),
    this.removedNames = const {},
  });

  List<CastMember> get visible => [
    for (final m in members)
      if (!m.hidden) m,
  ];

  CastMember? byKey(String key) {
    for (final m in members) {
      if (m.key == key) return m;
    }
    return null;
  }

  /// Los sujetos de [group] que siguen en el reparto, ocultos incluidos: un
  /// grupo se despliega entero aunque no estén en la paleta.
  List<CastMember> membersOf(CastGroup group) => [
    for (final key in group.members)
      if (byKey(key) case final member?) member,
  ];
}

/// El reparto de un proyecto en las plantas: cada personaje, con su color.
/// El mismo nombre lleva siempre el mismo color, en todos los planos.
class PlanCast {
  PlanCast._();

  /// «Adil», «ADIL» y « adil » son el mismo personaje.
  static String key(String? name) => (name ?? '').trim().toUpperCase();

  /// Nombres genéricos («Actor 1») no son personajes: no fijan color.
  static bool isNamed(String? name) =>
      key(name).isNotEmpty && !RegExp(r'^ACTOR( \d+)?$').hasMatch(key(name));

  static Future<List<CameraPlanElement>> _actorRows(
    AppDatabase db,
    int projectId,
  ) async {
    final query =
        db.select(db.cameraPlanElements).join([
            innerJoin(
              db.shots,
              db.shots.id.equalsExp(db.cameraPlanElements.shotId),
            ),
          ])
          ..where(
            db.shots.projectId.equals(projectId) &
                db.cameraPlanElements.type.equals('actor'),
          )
          ..orderBy([OrderingTerm.asc(db.cameraPlanElements.id)]);
    final rows = await query.get();
    return [for (final r in rows) r.readTable(db.cameraPlanElements)];
  }

  /// Los personajes que ya salen en alguna planta del proyecto, con el
  /// nombre tal como se escribió la primera vez y su color.
  static Future<Map<String, ({String name, Color color})>> load(
    AppDatabase db,
    int projectId,
  ) async {
    final cast = <String, ({String name, Color color})>{};
    for (final row in await _actorRows(db, projectId)) {
      if (!isNamed(row.label)) continue;
      cast.putIfAbsent(
        key(row.label),
        () => (
          name: row.label!.trim(),
          color: colorFromHex(row.color) ?? kActorColors.first,
        ),
      );
    }
    return cast;
  }

  /// Nombres del campo `charactersJson` de una escena.
  static List<String> _sceneCharacters(String? json) {
    if (json == null || json.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) {}
    return const [];
  }

  /// El reparto del proyecto: los personajes de las plantas y los que propone
  /// el guion, con su color. Primero lo que ya se usa en plantas; lo demás,
  /// por las escenas en las que sale.
  static Future<CastRoster> roster(AppDatabase db, int projectId) async {
    final project = await db.getProject(projectId);
    final settings = decodeCastSettings(project?.characterColorsJson);
    final scriptColors = decodeCharacterColors(project?.characterColorsJson);
    final inPlans = await load(db, projectId);

    final scenes = await (db.select(
      db.scenes,
    )..where((s) => s.projectId.equals(projectId))).get();
    final scenesOf = <String, int>{};
    final scriptName = <String, String>{};
    for (final scene in scenes) {
      if (scene.offScript) continue;
      for (final name in {
        for (final n in _sceneCharacters(scene.charactersJson)) key(n): n,
      }.entries) {
        if (!isNamed(name.value)) continue;
        scenesOf[name.key] = (scenesOf[name.key] ?? 0) + 1;
        scriptName.putIfAbsent(name.key, () => name.value.trim());
      }
    }

    final taken = <Color>[
      for (final c in inPlans.values) c.color,
      for (final hex in scriptColors.values)
        if (colorFromHex(hex) case final c?) c,
    ];
    final members = <CastMember>[];
    final removedNames = <String, String>{};
    for (final entry in inPlans.entries) {
      if (settings.removed.contains(entry.key)) {
        removedNames[entry.key] = entry.value.name;
        continue;
      }
      members.add(
        CastMember(
          key: entry.key,
          name: entry.value.name,
          color: entry.value.color,
          inPlans: true,
          scriptScenes: scenesOf[entry.key] ?? 0,
          hidden: settings.hidden.contains(entry.key),
        ),
      );
    }
    final proposed = scenesOf.keys.where((k) => !inPlans.containsKey(k)).toList()
      ..sort((a, b) {
        final byScenes = scenesOf[b]!.compareTo(scenesOf[a]!);
        return byScenes != 0 ? byScenes : a.compareTo(b);
      });
    for (final k in proposed) {
      if (settings.removed.contains(k)) {
        removedNames[k] = scriptName[k]!;
        continue;
      }
      final color = colorFromHex(scriptColors[k]) ?? freeColor(taken);
      taken.add(color);
      members.add(
        CastMember(
          key: k,
          name: scriptName[k]!,
          color: color,
          scriptScenes: scenesOf[k]!,
          hidden: settings.hidden.contains(k),
        ),
      );
    }
    return CastRoster(
      members: members,
      settings: settings,
      removedNames: removedNames,
    );
  }

  /// Guarda lo decidido sobre el reparto.
  static Future<void> saveSettings(
    AppDatabase db,
    int projectId,
    ProjectCastSettings settings,
  ) async {
    final project = await db.getProject(projectId);
    if (project == null) return;
    await db.updateProject(
      project.copyWith(
        characterColorsJson: Value(
          encodeCastSettings(project.characterColorsJson, settings),
        ),
        updatedAt: DateTime.now(),
      ),
    );
    await db.touchProjectContent(projectId);
  }

  /// Cambia el color de un personaje en todas las plantas y en el guion.
  static Future<void> recolour(
    AppDatabase db,
    int projectId,
    String name,
    Color color,
  ) async {
    if (!isNamed(name)) return;
    final ids = [
      for (final row in await _actorRows(db, projectId))
        if (key(row.label) == key(name)) row.id,
    ];
    if (ids.isNotEmpty) {
      await (db.update(db.cameraPlanElements)..where((e) => e.id.isIn(ids)))
          .write(
            CameraPlanElementsCompanion(color: Value(hexFromColor(color))),
          );
    }
    await _writeScriptColor(db, projectId, name, color);
    await db.touchProjectContent(projectId);
  }

  /// El guion resalta al personaje con el mismo color que la planta.
  static Future<void> _writeScriptColor(
    AppDatabase db,
    int projectId,
    String name,
    Color color,
  ) async {
    final project = await db.getProject(projectId);
    if (project == null) return;
    final raw = project.characterColorsJson;
    final colors = decodeCharacterColors(raw)
      ..[characterColorKey(name)] = hexFromColor(color);
    await db.updateProject(
      project.copyWith(
        characterColorsJson: Value(
          encodeCharacterColors(
            colors,
            manualCharacterLines: decodeManualCharacterLines(raw),
            lineTextOverrides: decodeLineTextOverrides(raw),
            keepCastFrom: raw,
          ),
        ),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Un color que todavía no lleva nadie del reparto.
  static Color freeColor(Iterable<Color> taken) {
    final used = {for (final c in taken) c.toARGB32()};
    for (final c in kActorColors) {
      if (!used.contains(c.toARGB32())) return c;
    }
    return kActorColors[used.length % kActorColors.length];
  }
}
