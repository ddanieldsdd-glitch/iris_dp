import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/project/project_shoot_context.dart';
import '../../../../shared/visual_bible/bible_lighting_data.dart';
import '../../bible_section_fields.dart';
import '../../moodboard_helpers.dart';
import '../../services/mired_converter.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_moodboard_image_target.dart';
import '../bible_navigation_scope.dart';
import '../../../camera_plan/camera_plan_screen.dart';
import '../../bible_paste_helpers.dart';
import '../lighting_diagram/lighting_diagram_editor.dart';
import 'lighting_section_hub.dart';
import 'section_scaffold.dart';

/// Iluminación — Acto 1 narrativo global + Acto 2 por localización/set.
class LightingSection extends ConsumerStatefulWidget {
  final VisualBibleData data;
  final int projectId;
  final int bibleId;
  final int? initialPlanId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const LightingSection({
    super.key,
    required this.data,
    required this.projectId,
    required this.bibleId,
    this.initialPlanId,
    this.sectionContentJson,
    required this.onChanged,
  });

  @override
  ConsumerState<LightingSection> createState() => _LightingSectionState();
}

class _LightingSectionState extends ConsumerState<LightingSection> {
  int? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    _selectedPlanId = widget.initialPlanId;
  }

  @override
  void didUpdateWidget(covariant LightingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPlanId != null &&
        widget.initialPlanId != oldWidget.initialPlanId) {
      _selectedPlanId = widget.initialPlanId;
    }
  }

  Map<String, dynamic> _getCustom() {
    if (widget.sectionContentJson == null || widget.sectionContentJson!.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(widget.sectionContentJson!);
      if (decoded is! Map<String, dynamic>) return {};
      final valuesRaw = decoded['values'] ?? decoded['_values'];
      if (valuesRaw is Map) {
        final vals = Map<String, dynamic>.from(valuesRaw);
        if (vals['lightingData'] is String) {
          return BibleLightingData.decode(vals['lightingData'] as String);
        }
        return BibleLightingData.migrate(vals);
      }
    } catch (_) {}
    return {};
  }

  Future<void> _updateCustom(Map<String, dynamic> update) async {
    final current = _getCustom();
    final newData = BibleLightingData.migrate({...current, ...update});
    final db = ref.read(databaseProvider);
    final def =
        await (db.select(db.bibleSectionDefinitions)..where(
              (d) =>
                  d.bibleId.equals(widget.data.id) &
                  d.id.equals(BibleSectionId.lighting),
            ))
            .getSingleOrNull();
    if (def == null) return;
    final fields = BibleSectionFieldsConfig.parse(
      def.contentJson,
      BibleSectionId.lighting,
    );
    final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
    values['lightingData'] = BibleLightingData.encode(newData);
    await db.upsertBibleSectionDefinition(
      def.copyWith(
        contentJson: drift.Value(
          BibleSectionFieldsConfig.encode(fields, values: values),
        ),
      ),
    );
  }

  Future<void> _updatePlan(int planId, Map<String, dynamic> patch) async {
    final merged = BibleLightingData.mergePlan(_getCustom(), planId, patch);
    await _updateCustom(merged);
  }

  Future<void> _syncLightingNote(int planId, String note) async {
    final db = ref.read(databaseProvider);
    final refs = await db.watchLocationRefsForBible(widget.bibleId).first;
    VisualBibleLocationRef? row;
    for (final r in refs) {
      if (r.locationBasePlanId == planId) {
        row = r;
        break;
      }
    }
    if (row != null) {
      await (db.update(db.visualBibleLocationRefs)
            ..where((r) => r.id.equals(row!.id)))
          .write(
        VisualBibleLocationRefsCompanion(
          lightingNote: drift.Value(note.isEmpty ? null : note),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _fixtureList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) {
      if (e is Map) {
        return Map<String, dynamic>.from(e);
      }
      return <String, dynamic>{'name': e.toString()};
    }).toList();
  }

  List<Map<String, String>> _behaviorCards(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) {
      if (e is Map) {
        return {
          'title': e['title']?.toString() ?? '',
          'meta': e['meta']?.toString() ?? '',
          'tag': e['tag']?.toString() ?? '',
          'note': e['note']?.toString() ?? '',
        };
      }
      return {'title': e.toString(), 'meta': '', 'tag': '', 'note': ''};
    }).toList();
  }

  int _parseContrast(String raw) {
    final m = RegExp(r'(\d+)').firstMatch(raw);
    return int.tryParse(m?.group(1) ?? '') ?? 8;
  }

  double _parseTint(String raw) {
    final m = RegExp(r'([+-]?\d+(?:\.\d+)?)').firstMatch(raw);
    return double.tryParse(m?.group(1) ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final custom = _getCustom();

    final heroBadge =
        custom['heroBadge'] as String? ?? 'SCENE • LIGHTING ANALYSIS';
    final heroTitle =
        custom['heroTitle'] as String? ?? 'Estrategia de Iluminación';
    final heroSubtitle =
        custom['heroSubtitle'] as String? ??
        widget.data.contrastStyle ??
        'El Dualismo de la Sombra';

    final visualIntent =
        custom['visualIntent'] as String? ??
        widget.data.lightingPhilosophy ??
        widget.data.lightingNarrativeIntent ??
        '';

    final colorTemp =
        (custom['colorTemp'] as num?)?.toInt() ??
        int.tryParse(
          RegExp(r'(\d+)').firstMatch(widget.data.lightSource ?? '')?.group(1) ?? '',
        ) ??
        5600;
    final tintStr = custom['tint'] as String? ?? '+0.00 G';
    final contrastRatio =
        custom['contrastRatio'] as String? ??
        widget.data.keyFillRatioNight ??
        widget.data.keyFillRatioDay ??
        '8:1';
    final blackIre = (custom['blackLevelIre'] as num?)?.toInt() ?? 0;
    final crushedBlacks = custom['crushedBlacks'] as bool? ?? true;

    var fixtures = _fixtureList(custom['activeFixtures']);
    if (fixtures.isEmpty) {
      fixtures = _fixtureList(custom['equipmentManifest']);
    }
    if (fixtures.isEmpty) {
      fixtures = [
        {'id': 'L1', 'name': 'HMI Par', 'role': 'Key', 'intensity': 100},
        {'id': 'L2', 'name': 'LED Tube', 'role': 'Practical', 'intensity': 30},
        {'id': 'L3', 'name': 'Fresnel', 'role': 'Edge', 'intensity': 85},
      ];
    }

    final fixtureTypes =
        (custom['fixtureTypes'] as List?)?.map((e) => e.toString()).toList() ??
        fixtures
            .map((f) => f['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();

    var behaviors = _behaviorCards(custom['behaviorCards']);
    if (behaviors.isEmpty) {
      behaviors = [
        {
          'title': 'Fall-off Rápido',
          'meta': 'Ratio: $contrastRatio',
          'tag': widget.data.lightQuality ?? 'Hard Light',
          'note': '',
        },
        {
          'title': 'Especularidad',
          'meta': '+2 STOPS',
          'tag': 'Metal',
          'note': '',
        },
        {
          'title': 'Motivación Práctica',
          'meta': '${colorTemp}K',
          'tag': tintStr,
          'note': '',
        },
      ];
    }

    final sourceK = (custom['sourceKelvin'] as num?)?.toInt() ?? 3200;
    final targetK = (custom['targetKelvin'] as num?)?.toInt() ?? colorTemp;
    final gafferDirectives = custom['gafferDirectives'] as String? ?? '';

    final shootCtx = ref.watch(projectShootContextProvider(widget.projectId));
    final selectedPlanId = _selectedPlanId ??
        (custom['selectedPlanId'] as num?)?.toInt() ??
        shootCtx.activeSetId;

    final narrativeStory = (custom['narrativeStory'] as String?)?.isNotEmpty == true
        ? custom['narrativeStory'] as String
        : visualIntent;
    final colorLanguage = custom['colorLanguage'] as String? ?? '';
    final lightSourcesOverview = custom['lightSources'] as String? ?? '';

    final planTelemetry =
        BibleLightingData.telemetryForPlan(custom, selectedPlanId);
    final planColorTemp =
        (planTelemetry['colorTemp'] as num?)?.toInt() ?? colorTemp;
    final planTintStr = planTelemetry['tint'] as String? ?? tintStr;
    final planTintVal = (planTelemetry['tintValue'] as num?)?.toDouble() ??
        _parseTint(planTintStr);
    final planContrastRatio =
        planTelemetry['contrastRatio'] as String? ?? contrastRatio;
    final planContrastNum = (planTelemetry['contrastNum'] as num?)?.toInt() ??
        _parseContrast(planContrastRatio);
    final planBlackIre =
        (planTelemetry['blackLevelIre'] as num?)?.toInt() ?? blackIre;
    final planCrushedBlacks =
        planTelemetry['crushedBlacks'] as bool? ?? crushedBlacks;

    var planFixtures = _fixtureList(planTelemetry['activeFixtures']);
    if (planFixtures.isEmpty) planFixtures = fixtures;
    final planFixtureTypes = (planTelemetry['fixtureTypes'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        fixtureTypes;

    var textureBehaviors = BibleLightingData.textureCards(custom);
    if (textureBehaviors.isEmpty) textureBehaviors = behaviors;

    final planData = BibleLightingData.planFor(custom, selectedPlanId);
    final lightBehavior = planData['lightBehavior'] as String? ?? '';
    final dayNightIntent = planData['dayNightIntent'] as String? ?? '';

    Future<void> updateTelemetry(Map<String, dynamic> patch) async {
      if (selectedPlanId != null) {
        await _updatePlan(selectedPlanId, patch);
      } else {
        await _updateCustom(patch);
      }
    }

    return BibleSectionScaffold(
      sectionId: BibleSectionId.lighting,
      projectId: widget.projectId,
      data: widget.data,
      onChanged: widget.onChanged,
      sectionContentJson: widget.sectionContentJson,
      narrativeHint:
          '¿Por qué iluminamos así? Qué emoción transmite esta filosofía de luz…',
      sectionNumber: null,
      sectionTitle: 'Iluminación',
      fieldWidgets: {
        'narrative': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BibleCrossNavChips.techTriplet(current: BibleSectionId.lighting),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Color'),
                  onPressed: () => BibleNavigationScope.goToSection(
                    context,
                    BibleSectionId.colorImage,
                  ),
                ),
                ActionChip(
                  label: const Text('Textura'),
                  onPressed: () => BibleNavigationScope.goToSection(
                    context,
                    BibleSectionId.texture,
                  ),
                ),
                ActionChip(
                  label: const Text('Localizaciones'),
                  onPressed: () => BibleNavigationScope.goToSection(
                    context,
                    BibleSectionId.location,
                    planId: selectedPlanId,
                  ),
                ),
                ActionChip(
                  label: const Text('Planta cámara'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CameraPlanScreen(
                          projectId: widget.projectId,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _HeroBanner(
              projectId: widget.projectId,
              bibleId: widget.bibleId,
              badge: heroBadge,
              title: heroTitle,
              subtitle: heroSubtitle,
              palette: palette,
              onEditBadge: () async {
                final v = await _prompt(
                  context,
                  'Badge de escena',
                  TextEditingController(text: heroBadge),
                );
                if (v == null) return;
                await _updateCustom({'heroBadge': v});
              },
              onEditTitle: () async {
                final t = TextEditingController(text: heroTitle);
                final s = TextEditingController(text: heroSubtitle);
                final ok = await _promptPair(
                  context,
                  'Título hero',
                  t,
                  s,
                  aLabel: 'Título',
                  bLabel: 'Subtítulo',
                );
                if (ok != true) return;
                await _updateCustom({
                  'heroTitle': t.text.trim(),
                  'heroSubtitle': s.text.trim(),
                });
                if (s.text.trim().isNotEmpty) {
                  widget.data.contrastStyle = s.text.trim();
                  widget.onChanged(widget.data);
                }
              },
            ),
          ],
        ),
        'narrativeStory': _EditableTextBlock(
          icon: Icons.auto_stories_outlined,
          label: 'Qué nos cuenta la luz',
          text: narrativeStory,
          emptyHint: 'Función dramática de la iluminación en la pieza…',
          palette: palette,
          maxLines: 8,
          onEdit: () async {
            final v = await _prompt(context, 'Qué nos cuenta la luz',
                TextEditingController(text: narrativeStory),
                maxLines: 8);
            if (v == null) return;
            await _updateCustom({'narrativeStory': v, 'visualIntent': v});
            widget.data.lightingPhilosophy = v;
            widget.data.lightingNarrativeIntent = v;
            widget.onChanged(widget.data);
          },
        ),
        'colorLanguage': _EditableTextBlock(
          icon: Icons.palette_outlined,
          label: 'Color y luz',
          text: colorLanguage,
          emptyHint: 'Temperatura emocional, paleta motivada por la luz…',
          palette: palette,
          maxLines: 5,
          trailing: ActionChip(
            label: const Text('Color'),
            onPressed: () => BibleNavigationScope.goToSection(
              context,
              BibleSectionId.colorImage,
            ),
          ),
          onEdit: () async {
            final v = await _prompt(context, 'Color y luz',
                TextEditingController(text: colorLanguage),
                maxLines: 5);
            if (v == null) return;
            await _updateCustom({'colorLanguage': v});
          },
        ),
        'textureLanguage': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHead(
              icon: Icons.grain,
              label: 'Textura y atmósfera global',
              palette: palette,
              accent: true,
            ),
            const SizedBox(height: 12),
            _AtmosphericMosaic(
              projectId: widget.projectId,
              bibleId: widget.bibleId,
              behaviors: textureBehaviors,
              contrastRatio: contrastRatio,
              colorTemp: colorTemp,
              tintStr: tintStr,
              palette: palette,
              onEditCard: (i) async {
                final card = textureBehaviors[i];
                final title = TextEditingController(text: card['title']);
                final meta = TextEditingController(text: card['meta']);
                final tag = TextEditingController(text: card['tag']);
                final note = TextEditingController(text: card['note']);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Tarjeta ${i + 1}'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(controller: title, decoration: const InputDecoration(labelText: 'Título')),
                        TextField(controller: meta, decoration: const InputDecoration(labelText: 'Meta')),
                        TextField(controller: tag, decoration: const InputDecoration(labelText: 'Tag')),
                        TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Nota')),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
                    ],
                  ),
                );
                if (ok != true) return;
                final next = [...textureBehaviors];
                next[i] = {
                  'title': title.text.trim(),
                  'meta': meta.text.trim(),
                  'tag': tag.text.trim(),
                  'note': note.text.trim(),
                };
                await _updateCustom({BibleLightingData.textureCardsKey: next});
              },
            ),
            ActionChip(
              label: const Text('Textura'),
              onPressed: () => BibleNavigationScope.goToSection(context, BibleSectionId.texture),
            ),
          ],
        ),
        'lightSources': _EditableTextBlock(
          icon: Icons.lightbulb_outline,
          label: 'Fuentes de luz (filosofía global)',
          text: lightSourcesOverview,
          emptyHint: 'Motivación de prácticos, tipos de fuente…',
          palette: palette,
          maxLines: 6,
          onEdit: () async {
            final v = await _prompt(context, 'Fuentes de luz',
                TextEditingController(text: lightSourcesOverview),
                maxLines: 6);
            if (v == null) return;
            await _updateCustom({'lightSources': v});
          },
        ),
        'gafferPhilosophy': _EditableTextBlock(
          icon: Icons.engineering_outlined,
          label: 'Directivas de gaffer',
          text: gafferDirectives,
          emptyHint: 'Notas generales al gaffer…',
          palette: palette,
          maxLines: 4,
          onEdit: () async {
            final v = await _prompt(context, 'Directivas gaffer',
                TextEditingController(text: gafferDirectives),
                maxLines: 4);
            if (v == null) return;
            await _updateCustom({'gafferDirectives': v});
          },
        ),
        'locationContext': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LightingActDivider(label: 'Iluminación por localización'),
            LightingLocationHub(
              projectId: widget.projectId,
              bibleId: widget.bibleId,
              selectedPlanId: selectedPlanId,
              onSelectSet: (set) {
                setState(() => _selectedPlanId = set.id);
                _updateCustom({'selectedPlanId': set.id});
              },
              onClearSet: () {
                setState(() => _selectedPlanId = null);
                _updateCustom({'selectedPlanId': null});
              },
            ),
          ],
        ),
        'lightBehavior': selectedPlanId == null
            ? _GlassPanel(
                child: Text(
                  'Selecciona un set para definir cómo actúa la luz en esa localización.',
                  style: AppTypography.bodyMedium(palette).copyWith(color: palette.textTertiary),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _EditableTextBlock(
                    icon: Icons.wb_incandescent_outlined,
                    label: 'Comportamiento de luz en set',
                    text: lightBehavior,
                    emptyHint: 'Cómo entra la luz en este set…',
                    palette: palette,
                    maxLines: 6,
                    onEdit: () async {
                      final v = await _prompt(context, 'Comportamiento de luz',
                          TextEditingController(text: lightBehavior),
                          maxLines: 6);
                      if (v == null) return;
                      await _updatePlan(selectedPlanId, {'lightBehavior': v});
                      await _syncLightingNote(selectedPlanId, v);
                    },
                  ),
                  _EditableTextBlock(
                    icon: Icons.nightlight_round,
                    label: 'Intención día / noche',
                    text: dayNightIntent,
                    emptyHint: 'INT. NOCHE — prácticos ventana…',
                    palette: palette,
                    maxLines: 3,
                    onEdit: () async {
                      final v = await _prompt(context, 'Día / noche',
                          TextEditingController(text: dayNightIntent),
                          maxLines: 3);
                      if (v == null) return;
                      await _updatePlan(selectedPlanId, {'dayNightIntent': v});
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Localizaciones'),
                        onPressed: () => BibleNavigationScope.goToSection(
                          context,
                          BibleSectionId.location,
                          planId: selectedPlanId,
                        ),
                      ),
                      ActionChip(
                        label: const Text('Exposición'),
                        onPressed: () => BibleNavigationScope.goToSection(
                          context,
                          BibleSectionId.exposure,
                          planId: selectedPlanId,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        'setTelemetry': selectedPlanId == null
            ? const SizedBox.shrink()
            : _TelemetryPanel(
                colorTemp: planColorTemp,
                tintVal: planTintVal,
                tintStr: planTintStr,
                contrastNum: planContrastNum,
                contrastRatio: planContrastRatio,
                blackIre: planBlackIre,
                crushedBlacks: planCrushedBlacks,
                fixtures: planFixtures,
                fixtureTypes: planFixtureTypes,
                palette: palette,
                onColorTemp: (v) async {
                  await updateTelemetry({'colorTemp': v.round(), 'contrastRatio': planContrastRatio});
                  widget.data.lightSource = '${v.round()}K';
                  widget.onChanged(widget.data);
                },
                onTint: (v) async {
                  final sign = v >= 0 ? '+' : '';
                  await updateTelemetry({'tintValue': v, 'tint': '$sign${v.toStringAsFixed(2)} G'});
                },
                onContrast: (v) async {
                  final r = '${v.round()}:1';
                  await updateTelemetry({'contrastNum': v.round(), 'contrastRatio': r});
                  widget.data.keyFillRatioNight = r;
                  widget.onChanged(widget.data);
                },
                onBlackIre: (v) async => updateTelemetry({'blackLevelIre': v.round()}),
                onToggleCrush: () async => updateTelemetry({'crushedBlacks': !planCrushedBlacks}),
                onEditFixture: (i) async {
                  final f = planFixtures[i];
                  final name = TextEditingController(text: f['name']?.toString() ?? '');
                  final role = TextEditingController(text: f['role']?.toString() ?? '');
                  final inten = TextEditingController(text: '${f['intensity'] ?? 100}');
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(f['id']?.toString() ?? 'Fixture'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(controller: name, decoration: const InputDecoration(labelText: 'Modelo')),
                          TextField(controller: role, decoration: const InputDecoration(labelText: 'Rol')),
                          TextField(controller: inten, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Intensidad %')),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  final next = [...planFixtures];
                  next[i] = {...f, 'name': name.text.trim(), 'role': role.text.trim(), 'intensity': int.tryParse(inten.text.trim()) ?? 100};
                  await updateTelemetry({'activeFixtures': next});
                },
                onAddFixture: () async {
                  await updateTelemetry({
                    'activeFixtures': [
                      ...planFixtures,
                      {'id': 'L${planFixtures.length + 1}', 'name': 'LED Panel', 'role': 'Fill', 'intensity': 50},
                    ],
                  });
                },
                onEditTypes: () async {
                  final c = TextEditingController(text: planFixtureTypes.join(', '));
                  final v = await _prompt(context, 'Tipos de fixture (coma)', c);
                  if (v == null) return;
                  await updateTelemetry({
                    'fixtureTypes': v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  });
                },
              ),
        'miredConverter': _MiredPanel(
          sourceK: sourceK,
          targetK: targetK,
          palette: palette,
          onSource: (v) => _updateCustom({'sourceKelvin': v.round()}),
          onTarget: (v) async {
            await _updateCustom({
              'targetKelvin': v.round(),
              'colorTemp': v.round(),
            });
          },
        ),
        'diagrams': _SetupsBlock(
          projectId: widget.projectId,
          bibleId: widget.bibleId,
          db: db,
          palette: palette,
          filterPlanId: selectedPlanId,
          onAdd: () => _addSetup(context, selectedPlanId),
        ),
        'references': _LightingReferencesBlock(
          projectId: widget.projectId,
          bibleId: widget.bibleId,
          palette: palette,
          selectedPlanId: selectedPlanId,
          planRefs: (planData['referenceImages'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
          onPlanRefsChanged: (paths) async {
            if (selectedPlanId == null) return;
            await _updatePlan(selectedPlanId, {'referenceImages': paths});
          },
        ),
      },
    );
  }

  Future<void> _addSetup(BuildContext context, int? planId) async {
    final palette = context.palette;
    final nameCtrl = TextEditingController();
    final narrativeCtrl = TextEditingController();
    final practicalCtrl = TextEditingController();
    final gelCtrl = TextEditingController();

    int? siteId;
    if (planId != null) {
      final db = ref.read(databaseProvider);
      final plan = await db.getLocationById(planId);
      siteId = plan?.siteId;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surfaceElevated,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.paddingOf(ctx).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nuevo setup de luz',
                  style: AppTypography.titleMedium(palette),
                ),
                const SizedBox(height: 16),
                BibleTextField(
                  label: 'Nombre',
                  hint: 'Beat 1: The Cyan Abyss',
                  onChanged: (_) {},
                  controller: nameCtrl,
                ),
                BibleTextField(
                  label: 'Intención narrativa',
                  hint: 'Qué emoción transmite este setup…',
                  maxLines: 2,
                  onChanged: (_) {},
                  controller: narrativeCtrl,
                ),
                BibleTextField(
                  label: 'Motivación práctica',
                  hint: 'Top-down arrays / practical desk…',
                  maxLines: 2,
                  onChanged: (_) {},
                  controller: practicalCtrl,
                ),
                BibleTextField(
                  label: 'Notas de gel',
                  hint: 'CTB, Plus Green…',
                  maxLines: 2,
                  onChanged: (_) {},
                  controller: gelCtrl,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    await ref
                        .read(databaseProvider)
                        .insertLightingSetup(
                          LightingSetupsCompanion.insert(
                            bibleId: widget.bibleId,
                            setupName: name,
                            narrativeNote: drift.Value(
                              narrativeCtrl.text.trim().isEmpty
                                  ? null
                                  : narrativeCtrl.text.trim(),
                            ),
                            practicalMotivation: drift.Value(
                              practicalCtrl.text.trim().isEmpty
                                  ? null
                                  : practicalCtrl.text.trim(),
                            ),
                            gelNotes: drift.Value(
                              gelCtrl.text.trim().isEmpty
                                  ? null
                                  : gelCtrl.text.trim(),
                            ),
                            locationBasePlanId: drift.Value(planId),
                            locationSiteId: drift.Value(siteId),
                            diagramJson: '[]',
                          ),
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Crear setup'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<String?> _prompt(
    BuildContext context,
    String title,
    TextEditingController c, {
    int maxLines = 1,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, maxLines: maxLines),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> _promptPair(
    BuildContext context,
    String title,
    TextEditingController a,
    TextEditingController b, {
    String aLabel = 'Título',
    String bLabel = 'Detalle',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: a,
              decoration: InputDecoration(labelText: aLabel),
            ),
            TextField(
              controller: b,
              decoration: InputDecoration(labelText: bLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ─── Editable text slot ───────────────────────────────────────────────────────

class _EditableTextBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final String emptyHint;
  final AppPalette palette;
  final int maxLines;
  final VoidCallback onEdit;
  final Widget? trailing;

  const _EditableTextBlock({
    required this.icon,
    required this.label,
    required this.text,
    required this.emptyHint,
    required this.palette,
    required this.maxLines,
    required this.onEdit,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionHead(icon: icon, label: label, palette: palette),
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onEdit,
            child: Text(
              text.isEmpty ? emptyHint : text,
              style: AppTypography.bodyMedium(palette).copyWith(
                fontSize: 15,
                height: 1.55,
                color: text.isEmpty ? palette.textTertiary : palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

class _HeroBanner extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final String badge;
  final String title;
  final String subtitle;
  final AppPalette palette;
  final VoidCallback onEditBadge;
  final VoidCallback onEditTitle;

  const _HeroBanner({
    required this.projectId,
    required this.bibleId,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.onEditBadge,
    required this.onEditTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: BibleMoodboardImageTarget(
        projectId: projectId,
        sectionId: BibleSectionId.lighting,
        bibleId: bibleId,
        hint: 'Clic aquí → ⌘V para pegar hero de iluminación',
        child: SizedBox(
          height: 280,
          child: Stack(
            fit: StackFit.expand,
            children: [
              StreamBuilder<List<MoodboardImage>>(
              stream: db.watchMoodboardImagesForSection(
                projectId,
                BibleSectionId.lighting,
              ),
              builder: (context, snap) {
                final imgs = snap.data ?? [];
                if (imgs.isNotEmpty &&
                    File(imgs.first.imagePath).existsSync()) {
                  return Opacity(
                    opacity: 0.55,
                    child: Image.file(
                      File(imgs.first.imagePath),
                      fit: BoxFit.cover,
                    ),
                  );
                }
                return ColoredBox(
                  color: palette.surfaceOverlay,
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () => MoodboardHelpers.addManualImages(
                        db: db,
                        projectId: projectId,
                        bibleId: bibleId,
                        category: MoodboardCategory.lighting,
                        assignedSections: [BibleSectionId.lighting],
                      ),
                      icon: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: palette.accent,
                      ),
                      label: Text(
                        'Añadir imagen hero',
                        style: TextStyle(color: palette.accent),
                      ),
                    ),
                  ),
                );
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    palette.background.withValues(alpha: 0.4),
                    palette.background,
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    palette.background,
                    palette.background.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              left: 28,
              right: 28,
              bottom: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: onEditBadge,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: palette.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            badge.toUpperCase(),
                            style: AppTypography.mono(palette).copyWith(
                              fontSize: 11,
                              letterSpacing: 1.4,
                              color: palette.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: onEditTitle,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$title\n',
                            style: AppTypography.displayMedium(palette)
                                .copyWith(
                                  fontSize: 36,
                                  height: 1.15,
                                  letterSpacing: -0.8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          TextSpan(
                            text: subtitle,
                            style: AppTypography.displayMedium(palette)
                                .copyWith(
                                  fontSize: 32,
                                  height: 1.2,
                                  letterSpacing: -0.6,
                                  color: palette.textTertiary,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ─── Mosaic ──────────────────────────────────────────────────────────────────

class _AtmosphericMosaic extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final List<Map<String, String>> behaviors;
  final String contrastRatio;
  final int colorTemp;
  final String tintStr;
  final AppPalette palette;
  final void Function(int index) onEditCard;

  const _AtmosphericMosaic({
    required this.projectId,
    required this.bibleId,
    required this.behaviors,
    required this.contrastRatio,
    required this.colorTemp,
    required this.tintStr,
    required this.palette,
    required this.onEditCard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImagesForSection(
        projectId,
        BibleSectionId.lighting,
      ),
      builder: (context, snap) {
        final imgs = snap.data ?? [];
        return LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 700;
            if (!wide) {
              return Column(
                children: [
                  for (var i = 0; i < math.min(3, behaviors.length); i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _BehaviorCard(
                      title: behaviors[i]['title'] ?? '',
                      meta: behaviors[i]['meta'] ?? '',
                      tag: behaviors[i]['tag'] ?? '',
                      note: behaviors[i]['note'] ?? '',
                      imagePath: i < imgs.length ? imgs[i].imagePath : null,
                      tall: i == 0,
                      showTech: i == 0,
                      contrastRatio: contrastRatio,
                      palette: palette,
                      onTap: () => onEditCard(i),
                      onAddImage: () => MoodboardHelpers.addManualImages(
                        db: db,
                        projectId: projectId,
                        bibleId: bibleId,
                        category: MoodboardCategory.lighting,
                        assignedSections: [BibleSectionId.lighting],
                      ),
                    ),
                  ],
                ],
              );
            }
            return SizedBox(
              height: 320,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 8,
                    child: _BehaviorCard(
                      title: behaviors[0]['title'] ?? 'Visual Intent',
                      meta: behaviors[0]['meta'] ?? contrastRatio,
                      tag: behaviors[0]['tag'] ?? '',
                      note: behaviors[0]['note'] ?? '',
                      imagePath: imgs.isNotEmpty ? imgs.first.imagePath : null,
                      tall: true,
                      showTech: true,
                      contrastRatio: contrastRatio,
                      palette: palette,
                      onTap: () => onEditCard(0),
                      onAddImage: () => MoodboardHelpers.addManualImages(
                        db: db,
                        projectId: projectId,
                        bibleId: bibleId,
                        category: MoodboardCategory.lighting,
                        assignedSections: [BibleSectionId.lighting],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        Expanded(
                          child: _BehaviorCard(
                            title: behaviors.length > 1
                                ? (behaviors[1]['title'] ?? 'Specular')
                                : 'Specular Analysis',
                            meta: behaviors.length > 1
                                ? (behaviors[1]['meta'] ?? '')
                                : '+2 STOPS',
                            tag: behaviors.length > 1
                                ? (behaviors[1]['tag'] ?? '')
                                : 'Metal',
                            note: '',
                            imagePath: imgs.length > 1
                                ? imgs[1].imagePath
                                : null,
                            tall: false,
                            showTech: false,
                            contrastRatio: contrastRatio,
                            palette: palette,
                            onTap: () =>
                                onEditCard(behaviors.length > 1 ? 1 : 0),
                            onAddImage: () => MoodboardHelpers.addManualImages(
                              db: db,
                              projectId: projectId,
                              bibleId: bibleId,
                              category: MoodboardCategory.lighting,
                        assignedSections: [BibleSectionId.lighting],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: _BehaviorCard(
                            title: behaviors.length > 2
                                ? (behaviors[2]['title'] ?? 'Color Volume')
                                : 'Color Volume',
                            meta: behaviors.length > 2
                                ? (behaviors[2]['meta'] ?? '${colorTemp}K')
                                : '${colorTemp}K',
                            tag: behaviors.length > 2
                                ? (behaviors[2]['tag'] ?? tintStr)
                                : tintStr,
                            note: '',
                            imagePath: imgs.length > 2
                                ? imgs[2].imagePath
                                : null,
                            tall: false,
                            showTech: false,
                            contrastRatio: contrastRatio,
                            palette: palette,
                            onTap: () =>
                                onEditCard(behaviors.length > 2 ? 2 : 0),
                            onAddImage: () => MoodboardHelpers.addManualImages(
                              db: db,
                              projectId: projectId,
                              bibleId: bibleId,
                              category: MoodboardCategory.lighting,
                        assignedSections: [BibleSectionId.lighting],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _BehaviorCard extends StatelessWidget {
  final String title;
  final String meta;
  final String tag;
  final String note;
  final String? imagePath;
  final bool tall;
  final bool showTech;
  final String contrastRatio;
  final AppPalette palette;
  final VoidCallback onTap;
  final VoidCallback onAddImage;

  const _BehaviorCard({
    required this.title,
    required this.meta,
    required this.tag,
    required this.note,
    required this.imagePath,
    required this.tall,
    required this.showTech,
    required this.contrastRatio,
    required this.palette,
    required this.onTap,
    required this.onAddImage,
  });

  @override
  Widget build(BuildContext context) {
    final hasImg = imagePath != null && File(imagePath!).existsSync();
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: tall ? 280 : 140),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImg)
              Opacity(
                opacity: 0.8,
                child: Image.file(File(imagePath!), fit: BoxFit.cover),
              )
            else
              ColoredBox(
                color: palette.surfaceOverlay,
                child: Center(
                  child: IconButton(
                    onPressed: onAddImage,
                    icon: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: palette.accent,
                    ),
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE60D0D0D)],
                ),
              ),
            ),
            if (showTech)
              Positioned(
                top: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _TechChip(label: 'LUMA ANALYSIS', palette: palette),
                    const SizedBox(height: 4),
                    _TechChip(label: 'RATIO $contrastRatio', palette: palette),
                  ],
                ),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: AppTypography.mono(palette).copyWith(
                      fontSize: 11,
                      letterSpacing: 1.3,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (note.isNotEmpty)
                    Text(
                      note,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium(palette).copyWith(
                        fontSize: 13,
                        color: palette.textSecondary,
                        height: 1.4,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meta,
                            style: AppTypography.mono(palette).copyWith(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        if (tag.isNotEmpty)
                          Text(
                            tag,
                            style: AppTypography.mono(palette).copyWith(
                              fontSize: 12,
                              color: palette.textTertiary,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechChip extends StatelessWidget {
  final String label;
  final AppPalette palette;
  const _TechChip({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        border: Border.all(color: palette.accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTypography.mono(
          palette,
        ).copyWith(fontSize: 10, color: palette.accent.withValues(alpha: 0.85)),
      ),
    );
  }
}

// ─── Telemetry ───────────────────────────────────────────────────────────────

class _TelemetryPanel extends StatefulWidget {
  final int colorTemp;
  final double tintVal;
  final String tintStr;
  final int contrastNum;
  final String contrastRatio;
  final int blackIre;
  final bool crushedBlacks;
  final List<Map<String, dynamic>> fixtures;
  final List<String> fixtureTypes;
  final AppPalette palette;
  final ValueChanged<double> onColorTemp;
  final ValueChanged<double> onTint;
  final ValueChanged<double> onContrast;
  final ValueChanged<double> onBlackIre;
  final VoidCallback onToggleCrush;
  final void Function(int) onEditFixture;
  final VoidCallback onAddFixture;
  final VoidCallback onEditTypes;

  const _TelemetryPanel({
    required this.colorTemp,
    required this.tintVal,
    required this.tintStr,
    required this.contrastNum,
    required this.contrastRatio,
    required this.blackIre,
    required this.crushedBlacks,
    required this.fixtures,
    required this.fixtureTypes,
    required this.palette,
    required this.onColorTemp,
    required this.onTint,
    required this.onContrast,
    required this.onBlackIre,
    required this.onToggleCrush,
    required this.onEditFixture,
    required this.onAddFixture,
    required this.onEditTypes,
  });

  @override
  State<_TelemetryPanel> createState() => _TelemetryPanelState();
}

class _TelemetryPanelState extends State<_TelemetryPanel> {
  late double _temp;
  late double _tint;
  late double _contrast;
  late double _black;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant _TelemetryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.colorTemp != widget.colorTemp ||
        oldWidget.tintVal != widget.tintVal ||
        oldWidget.contrastNum != widget.contrastNum ||
        oldWidget.blackIre != widget.blackIre) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    _temp = widget.colorTemp.toDouble();
    _tint = widget.tintVal;
    _contrast = widget.contrastNum.toDouble();
    _black = widget.blackIre.toDouble();
  }

  String get _tintLabel {
    final sign = _tint >= 0 ? '+' : '';
    return '$sign${_tint.toStringAsFixed(2)} G';
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'TELEMETRY METRICS',
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: palette.accent,
                ),
              ),
              const Spacer(),
              Icon(Icons.memory, size: 18, color: palette.accent),
            ],
          ),
          Divider(height: 28, color: Colors.white.withValues(alpha: 0.08)),
          _MetricLabel(
            label: 'Color Temp',
            value: '${_temp.round()}K',
            palette: palette,
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: _temp.clamp(2000, 10000),
              min: 2000,
              max: 10000,
              divisions: 80,
              activeColor: palette.accent,
              inactiveColor: Colors.white12,
              onChanged: (v) => setState(() => _temp = v),
              onChangeEnd: widget.onColorTemp,
            ),
          ),
          Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8914), Colors.white, Color(0xFF5C98FF)],
              ),
            ),
          ),
          const SizedBox(height: 22),
          _MetricLabel(
            label: 'Tint / Shift',
            value: _tintLabel,
            palette: palette,
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: _tint.clamp(-0.5, 0.5),
              min: -0.5,
              max: 0.5,
              divisions: 100,
              activeColor: palette.accent,
              inactiveColor: Colors.white12,
              onChanged: (v) => setState(() => _tint = v),
              onChangeEnd: widget.onTint,
            ),
          ),
          const SizedBox(height: 12),
          _MetricLabel(
            label: 'Contrast Ratio (Target)',
            value: '${_contrast.round()}:1',
            palette: palette,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(height: 16, color: Colors.white),
              ),
              Expanded(
                flex: _contrast.round().clamp(1, 32),
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 2),
            child: Slider(
              value: _contrast.clamp(2, 32),
              min: 2,
              max: 32,
              divisions: 30,
              activeColor: palette.accent,
              inactiveColor: Colors.white12,
              onChanged: (v) => setState(() => _contrast = v),
              onChangeEnd: widget.onContrast,
            ),
          ),
          const SizedBox(height: 8),
          _MetricLabel(
            label: 'Black Level (IRE)',
            value: '${_black.round()}%',
            palette: palette,
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 2),
            child: Slider(
              value: _black.clamp(0, 20),
              min: 0,
              max: 20,
              divisions: 20,
              activeColor: palette.accent,
              inactiveColor: Colors.white12,
              onChanged: (v) => setState(() => _black = v),
              onChangeEnd: widget.onBlackIre,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: widget.onToggleCrush,
              child: Text(
                widget.crushedBlacks
                    ? 'Crushed Blacks Allowed'
                    : 'Preserve Shadow Detail',
                style: AppTypography.mono(
                  palette,
                ).copyWith(fontSize: 10, color: palette.textTertiary),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),
          Text(
            'ACTIVE FIXTURES',
            style: AppTypography.mono(
              palette,
            ).copyWith(fontSize: 10, letterSpacing: 1.4, color: palette.accent),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < widget.fixtures.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => widget.onEditFixture(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${widget.fixtures[i]['id'] ?? 'L${i + 1}'}: '
                          '${widget.fixtures[i]['name'] ?? ''} '
                          '(${widget.fixtures[i]['role'] ?? ''})',
                          style: AppTypography.mono(palette).copyWith(
                            fontSize: 11,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '${widget.fixtures[i]['intensity'] ?? 0}%',
                        style: AppTypography.mono(
                          palette,
                        ).copyWith(fontSize: 11, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          TextButton.icon(
            onPressed: widget.onAddFixture,
            icon: Icon(Icons.add, size: 16, color: palette.accent),
            label: Text(
              'Añadir fixture',
              style: TextStyle(color: palette.accent, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: widget.onEditTypes,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in widget.fixtureTypes)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      t,
                      style: AppTypography.mono(palette).copyWith(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricLabel extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  const _MetricLabel({
    required this.label,
    required this.value,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: AppTypography.mono(palette).copyWith(
              fontSize: 11,
              letterSpacing: 1.1,
              color: palette.textTertiary,
            ),
          ),
        ),
        Text(
          value,
          style: AppTypography.mono(
            palette,
          ).copyWith(fontSize: 12, color: Colors.white),
        ),
      ],
    );
  }
}

// ─── Mired ───────────────────────────────────────────────────────────────────

class _MiredPanel extends StatelessWidget {
  final int sourceK;
  final int targetK;
  final AppPalette palette;
  final ValueChanged<double> onSource;
  final ValueChanged<double> onTarget;

  const _MiredPanel({
    required this.sourceK,
    required this.targetK,
    required this.palette,
    required this.onSource,
    required this.onTarget,
  });

  @override
  Widget build(BuildContext context) {
    final gel = MiredConverter.recommendGel(
      sourceKelvin: sourceK,
      targetKelvin: targetK,
    );
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHead(
            icon: Icons.thermostat,
            label: 'Mired / Kelvin / Gel',
            palette: palette,
          ),
          const SizedBox(height: 16),
          _MetricLabel(
            label: 'Source Kelvin',
            value: '${sourceK}K',
            palette: palette,
          ),
          Slider(
            value: sourceK.clamp(2000, 10000).toDouble(),
            min: 2000,
            max: 10000,
            divisions: 80,
            activeColor: palette.accent,
            onChanged: onSource,
          ),
          _MetricLabel(
            label: 'Target Kelvin',
            value: '${targetK}K',
            palette: palette,
          ),
          Slider(
            value: targetK.clamp(2000, 10000).toDouble(),
            min: 2000,
            max: 10000,
            divisions: 80,
            activeColor: palette.accent,
            onChanged: onTarget,
          ),
          const SizedBox(height: 8),
          Text(
            gel == null ? 'Sin corrección de gel recomendada' : gel.description,
            style: AppTypography.mono(palette).copyWith(
              fontSize: 12,
              color: gel == null ? palette.textTertiary : palette.accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ΔMired '
            '${(MiredConverter.kelvinToMired(sourceK) - MiredConverter.kelvinToMired(targetK)).toStringAsFixed(1)}',
            style: AppTypography.mono(
              palette,
            ).copyWith(fontSize: 11, color: palette.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ─── Referencias ─────────────────────────────────────────────────────────────

class _LightingReferencesBlock extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final AppPalette palette;
  final int? selectedPlanId;
  final List<String> planRefs;
  final Future<void> Function(List<String> paths) onPlanRefsChanged;

  const _LightingReferencesBlock({
    required this.projectId,
    required this.bibleId,
    required this.palette,
    required this.selectedPlanId,
    required this.planRefs,
    required this.onPlanRefsChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    Future<void> pasteToPlan() async {
      if (selectedPlanId == null) return;
      await BiblePasteHelpers.pasteFromClipboard(
        onPayload: (payload) async {
          final path = await BiblePasteHelpers.savePayloadToProject(
            projectId: projectId,
            subfolder: 'lighting_refs',
            payload: payload,
          );
          if (path != null) {
            await onPlanRefsChanged([...planRefs, path]);
          }
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead(
          icon: Icons.photo_library_outlined,
          label: selectedPlanId == null
              ? 'Referencias globales'
              : 'Referencias del set',
          palette: palette,
        ),
        const SizedBox(height: 12),
        if (selectedPlanId == null)
          StreamBuilder<List<MoodboardImage>>(
            stream: db.watchMoodboardImagesForSection(
              projectId,
              BibleSectionId.lighting,
            ),
            builder: (context, snap) {
              final imgs = snap.data ?? [];
              if (imgs.isEmpty) {
                return _GlassPanel(
                  child: Text(
                    'Pega imágenes en el hero o selecciona un set para refs por localización.',
                    style: AppTypography.bodyMedium(palette)
                        .copyWith(color: palette.textTertiary),
                  ),
                );
              }
              return SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: imgs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final file = File(imgs[i].imagePath);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: file.existsSync()
                          ? Image.file(file, width: 160, height: 120, fit: BoxFit.cover)
                          : const SizedBox(width: 160, height: 120),
                    );
                  },
                ),
              );
            },
          )
        else ...[
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: planRefs.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == planRefs.length) {
                  return BibleMoodboardImageTarget(
                    projectId: projectId,
                    sectionId: BibleSectionId.lighting,
                    bibleId: bibleId,
                    hint: '⌘V — ref del set',
                    child: InkWell(
                      onTap: pasteToPlan,
                      child: Container(
                        width: 160,
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: palette.border,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: palette.accent),
                            const SizedBox(height: 4),
                            Text('Pegar ref',
                                style: TextStyle(
                                    color: palette.accent, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                final file = File(planRefs[i]);
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: file.existsSync()
                          ? Image.file(file,
                              width: 160, height: 120, fit: BoxFit.cover)
                          : const SizedBox(width: 160, height: 120),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          minimumSize: const Size(28, 28),
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.close, size: 16, color: Colors.white),
                        onPressed: () {
                          final next = [...planRefs]..removeAt(i);
                          onPlanRefsChanged(next);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => MoodboardHelpers.addManualImages(
              db: db,
              projectId: projectId,
              bibleId: bibleId,
              category: MoodboardCategory.lighting,
              assignedSections: [BibleSectionId.lighting],
            ),
            icon: Icon(Icons.folder_open, size: 16, color: palette.accent),
            label: Text('Elegir desde Finder',
                style: TextStyle(color: palette.accent, fontSize: 12)),
          ),
        ],
      ],
    );
  }
}

// ─── Setup card ──────────────────────────────────────────────────────────────

class _SetupCard extends ConsumerStatefulWidget {
  final LightingSetupModel setup;
  final LightingSetup row;
  final int projectId;
  final int bibleId;
  final AppDatabase db;
  final AppPalette palette;

  const _SetupCard({
    required this.setup,
    required this.row,
    required this.projectId,
    required this.bibleId,
    required this.db,
    required this.palette,
  });

  @override
  ConsumerState<_SetupCard> createState() => _SetupCardState();
}

class _SetupCardState extends ConsumerState<_SetupCard> {
  String? _setName;

  @override
  void initState() {
    super.initState();
    _loadSetName();
  }

  Future<void> _loadSetName() async {
    final planId = widget.setup.locationBasePlanId;
    if (planId == null) return;
    final plan = await widget.db.getLocationById(planId);
    if (mounted && plan != null) {
      setState(() => _setName = plan.locationName);
    }
  }

  Future<void> _saveRefPath(String? path) async {
    await widget.db.updateLightingSetup(
      widget.row.copyWith(referenceImagePath: drift.Value(path)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final setup = widget.setup;
    final palette = widget.palette;
    final db = widget.db;

    return _GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_setName != null) ...[
                        Text(
                          _setName!.toUpperCase(),
                          style: AppTypography.mono(palette).copyWith(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: palette.accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        setup.setupName,
                        style: AppTypography.titleMedium(palette)
                            .copyWith(fontSize: 18),
                      ),
                      if (setup.narrativeNote?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          setup.narrativeNote!,
                          style: AppTypography.bodyMedium(palette).copyWith(
                            color: palette.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (setup.practicalMotivation?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          'MOTIVACIÓN: ${setup.practicalMotivation}',
                          style: AppTypography.mono(palette).copyWith(
                            fontSize: 11,
                            color: palette.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: palette.error, size: 20),
                  onPressed: () => db.deleteLightingSetup(setup.id),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: BibleMoodboardImageTarget(
                projectId: widget.projectId,
                sectionId: BibleSectionId.lighting,
                bibleId: widget.bibleId,
                hint: '⌘V — ref del setup',
                child: AspectRatio(
                  aspectRatio: 16 / 5,
                  child: InkWell(
                    onTap: () async {
                      await BiblePasteHelpers.pasteFromClipboard(
                        onPayload: (payload) async {
                          final path =
                              await BiblePasteHelpers.savePayloadToProject(
                            projectId: widget.projectId,
                            subfolder: 'lighting_setups',
                            payload: payload,
                          );
                          if (path != null) await _saveRefPath(path);
                        },
                      );
                    },
                    child: setup.referenceImagePath != null &&
                            File(setup.referenceImagePath!).existsSync()
                        ? Image.file(
                            File(setup.referenceImagePath!),
                            fit: BoxFit.cover,
                          )
                        : ColoredBox(
                            color: palette.surfaceOverlay,
                            child: Center(
                              child: Text(
                                'Pegar referencia del setup',
                                style: TextStyle(
                                  color: palette.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          SizedBox(
            height: 280,
            child: LightingDiagramEditor(
              key: ValueKey('lighting-diagram-${setup.id}'),
              database: db,
              projectId: widget.projectId,
              setupId: setup.id,
              setName: _setName,
              locationBasePlanId: setup.locationBasePlanId,
              initialJson: setup.diagramJson,
              onChanged: (json) async {
                await db.updateLightingSetup(
                  widget.row.copyWith(diagramJson: json),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Setups ──────────────────────────────────────────────────────────────────

class _SetupsBlock extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final AppDatabase db;
  final AppPalette palette;
  final int? filterPlanId;
  final VoidCallback onAdd;

  const _SetupsBlock({
    required this.projectId,
    required this.bibleId,
    required this.db,
    required this.palette,
    this.filterPlanId,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'LIGHTING SETUPS',
              style: AppTypography.mono(palette).copyWith(
                fontSize: 12,
                letterSpacing: 1.4,
                color: palette.textTertiary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: Icon(Icons.add, color: palette.accent, size: 18),
              label: Text(
                'Nuevo setup',
                style: TextStyle(color: palette.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<LightingSetup>>(
          stream: db.watchLightingSetupsForBible(bibleId),
          builder: (context, snap) {
            var setups = snap.data ?? [];
            if (filterPlanId != null) {
              setups = setups
                  .where(
                    (s) =>
                        s.locationBasePlanId == filterPlanId ||
                        s.locationBasePlanId == null,
                  )
                  .toList();
            }
            if (setups.isEmpty) {
              return _GlassPanel(
                child: Text(
                  'Sin setups. Crea uno para diagramar key/fill y motivación práctica.',
                  style: AppTypography.bodyMedium(
                    palette,
                  ).copyWith(color: palette.textTertiary),
                ),
              );
            }
            return Column(
              children: setups.map((row) {
                final setup = LightingSetupModel.fromRow(row);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _SetupCard(
                    setup: setup,
                    row: row,
                    projectId: projectId,
                    bibleId: bibleId,
                    db: db,
                    palette: palette,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ─── Shared chrome ───────────────────────────────────────────────────────────

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _GlassPanel({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _SectionHead extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppPalette palette;
  final bool accent;

  const _SectionHead({
    required this.icon,
    required this.label,
    required this.palette,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: accent ? palette.accent : palette.textTertiary,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: accent
              ? AppTypography.mono(palette).copyWith(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: palette.accent,
                )
              : AppTypography.titleMedium(palette).copyWith(fontSize: 20),
        ),
      ],
    );
  }
}
