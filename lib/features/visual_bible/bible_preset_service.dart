import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/templates/user_template_models.dart';
import '../../core/templates/user_template_service.dart';
import 'bible_blueprint.dart';
import 'bible_blueprint_service.dart';
import 'bible_preset_bundle.dart';
import 'bible_section_fields.dart';
import 'bible_section_style_store.dart';
import 'visual_bible_export_config.dart';
import 'visual_bible_model.dart';

/// Guarda y aplica [BiblePresetBundle] (layout + estilos + blueprint + seed).
abstract final class BiblePresetService {
  BiblePresetService._();

  /// Guarda el estado actual de la biblia como plantilla de usuario (bundle).
  static Future<String> saveCurrentAsBundle({
    required AppDatabase db,
    required int projectId,
    required int bibleId,
    required String name,
    String? description,
    String? existingId,
  }) async {
    final groups = await (db.select(db.bibleSectionGroups)
          ..where((g) => g.bibleId.equals(bibleId)))
        .get();
    final sections = await (db.select(db.bibleSectionDefinitions)
          ..where((d) => d.bibleId.equals(bibleId)))
        .get();
    final blueprint = await BibleConfigStore.loadBlueprint(projectId);
    final styles = await BibleSectionStyleStore.loadAll(projectId);
    final export = await VisualBibleExportConfigStore.loadLast(projectId);

    final layout = BibleLayoutTemplatePayload(
      groups: groups
          .map(
            (g) => BibleLayoutGroupPayload(
              id: g.id,
              label: g.label,
              sortOrder: g.sortOrder,
              isBuiltIn: g.isBuiltIn,
            ),
          )
          .toList(),
      sections: sections
          .map(
            (s) => BibleLayoutSectionPayload(
              id: s.id,
              groupId: s.groupId,
              label: s.label,
              iconKey: s.iconKey,
              sortOrder: s.sortOrder,
              isBuiltIn: s.isBuiltIn,
              isHidden: s.isHidden,
              template: s.template,
              contentJson: s.contentJson,
            ),
          )
          .toList(),
    );

    final bundle = BiblePresetBundle(
      id: existingId ?? const Uuid().v4(),
      name: name,
      description: description ?? 'Plantilla de usuario',
      blueprint: blueprint,
      layout: layout,
      sectionStyles: styles,
      exportDefaults: export,
      includes: const ['Layout', 'Estilos', 'Blueprint', 'Export'],
    );

    return UserTemplateService.upsertRaw(
      db: db,
      type: UserTemplateType.bibleLayout,
      name: name,
      description: description ?? bundle.description,
      payloadJson: bundle.encode(),
      existingId: existingId,
    );
  }

  static Future<void> applyBundle({
    required AppDatabase db,
    required int projectId,
    required int bibleId,
    required BiblePresetBundle bundle,
    bool applySampleSeed = true,
  }) async {
    // Blueprint (visibilidad + estilos default).
    await BibleBlueprintService.apply(
      db: db,
      bibleId: bibleId,
      projectId: projectId,
      type: bundle.blueprint,
    );

    // Layout personalizado si existe.
    if (bundle.layout != null &&
        (bundle.layout!.groups.isNotEmpty ||
            bundle.layout!.sections.isNotEmpty)) {
      await db.applyBibleLayoutTemplate(bibleId, bundle.layout!);
    }

    // Estilos del bundle (override blueprint defaults).
    if (bundle.sectionStyles.isNotEmpty) {
      await BibleSectionStyleStore.saveMany(projectId, bundle.sectionStyles);
    }

    if (bundle.exportDefaults != null) {
      await VisualBibleExportConfigStore.saveLast(
        projectId,
        bundle.exportDefaults!,
      );
    }

    if (applySampleSeed && bundle.sampleSeed != null) {
      await _applySampleSeed(
        db: db,
        bibleId: bibleId,
        seed: bundle.sampleSeed!,
      );
    }
  }

  static Future<void> applyById({
    required AppDatabase db,
    required int projectId,
    required int bibleId,
    required String templateId,
    bool applySampleSeed = true,
  }) async {
    final builtin = BibleBuiltinPresets.byId(templateId);
    if (builtin != null) {
      await applyBundle(
        db: db,
        projectId: projectId,
        bibleId: bibleId,
        bundle: builtin,
        applySampleSeed: applySampleSeed,
      );
      return;
    }

    if (templateId == kBuiltinBibleLayoutTemplateId) {
      await db.resetBibleSectionLayoutToBuiltin(bibleId);
      return;
    }

    final template = await UserTemplateService.getTemplate(db, templateId);
    if (template == null) return;

    final bundle = BiblePresetBundle.tryDecode(template.payloadJson);
    if (bundle != null) {
      await applyBundle(
        db: db,
        projectId: projectId,
        bibleId: bibleId,
        bundle: bundle,
        applySampleSeed: applySampleSeed,
      );
      return;
    }

    // Legacy layout-only.
    await UserTemplateService.applyBibleLayoutTemplate(
      db: db,
      bibleId: bibleId,
      templateId: templateId,
    );
  }

