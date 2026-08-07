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
import '../../bible_section_fields.dart';
import '../../moodboard_helpers.dart';
import '../../services/mired_converter.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_navigation_scope.dart';
import '../lighting_diagram/lighting_diagram_editor.dart';
import 'section_scaffold.dart';

/// Iluminación — layout Stitch (hero + intent + telemetry + setups).
class LightingSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final int bibleId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const LightingSection({
    super.key,
    required this.data,
    required this.projectId,
    required this.bibleId,
    this.sectionContentJson,
    required this.onChanged,
  });

  Map<String, dynamic> _getCustom() {
    if (sectionContentJson == null || sectionContentJson!.isEmpty) return {};
    try {
      final decoded = jsonDecode(sectionContentJson!);
      if (decoded is! Map<String, dynamic>) return {};
      final valuesRaw = decoded['values'] ?? decoded['_values'];
      if (valuesRaw is Map) {
        final vals = Map<String, dynamic>.from(valuesRaw);
        if (vals['lightingData'] is String) {
          final parsed = jsonDecode(vals['lightingData'] as String);
          if (parsed is Map<String, dynamic>) return parsed;
        }
        return vals;
      }
    } catch (_) {}
    return {};
  }

  Future<void> _updateCustom(
    WidgetRef ref,
    Map<String, dynamic> update,
  ) async {
    final current = _getCustom();
    final newData = {...current, ...update};
    final db = ref.read(databaseProvider);
    final def = await (db.select(db.bibleSectionDefinitions)
          ..where(
            (d) =>
                d.bibleId.equals(data.id) &
                d.id.equals(BibleSectionId.lighting),
          ))
        .getSingleOrNull();
    if (def == null) return;
    final fields = BibleSectionFieldsConfig.parse(
      def.contentJson,
      BibleSectionId.lighting,
    );
    final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
    values['lightingData'] = jsonEncode(newData);
    await db.upsertBibleSectionDefinition(
      def.copyWith(
        contentJson: drift.Value(
          BibleSectionFieldsConfig.encode(fields, values: values),
        ),
      ),
    );
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final custom = _getCustom();

    final heroBadge = custom['heroBadge'] as String? ??
        'SCENE • LIGHTING ANALYSIS';
    final heroTitle = custom['heroTitle'] as String? ??
        'Estrategia de Iluminación';
    final heroSubtitle = custom['heroSubtitle'] as String? ??
        data.contrastStyle ??
        'El Dualismo de la Sombra';

    final visualIntent = custom['visualIntent'] as String? ??
        data.lightingPhilosophy ??
        data.lightingNarrativeIntent ??
        '';

    final colorTemp = (custom['colorTemp'] as num?)?.toInt() ??
        int.tryParse(
          RegExp(r'(\d+)').firstMatch(data.lightSource ?? '')?.group(1) ?? '',
        ) ??
        5600;
    final tintStr = custom['tint'] as String? ?? '+0.00 G';
    final tintVal = (custom['tintValue'] as num?)?.toDouble() ??
        _parseTint(tintStr);
    final contrastRatio = custom['contrastRatio'] as String? ??
        data.keyFillRatioNight ??
        data.keyFillRatioDay ??
        '8:1';
    final contrastNum = (custom['contrastNum'] as num?)?.toInt() ??
        _parseContrast(contrastRatio);
    final blackIre = (custom['blackLevelIre'] as num?)?.toInt() ?? 0;
    final crushedBlacks = custom['crushedBlacks'] as bool? ?? true;

    var fixtures = _fixtureList(custom['activeFixtures']);
    if (fixtures.isEmpty) {
      fixtures = _fixtureList(custom['equipmentManifest']);
    }
    if (fixtures.isEmpty) {
      fixtures = [
        {'id': 'L1', 'name': 'HMI Par', 'role': 'Key', 'intensity': 100},
        {
          'id': 'L2',
          'name': 'LED Tube',
          'role': 'Practical',
          'intensity': 30,
        },
        {'id': 'L3', 'name': 'Fresnel', 'role': 'Edge', 'intensity': 85},
      ];
    }

    final fixtureTypes = (custom['fixtureTypes'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
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
          'tag': data.lightQuality ?? 'Hard Light',
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

    return BibleSectionScaffold(
      sectionId: BibleSectionId.lighting,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Por qué iluminamos así? Qué emoción transmite esta filosofía de luz…',
      sectionNumber: null,
      sectionTitle: 'Iluminación',
      fieldWidgets: {
        'narrative': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BibleCrossNavChips.techTriplet(current: BibleSectionId.lighting),
            const SizedBox(height: 12),
            _HeroBanner(
          projectId: projectId,
          bibleId: bibleId,
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
            await _updateCustom(ref, {'heroBadge': v});
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
            await _updateCustom(ref, {
              'heroTitle': t.text.trim(),
              'heroSubtitle': s.text.trim(),
            });
            if (s.text.trim().isNotEmpty) {
              data.contrastStyle = s.text.trim();
              onChanged(data);
            }
          },
        ),
          ],
        ),
        'philosophy': LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;

            final intentCol = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHead(
                  icon: Icons.analytics_outlined,
                  label: 'Visual Intent & Concept',
                  palette: palette,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final v = await _prompt(
                      context,
                      'Intención visual',
                      TextEditingController(text: visualIntent),
                      maxLines: 8,
                    );
                    if (v == null) return;
                    await _updateCustom(ref, {'visualIntent': v});
                    data.lightingPhilosophy = v;
                    data.lightingNarrativeIntent = v;
                    onChanged(data);
                  },
                  child: Text(
                    visualIntent.isEmpty
                        ? 'Toca para definir la filosofía de luz…'
                        : visualIntent,
                    style: AppTypography.bodyMedium(palette).copyWith(
                      fontSize: 16,
                      height: 1.6,
                      color: visualIntent.isEmpty
                          ? palette.textTertiary
                          : palette.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                _SectionHead(
                  icon: Icons.grid_on_outlined,
                  label: '// Atmospheric Texture Analysis',
                  palette: palette,
                  accent: true,
                ),
                const SizedBox(height: 16),
                _AtmosphericMosaic(
                  projectId: projectId,
                  bibleId: bibleId,
                  behaviors: behaviors,
                  contrastRatio: contrastRatio,
                  colorTemp: colorTemp,
                  tintStr: tintStr,
                  palette: palette,
                  onEditCard: (i) async {
                    final card = behaviors[i];
                    final title = TextEditingController(text: card['title']);
                    final meta = TextEditingController(text: card['meta']);
                    final tag = TextEditingController(text: card['tag']);
                    final note = TextEditingController(text: card['note']);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Tarjeta ${i + 1}'),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: title,
                                decoration:
                                    const InputDecoration(labelText: 'Título'),
                              ),
                              TextField(
                                controller: meta,
                                decoration:
                                    const InputDecoration(labelText: 'Meta'),
                              ),
                              TextField(
                                controller: tag,
                                decoration:
                                    const InputDecoration(labelText: 'Tag'),
                              ),
                              TextField(
                                controller: note,
                                maxLines: 3,
                                decoration:
                                    const InputDecoration(labelText: 'Nota'),
                              ),
                            ],
                          ),
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
                    if (ok != true) return;
                    final next = [...behaviors];
                    next[i] = {
                      'title': title.text.trim(),
                      'meta': meta.text.trim(),
                      'tag': tag.text.trim(),
                      'note': note.text.trim(),
                    };
                    await _updateCustom(ref, {'behaviorCards': next});
                  },
                ),
                const SizedBox(height: 24),
                _GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GAFFER DIRECTIVES',
                        style: AppTypography.mono(palette).copyWith(
                          fontSize: 11,
                          letterSpacing: 1.4,
                          color: palette.accent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () async {
                          final v = await _prompt(
                            context,
                            'Directivas gaffer',
                            TextEditingController(text: gafferDirectives),
                            maxLines: 4,
                          );
                          if (v == null) return;
                          await _updateCustom(
                            ref,
                            {'gafferDirectives': v},
                          );
                        },
                        child: Text(
                          gafferDirectives.isEmpty
                              ? 'Toca para añadir notas al gaffer…'
                              : gafferDirectives,
                          style: AppTypography.bodyMedium(palette).copyWith(
                            color: gafferDirectives.isEmpty
                                ? palette.textTertiary
                                : palette.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final metricsCol = _TelemetryPanel(
              colorTemp: colorTemp,
              tintVal: tintVal,
              tintStr: tintStr,
              contrastNum: contrastNum,
              contrastRatio: contrastRatio,
              blackIre: blackIre,
              crushedBlacks: crushedBlacks,
              fixtures: fixtures,
              fixtureTypes: fixtureTypes,
              palette: palette,
              onColorTemp: (v) async {
                await _updateCustom(ref, {
                  'colorTemp': v.round(),
                  'contrastRatio': contrastRatio,
                });
                data.lightSource = '${v.round()}K';
                onChanged(data);
              },
              onTint: (v) async {
                final sign = v >= 0 ? '+' : '';
                final s = '$sign${v.toStringAsFixed(2)} G';
                await _updateCustom(ref, {
                  'tintValue': v,
                  'tint': s,
                });
              },
              onContrast: (v) async {
                final r = '${v.round()}:1';
                await _updateCustom(ref, {
                  'contrastNum': v.round(),
                  'contrastRatio': r,
                });
                data.keyFillRatioNight = r;
                onChanged(data);
              },
              onBlackIre: (v) async {
                await _updateCustom(ref, {'blackLevelIre': v.round()});
              },
              onToggleCrush: () async {
                await _updateCustom(
                  ref,
                  {'crushedBlacks': !crushedBlacks},
                );
              },
              onEditFixture: (i) async {
                final f = fixtures[i];
                final name = TextEditingController(
                  text: f['name']?.toString() ?? '',
                );
                final role = TextEditingController(
                  text: f['role']?.toString() ?? '',
                );
                final inten = TextEditingController(
                  text: '${f['intensity'] ?? 100}',
                );
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(f['id']?.toString() ?? 'Fixture'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: name,
                          decoration:
                              const InputDecoration(labelText: 'Modelo'),
                        ),
                        TextField(
                          controller: role,
                          decoration: const InputDecoration(labelText: 'Rol'),
                        ),
                        TextField(
                          controller: inten,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Intensidad %',
                          ),
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
                if (ok != true) return;
                final next = [...fixtures];
                next[i] = {
                  ...f,
                  'name': name.text.trim(),
                  'role': role.text.trim(),
                  'intensity': int.tryParse(inten.text.trim()) ?? 100,
                };
                await _updateCustom(ref, {'activeFixtures': next});
              },
              onAddFixture: () async {
                final next = [
                  ...fixtures,
                  {
                    'id': 'L${fixtures.length + 1}',
                    'name': 'LED Panel',
                    'role': 'Fill',
                    'intensity': 50,
                  },
                ];
                await _updateCustom(ref, {'activeFixtures': next});
              },
              onEditTypes: () async {
                final c = TextEditingController(
                  text: fixtureTypes.join(', '),
                );
                final v = await _prompt(
                  context,
                  'Tipos de fixture (coma)',
                  c,
                );
                if (v == null) return;
                await _updateCustom(ref, {
                  'fixtureTypes': v
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                });
              },
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 8, child: intentCol),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: metricsCol),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                intentCol,
                const SizedBox(height: 24),
                metricsCol,
              ],
            );
          },
        ),
        'miredConverter': _MiredPanel(
          sourceK: sourceK,
          targetK: targetK,
          palette: palette,
          onSource: (v) => _updateCustom(ref, {'sourceKelvin': v.round()}),
          onTarget: (v) async {
            await _updateCustom(ref, {
              'targetKelvin': v.round(),
              'colorTemp': v.round(),
            });
          },
        ),
        'diagrams': _SetupsBlock(
          bibleId: bibleId,
          db: db,
          palette: palette,
          onAdd: () => _addSetup(context, ref),
        ),
      },
    );
  }

  Future<void> _addSetup(BuildContext context, WidgetRef ref) async {
    final palette = context.palette;
    final nameCtrl = TextEditingController();
    final narrativeCtrl = TextEditingController();
    final practicalCtrl = TextEditingController();

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
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    await ref.read(databaseProvider).insertLightingSetup(
                          LightingSetupsCompanion.insert(
                            bibleId: bibleId,
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
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: maxLines,
        ),
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
                            style: AppTypography.displayMedium(palette).copyWith(
                              fontSize: 36,
                              height: 1.15,
                              letterSpacing: -0.8,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: subtitle,
                            style: AppTypography.displayMedium(palette).copyWith(
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
                            imagePath:
                                imgs.length > 1 ? imgs[1].imagePath : null,
                            tall: false,
                            showTech: false,
                            contrastRatio: contrastRatio,
                            palette: palette,
                            onTap: () => onEditCard(
                              behaviors.length > 1 ? 1 : 0,
                            ),
                            onAddImage: () => MoodboardHelpers.addManualImages(
                              db: db,
                              projectId: projectId,
                              bibleId: bibleId,
                              category: MoodboardCategory.lighting,
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
                            imagePath:
                                imgs.length > 2 ? imgs[2].imagePath : null,
                            tall: false,
                            showTech: false,
                            contrastRatio: contrastRatio,
                            palette: palette,
                            onTap: () => onEditCard(
                              behaviors.length > 2 ? 2 : 0,
                            ),
                            onAddImage: () => MoodboardHelpers.addManualImages(
                              db: db,
                              projectId: projectId,
                              bibleId: bibleId,
                              category: MoodboardCategory.lighting,
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
    final hasImg =
        imagePath != null && File(imagePath!).existsSync();
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
                  colors: [
                    Colors.transparent,
                    Color(0xE60D0D0D),
                  ],
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
        style: AppTypography.mono(palette).copyWith(
          fontSize: 10,
          color: palette.accent.withValues(alpha: 0.85),
        ),
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
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 10,
                  color: palette.textTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),
          Text(
            'ACTIVE FIXTURES',
            style: AppTypography.mono(palette).copyWith(
              fontSize: 10,
              letterSpacing: 1.4,
              color: palette.accent,
            ),
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
                        style: AppTypography.mono(palette).copyWith(
                          fontSize: 11,
                          color: Colors.white,
                        ),
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
          style: AppTypography.mono(palette).copyWith(
            fontSize: 12,
            color: Colors.white,
          ),
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
            gel == null
                ? 'Sin corrección de gel recomendada'
                : gel.description,
            style: AppTypography.mono(palette).copyWith(
              fontSize: 12,
              color: gel == null ? palette.textTertiary : palette.accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ΔMired '
            '${(MiredConverter.kelvinToMired(sourceK) - MiredConverter.kelvinToMired(targetK)).toStringAsFixed(1)}',
            style: AppTypography.mono(palette).copyWith(
              fontSize: 11,
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Setups ──────────────────────────────────────────────────────────────────

class _SetupsBlock extends StatelessWidget {
  final int bibleId;
  final AppDatabase db;
  final AppPalette palette;
  final VoidCallback onAdd;

  const _SetupsBlock({
    required this.bibleId,
    required this.db,
    required this.palette,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
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
            final setups = snap.data ?? [];
            if (setups.isEmpty) {
              return _GlassPanel(
                child: Text(
                  'Sin setups. Crea uno para diagramar key/fill y motivación práctica.',
                  style: AppTypography.bodyMedium(palette).copyWith(
                    color: palette.textTertiary,
                  ),
                ),
              );
            }
            return Column(
              children: setups.map((row) {
                final setup = LightingSetupModel.fromRow(row);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _GlassPanel(
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
                                    Text(
                                      setup.setupName,
                                      style: AppTypography.titleMedium(palette)
                                          .copyWith(fontSize: 18),
                                    ),
                                    if (setup.narrativeNote?.isNotEmpty ==
                                        true) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        setup.narrativeNote!,
                                        style: AppTypography.bodyMedium(palette)
                                            .copyWith(
                                          color: palette.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                    if (setup.practicalMotivation
                                            ?.isNotEmpty ==
                                        true) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'MOTIVACIÓN: ${setup.practicalMotivation}',
                                        style: AppTypography.mono(palette)
                                            .copyWith(
                                          fontSize: 11,
                                          color: palette.accent,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: palette.error,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    db.deleteLightingSetup(setup.id),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 280,
                          child: LightingDiagramEditor(
                            initialJson: setup.diagramJson,
                            onChanged: (json) async {
                              await db.updateLightingSetup(
                                row.copyWith(diagramJson: json),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
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
