import '../../core/database/app_database.dart';
import 'bible_blueprint.dart';
import 'bible_section_style_store.dart';

/// Aplica blueprints y repara corrupción de `template` ↔ estilo.
abstract final class BibleBlueprintService {
  /// Si Master Config escribió estilos en `template`, restaura el renderer.
  static Future<int> repairCorruptedTemplates({
    required AppDatabase db,
    required int bibleId,
    required int projectId,
  }) async {
    final defs = await db.watchBibleSectionDefinitions(bibleId).first;
    var fixed = 0;
    final recoveredStyles = <String, BibleSectionStyle>{};

    for (final def in defs) {
      if (!BibleSectionRenderer.isCorruptedAesthetic(def.template)) continue;
      final style = BibleSectionStyle.values.firstWhere(
        (s) => s.name == def.template,
        orElse: () => BibleSectionStyle.cinematic,
      );
      recoveredStyles[def.id] = style;
      await db.upsertBibleSectionDefinition(
        def.copyWith(template: BibleSectionRenderer.builtinFor(def.id)),
      );
      fixed++;
    }

    if (recoveredStyles.isNotEmpty) {
      await BibleSectionStyleStore.saveMany(projectId, recoveredStyles);
    }
    return fixed;
  }

  /// Aplica blueprint: visibilidad + estilos (sin tocar renderer `template`).
  static Future<void> apply({
    required AppDatabase db,
    required int bibleId,
    required int projectId,
    required BibleBlueprintType type,
  }) async {
    await repairCorruptedTemplates(
      db: db,
      bibleId: bibleId,
      projectId: projectId,
    );

    final defs = await db.watchBibleSectionDefinitions(bibleId).first;
    final hidden = type.defaultHiddenSectionIds;
    final styles = <String, BibleSectionStyle>{};

    for (final def in defs) {
      if (def.id == 'settings') continue;

      final shouldHide = hidden.contains(def.id);
      if (def.isHidden != shouldHide) {
        await db.setBibleSectionHidden(
          bibleId: bibleId,
          sectionId: def.id,
          hidden: shouldHide,
        );
      }

      styles[def.id] = defaultStyleForSection(def.id, type);
    }

    await BibleSectionStyleStore.saveMany(projectId, styles);
    await BibleConfigStore.saveBlueprint(projectId, type);
  }
}