  static Future<void> _applySampleSeed({
    required AppDatabase db,
    required int bibleId,
    required BiblePresetSampleSeed seed,
  }) async {
    final row = await (db.select(db.visualBibles)
          ..where((v) => v.id.equals(bibleId)))
        .getSingleOrNull();
    if (row == null) return;

    final data = VisualBibleData.fromRow(row);
    final f = seed.visualBibleFields;

    void setStr(String key, void Function(String?) assign) {
      final v = f[key];
      if (v is String && v.trim().isNotEmpty) assign(v);
    }

    setStr('visualConcept', (v) => data.visualConcept = v);
    setStr('tone', (v) => data.tone = v);
    setStr('creativeIntention', (v) => data.creativeIntention = v);
    setStr('lightingPhilosophy', (v) => data.lightingPhilosophy = v);
    setStr('lightQuality', (v) => data.lightQuality = v);
    setStr('contrastStyle', (v) => data.contrastStyle = v);
    setStr('keyFillRatioNight', (v) => data.keyFillRatioNight = v);
    setStr('keyFillRatioDay', (v) => data.keyFillRatioDay = v);
    setStr('lightSource', (v) => data.lightSource = v);
    setStr('defaultTStop', (v) => data.defaultTStop = v);
    setStr('highlightBehavior', (v) => data.highlightBehavior = v);
    setStr('shadowBehavior', (v) => data.shadowBehavior = v);
    setStr('grainLevel', (v) => data.grainLevel = v);
    setStr('imageTexture', (v) => data.imageTexture = v);
    setStr('diffusionNotes', (v) => data.diffusionNotes = v);
    setStr('workingLutName', (v) => data.workingLutName = v);
    setStr('creativeLutName', (v) => data.creativeLutName = v);
    setStr('aspectRatio', (v) => data.aspectRatio = v);
    setStr('directionNarrativeIntent', (v) => data.directionNarrativeIntent = v);
    setStr('conceptNarrativeIntent', (v) => data.conceptNarrativeIntent = v);
    setStr('lightingNarrativeIntent', (v) => data.lightingNarrativeIntent = v);
    setStr('exposureNarrativeIntent', (v) => data.exposureNarrativeIntent = v);
    setStr('colorNarrativeIntent', (v) => data.colorNarrativeIntent = v);
    setStr('textureNarrativeIntent', (v) => data.textureNarrativeIntent = v);
    if (f['nativeIso'] is num) {
      data.nativeIso = (f['nativeIso'] as num).toInt();
    }

    await db.upsertVisualBible(data.toCompanion());

    final existingColors = await db.watchColorBlocksForBible(bibleId).first;
    if (existingColors.isEmpty && seed.colorBlocks.isNotEmpty) {
      for (var i = 0; i < seed.colorBlocks.length; i++) {
        final b = seed.colorBlocks[i];
        await db.insertColorBlock(
          VisualBibleColorBlocksCompanion.insert(
            bibleId: bibleId,
            blockName: b['blockName'] as String? ?? 'Paleta ${i + 1}',
            dominantColors: jsonEncode(b['dominantColors'] ?? []),
            accentColors: Value(
              b['accentColors'] != null
                  ? jsonEncode(b['accentColors'])
                  : null,
            ),
            prohibitedColors: Value(
              b['prohibitedColors'] != null
                  ? jsonEncode(b['prohibitedColors'])
                  : null,
            ),
            colorTempKelvin: Value((b['colorTempKelvin'] as num?)?.toInt()),
            sortOrder: Value(i),
          ),
        );
      }
    }

    final existingSetups = await db.watchLightingSetupsForBible(bibleId).first;
    if (existingSetups.isEmpty && seed.lightingSetups.isNotEmpty) {
      for (final s in seed.lightingSetups) {
        await db.insertLightingSetup(
          LightingSetupsCompanion.insert(
            bibleId: bibleId,
            setupName: s['setupName'] as String? ?? 'Setup',
            diagramJson: '[]',
            narrativeNote: Value(s['narrativeNote'] as String?),
            gelNotes: Value(s['gelNotes'] as String?),
            practicalMotivation: Value(s['practicalMotivation'] as String?),
          ),
        );
      }
    }

    for (final entry in seed.sectionValues.entries) {
      final sectionId = entry.key;
      final valuesUpdate = Map<String, dynamic>.from(entry.value as Map);
      final def = await (db.select(db.bibleSectionDefinitions)
            ..where(
              (d) =>
                  d.bibleId.equals(bibleId) & d.id.equals(sectionId),
            ))
          .getSingleOrNull();
      if (def == null) continue;

      final fields = BibleSectionFieldsConfig.parse(def.contentJson, sectionId);
      final values = BibleSectionFieldsConfig.parseValues(def.contentJson);

      final dataKey = switch (sectionId) {
        BibleSectionId.lighting => 'lightingData',
        BibleSectionId.exposure => 'exposureData',
        BibleSectionId.colorImage => 'colorData',
        BibleSectionId.texture => 'textureData',
        BibleSectionId.concept => 'conceptData',
        BibleSectionId.location => 'locationData',
        _ => null,
      };

      if (dataKey != null) {
        Map<String, dynamic> existing = {};
        final raw = values[dataKey];
        if (raw != null && raw.isNotEmpty) {
          try {
            final p = jsonDecode(raw);
            if (p is Map) existing = Map<String, dynamic>.from(p);
          } catch (_) {}
        }
        values[dataKey] = jsonEncode({...existing, ...valuesUpdate});
      } else {
        for (final e in valuesUpdate.entries) {
          values[e.key] = e.value is String
              ? e.value as String
              : jsonEncode(e.value);
        }
      }

      await db.upsertBibleSectionDefinition(
        def.copyWith(
          contentJson: Value(
            BibleSectionFieldsConfig.encode(fields, values: values),
          ),
        ),
      );
    }
  }
}
