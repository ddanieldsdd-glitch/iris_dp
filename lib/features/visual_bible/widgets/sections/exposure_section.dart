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
import '../../v2/model/bible_json_parse.dart';
import '../../moodboard_helpers.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_moodboard_image_target.dart';
import '../bible_navigation_scope.dart';
import '../block_reference_images.dart';
import 'section_scaffold.dart';

/// Exposición — layout Stitch (specs + pipeline + frame + slots por set).
class ExposureSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final int bibleId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const ExposureSection({
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
        if (vals['exposureData'] is String) {
          final parsed = jsonDecode(vals['exposureData'] as String);
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
                d.id.equals(BibleSectionId.exposure),
          ))
        .getSingleOrNull();
    if (def == null) return;
    final fields = BibleSectionFieldsConfig.parse(
      def.contentJson,
      BibleSectionId.exposure,
    );
    final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
    values['exposureData'] = jsonEncode(newData);
    await db.upsertBibleSectionDefinition(
      def.copyWith(
        contentJson: drift.Value(
          BibleSectionFieldsConfig.encode(fields, values: values),
        ),
      ),
    );
  }

  Future<void> _updateLocationSlot(
    WidgetRef ref,
    int planId,
    Map<String, dynamic> patch,
  ) async {
    final current = _getCustom();
    final byLoc = Map<String, dynamic>.from(
      (current['byLocation'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v),
          ) ??
          {},
    );
    final slot = Map<String, dynamic>.from(
      (byLoc['$planId'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v),
          ) ??
          {},
    );
    slot.addAll(patch);
    byLoc['$planId'] = slot;
    await _updateCustom(ref, {'byLocation': byLoc});
  }

  Map<String, dynamic> _slotFor(Map<String, dynamic> custom, int planId) {
    final byLoc = custom['byLocation'];
    if (byLoc is! Map) return {};
    final raw = byLoc['$planId'] ?? byLoc[planId];
    if (raw is Map) {
      return Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return {};
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final custom = _getCustom();

    final sceneBadge = bibleJsonString(custom['sceneBadge']) ??
        'SCENE • EXPOSURE STRATEGY';
    final baseIso = data.nativeIso ??
        bibleJsonInt(custom['baseIso']) ??
        800;
    final tStop = data.defaultTStop ??
        bibleJsonString(custom['targetTStop']) ??
        'T2.8';
    final shutter = bibleJsonDouble(custom['shutterAngle']) ?? 180.0;
    final ndFilter = bibleJsonString(custom['ndFilter']) ??
        (data.ndNotes?.isNotEmpty == true ? data.ndNotes! : 'Clear');
    final exposureIndex =
        bibleJsonDouble(custom['exposureIndex']) ?? baseIso.toDouble();

    final sourceIntensity =
        bibleJsonString(custom['sourceIntensity']) ?? 'Harsh Daylight';
    final sensorSensitivity =
        bibleJsonString(custom['sensorSensitivity']) ?? 'EI $baseIso';
    final opticsLimit =
        bibleJsonString(custom['opticsLimit']) ?? 'Wide Open $tStop';

    final crush = bibleJsonDouble(custom['lumaCrush']) ?? 8.0;
    final peak = bibleJsonDouble(custom['lumaPeak']) ?? 92.0;

    final narrativeIntent = bibleJsonString(custom['narrativeIntent']) ??
        data.exposureNarrativeIntent ??
        '';
    final tags = (custom['intentTags'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const ['LOW-KEY', 'HIGH CONTRAST', 'SHADOW DETAIL CRITICAL'];

    return BibleSectionScaffold(
      sectionId: BibleSectionId.exposure,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Protegemos highlights o dejamos quemar? ¿Por qué? Cómo la exposición refuerza la narrativa…',
      sectionNumber: null,
      sectionTitle: 'Exposición',
      fieldWidgets: {
        'narrative': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BibleCrossNavChips.techTriplet(current: BibleSectionId.exposure),
            const SizedBox(height: 12),
            _ExposureHeader(
              badge: sceneBadge,
              palette: palette,
              onEditBadge: () async {
                final v = await _prompt(
                  context,
                  'Badge de escena',
                  TextEditingController(text: sceneBadge),
                );
                if (v == null) return;
                await _updateCustom(ref, {'sceneBadge': v});
              },
            ),
          ],
        ),
        'globalExposure': LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;

            final specsCard = _GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune, size: 16, color: palette.accent),
                      const SizedBox(width: 8),
                      Text(
                        'PRIMARY SPECS',
                        style: AppTypography.label(palette).copyWith(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _SpecScrubber(
                          label: 'BASE ISO',
                          value: '$baseIso',
                          palette: palette,
                          onDrag: (dx) {
                            final next =
                                (baseIso + (dx / 3).round()).clamp(100, 12800);
                            data.nativeIso = next;
                            onChanged(data);
                            _updateCustom(ref, {
                              'baseIso': next,
                              'exposureIndex':
                                  bibleJsonDouble(custom['exposureIndex']) ??
                                      next.toDouble(),
                            });
                          },
                          onTap: () async {
                            final c = TextEditingController(text: '$baseIso');
                            final v = await _prompt(context, 'Base ISO', c);
                            final n = int.tryParse(
                              v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '',
                            );
                            if (n == null) return;
                            data.nativeIso = n;
                            onChanged(data);
                            await _updateCustom(ref, {'baseIso': n});
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SpecScrubber(
                          label: 'TARGET T-STOP',
                          value: tStop,
                          palette: palette,
                          accent: true,
                          onDrag: (dx) {
                            final next = _nudgeTStop(tStop, dx);
                            data.defaultTStop = next;
                            onChanged(data);
                            _updateCustom(ref, {'targetTStop': next});
                          },
                          onTap: () async {
                            final c = TextEditingController(text: tStop);
                            final v =
                                await _prompt(context, 'Target T-Stop', c);
                            if (v == null || v.isEmpty) return;
                            data.defaultTStop = v;
                            onChanged(data);
                            await _updateCustom(ref, {'targetTStop': v});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _SpecScrubber(
                          label: 'SHUTTER ANGLE',
                          value: '${shutter.round()}°',
                          palette: palette,
                          onDrag: (dx) {
                            final next = (shutter + dx / 2)
                                .clamp(11.25, 360.0)
                                .toDouble();
                            _updateCustom(ref, {
                              'shutterAngle': double.parse(
                                next.toStringAsFixed(1),
                              ),
                            });
                          },
                          onTap: () async {
                            final c = TextEditingController(
                              text: '${shutter.round()}',
                            );
                            final v =
                                await _prompt(context, 'Shutter Angle', c);
                            final n = double.tryParse(
                              v?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
                            );
                            if (n == null) return;
                            await _updateCustom(ref, {
                              'shutterAngle': n.clamp(11.25, 360.0),
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SpecScrubber(
                          label: 'ND FILTER',
                          value: ndFilter,
                          palette: palette,
                          onDrag: (dx) {
                            final next = _nudgeNd(ndFilter, dx);
                            data.ndNotes = next;
                            onChanged(data);
                            _updateCustom(ref, {'ndFilter': next});
                          },
                          onTap: () async {
                            final c = TextEditingController(text: ndFilter);
                            final v = await _prompt(context, 'ND Filter', c);
                            if (v == null || v.isEmpty) return;
                            data.ndNotes = v;
                            onChanged(data);
                            await _updateCustom(ref, {'ndFilter': v});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _ExposureIndexBar(
                    baseIso: baseIso.toDouble(),
                    exposureIndex: exposureIndex,
                    palette: palette,
                    onChanged: (v) =>
                        _updateCustom(ref, {'exposureIndex': v}),
                  ),
                ],
              ),
            );

            final pipelineCard = _GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_tree_outlined,
                          size: 16, color: palette.textTertiary),
                      const SizedBox(width: 8),
                      Text(
                        'EXPOSURE PIPELINE',
                        style: AppTypography.label(palette).copyWith(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PipelineStep(
                    step: '01',
                    title: 'SOURCE INTENSITY',
                    value: sourceIntensity,
                    palette: palette,
                    onTap: () async {
                      final v = await _prompt(
                        context,
                        'Source Intensity',
                        TextEditingController(text: sourceIntensity),
                      );
                      if (v == null) return;
                      await _updateCustom(ref, {'sourceIntensity': v});
                    },
                  ),
                  _PipelineArrow(palette: palette),
                  _PipelineStep(
                    step: '02',
                    title: 'SENSOR SENSITIVITY',
                    value: sensorSensitivity,
                    palette: palette,
                    accent: true,
                    onTap: () async {
                      final v = await _prompt(
                        context,
                        'Sensor Sensitivity',
                        TextEditingController(text: sensorSensitivity),
                      );
                      if (v == null) return;
                      await _updateCustom(ref, {'sensorSensitivity': v});
                    },
                  ),
                  _PipelineArrow(palette: palette),
                  _PipelineStep(
                    step: '03',
                    title: 'OPTICS LIMIT',
                    value: opticsLimit,
                    palette: palette,
                    onTap: () async {
                      final v = await _prompt(
                        context,
                        'Optics Limit',
                        TextEditingController(text: opticsLimit),
                      );
                      if (v == null) return;
                      await _updateCustom(ref, {'opticsLimit': v});
                    },
                  ),
                ],
              ),
            );

            final preview = _ExposureFramePreview(
              projectId: projectId,
              bibleId: bibleId,
              crush: crush,
              peak: peak,
              palette: palette,
              onEditCrushPeak: () async {
                final cCrush = TextEditingController(
                  text: crush.toStringAsFixed(0),
                );
                final cPeak = TextEditingController(
                  text: peak.toStringAsFixed(0),
                );
                final ok = await _promptPair(
                  context,
                  'Luma Waveform',
                  cCrush,
                  cPeak,
                  aLabel: 'Crush %',
                  bLabel: 'Peak %',
                );
                if (ok != true) return;
                final crushN = double.tryParse(cCrush.text) ?? crush;
                final peakN = double.tryParse(cPeak.text) ?? peak;
                await _updateCustom(ref, {
                  'lumaCrush': crushN.clamp(0, 40),
                  'lumaPeak': peakN.clamp(60, 100),
                });
              },
            );

            final intentCard = _GlassPanel(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note,
                          size: 16, color: palette.textTertiary),
                      const SizedBox(width: 8),
                      Text(
                        'NARRATIVE INTENT',
                        style: AppTypography.label(palette).copyWith(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () async {
                      final v = await _prompt(
                        context,
                        'Intención narrativa',
                        TextEditingController(text: narrativeIntent),
                        maxLines: 6,
                      );
                      if (v == null) return;
                      await _updateCustom(ref, {'narrativeIntent': v});
                      data.exposureNarrativeIntent = v;
                      onChanged(data);
                    },
                    child: Text(
                      narrativeIntent.isEmpty
                          ? 'Toca para definir cómo la exposición refuerza la narrativa…'
                          : narrativeIntent,
                      style: AppTypography.bodyMedium(palette).copyWith(
                        fontSize: 15,
                        height: 1.55,
                        color: narrativeIntent.isEmpty
                            ? palette.textTertiary
                            : palette.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in const [
                        'LOW-KEY',
                        'HIGH CONTRAST',
                        'SHADOW DETAIL CRITICAL',
                      ])
                        _IntentTag(
                          label: tag,
                          active: tags.contains(tag),
                          palette: palette,
                          onTap: () async {
                            final next = [...tags];
                            if (next.contains(tag)) {
                              next.remove(tag);
                            } else {
                              next.add(tag);
                            }
                            await _updateCustom(ref, {'intentTags': next});
                          },
                        ),
                    ],
                  ),
                ],
              ),
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        specsCard,
                        const SizedBox(height: 16),
                        pipelineCard,
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        preview,
                        const SizedBox(height: 16),
                        intentCard,
                      ],
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                specsCard,
                const SizedBox(height: 16),
                preview,
                const SizedBox(height: 16),
                pipelineCard,
                const SizedBox(height: 16),
                intentCard,
              ],
            );
          },
        ),
        'blocks': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LocationExposureSlots(
              projectId: projectId,
              bibleId: bibleId,
              data: data,
              custom: custom,
              palette: palette,
              slotFor: (id) => _slotFor(custom, id),
              onPatch: (planId, patch) =>
                  _updateLocationSlot(ref, planId, patch),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Text(
                  'EXPOSURE BLOCKS',
                  style: AppTypography.mono(palette).copyWith(
                    fontSize: 12,
                    letterSpacing: 1.4,
                    color: palette.textTertiary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _addBlock(context, ref),
                  icon: Icon(Icons.add, color: palette.accent, size: 18),
                  label: Text(
                    'Añadir bloque',
                    style: TextStyle(color: palette.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<ExposureBlock>>(
              stream: db.watchExposureBlocksForBible(bibleId),
              builder: (context, snap) {
                final blocks = snap.data ?? [];
                if (blocks.isEmpty) {
                  return _GlassPanel(
                    child: Text(
                      'Sin bloques narrativos. Añade uno para documentar highlight/shadow strategy por acto o secuencia.',
                      style: AppTypography.bodyMedium(palette).copyWith(
                        color: palette.textTertiary,
                      ),
                    ),
                  );
                }
                return Column(
                  children: blocks.map((row) {
                    final block = ExposureBlockModel.fromRow(row);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final c = TextEditingController(
                                        text: block.blockName,
                                      );
                                      final v = await _prompt(
                                        context,
                                        'Nombre del bloque',
                                        c,
                                      );
                                      if (v == null || v.isEmpty) return;
                                      await db.updateExposureBlock(
                                        row.copyWith(blockName: v),
                                      );
                                    },
                                    child: Text(
                                      block.blockName,
                                      style:
                                          AppTypography.titleMedium(palette),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: palette.error,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      db.deleteExposureBlock(block.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final c = TextEditingController(
                                  text: block.narrativeIntent ?? '',
                                );
                                final v = await _prompt(
                                  context,
                                  'Intención narrativa',
                                  c,
                                  maxLines: 3,
                                );
                                if (v == null) return;
                                await db.updateExposureBlock(
                                  row.copyWith(
                                    narrativeIntent: drift.Value(
                                      v.isEmpty ? null : v,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                (block.narrativeIntent?.isNotEmpty == true)
                                    ? block.narrativeIntent!
                                    : 'Toca para añadir intención…',
                                style:
                                    AppTypography.bodyMedium(palette).copyWith(
                                  color: (block.narrativeIntent?.isNotEmpty ==
                                          true)
                                      ? palette.textSecondary
                                      : palette.textTertiary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MetaChip(
                                  label: 'K:F',
                                  value: block.keyFillRatio ?? '—',
                                  palette: palette,
                                  onTap: () async {
                                    final c = TextEditingController(
                                      text: block.keyFillRatio ?? '',
                                    );
                                    final v =
                                        await _prompt(context, 'Ratio K:F', c);
                                    if (v == null) return;
                                    await db.updateExposureBlock(
                                      row.copyWith(
                                        keyFillRatio: drift.Value(
                                          v.isEmpty ? null : v,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _MetaChip(
                                  label: 'HIGHLIGHTS',
                                  value: block.highlightStrategy ?? '—',
                                  palette: palette,
                                  onTap: () async {
                                    final c = TextEditingController(
                                      text: block.highlightStrategy ?? '',
                                    );
                                    final v = await _prompt(
                                      context,
                                      'Highlight strategy',
                                      c,
                                    );
                                    if (v == null) return;
                                    await db.updateExposureBlock(
                                      row.copyWith(
                                        highlightStrategy: drift.Value(
                                          v.isEmpty ? null : v,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _MetaChip(
                                  label: 'SHADOWS',
                                  value: block.shadowStrategy ?? '—',
                                  palette: palette,
                                  onTap: () async {
                                    final c = TextEditingController(
                                      text: block.shadowStrategy ?? '',
                                    );
                                    final v = await _prompt(
                                      context,
                                      'Shadow strategy',
                                      c,
                                    );
                                    if (v == null) return;
                                    await db.updateExposureBlock(
                                      row.copyWith(
                                        shadowStrategy: drift.Value(
                                          v.isEmpty ? null : v,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            blockReferenceImagesRow(
                              projectId: projectId,
                              paths: block.referenceImages,
                              onSaved: (path) async {
                                block.referenceImages.add(path);
                                await db.updateExposureBlock(
                                  row.copyWith(
                                    referenceImages: drift.Value(
                                      jsonEncode(block.referenceImages),
                                    ),
                                  ),
                                );
                              },
                              onAdd: () async {
                                await pickBlockReferenceImage(
                                  projectId: projectId,
                                  onSaved: (path) async {
                                    block.referenceImages.add(path);
                                    await db.updateExposureBlock(
                                      row.copyWith(
                                        referenceImages: drift.Value(
                                          jsonEncode(block.referenceImages),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
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
        ),
      },
    );
  }

  Future<void> _addBlock(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final intentCtrl = TextEditingController();
    final ratioCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo bloque de exposición'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BibleTextField(
                label: 'Nombre',
                hint: 'Acto I',
                controller: nameCtrl,
                onChanged: (_) {},
              ),
              BibleTextField(
                label: 'Intención narrativa',
                hint: 'Sombras abiertas para vulnerabilidad…',
                maxLines: 2,
                controller: intentCtrl,
                onChanged: (_) {},
              ),
              BibleTextField(
                label: 'Ratio K:F',
                hint: '3:1',
                controller: ratioCtrl,
                onChanged: (_) {},
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
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    await ref.read(databaseProvider).insertExposureBlock(
          ExposureBlocksCompanion.insert(
            bibleId: bibleId,
            blockName: name,
            narrativeIntent: drift.Value(
              intentCtrl.text.trim().isEmpty ? null : intentCtrl.text.trim(),
            ),
            keyFillRatio: drift.Value(
              ratioCtrl.text.trim().isEmpty ? null : ratioCtrl.text.trim(),
            ),
          ),
        );
  }

  static const _tStops = [
    'T1.3',
    'T1.4',
    'T1.5',
    'T2',
    'T2.8',
    'T4',
    'T5.6',
    'T8',
    'T11',
    'T16',
  ];

  static const _ndSteps = [
    'Clear',
    '0.3',
    '0.6',
    '0.9',
    '1.2',
    '1.5',
    '1.8',
    '2.1',
  ];

  static String _nudgeTStop(String current, double dx) {
    var i = _tStops.indexWhere(
      (t) => t.toLowerCase() == current.toLowerCase(),
    );
    if (i < 0) i = 4;
    if (dx.abs() < 8) return current;
    final next = (i + (dx > 0 ? 1 : -1)).clamp(0, _tStops.length - 1);
    return _tStops[next];
  }

  static String _nudgeNd(String current, double dx) {
    var i = _ndSteps.indexWhere(
      (n) => n.toLowerCase() == current.toLowerCase(),
    );
    if (i < 0) i = 0;
    if (dx.abs() < 8) return current;
    final next = (i + (dx > 0 ? 1 : -1)).clamp(0, _ndSteps.length - 1);
    return _ndSteps[next];
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
    String aLabel = 'A',
    String bLabel = 'B',
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

// ─── Header ──────────────────────────────────────────────────────────────────

class _ExposureHeader extends StatelessWidget {
  final String badge;
  final AppPalette palette;
  final VoidCallback onEditBadge;

  const _ExposureHeader({
    required this.badge,
    required this.palette,
    required this.onEditBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '05 EXPOSICIÓN',
          style: AppTypography.displayMedium(palette).copyWith(
            fontSize: 32,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: onEditBadge,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surfaceElevated,
              borderRadius: BorderRadius.circular(999),
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
                    letterSpacing: 1.3,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.edit, size: 12, color: palette.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Location slots ──────────────────────────────────────────────────────────

class _LocationExposureSlots extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final VisualBibleData data;
  final Map<String, dynamic> custom;
  final AppPalette palette;
  final Map<String, dynamic> Function(int planId) slotFor;
  final Future<void> Function(int planId, Map<String, dynamic> patch) onPatch;

  const _LocationExposureSlots({
    required this.projectId,
    required this.bibleId,
    required this.data,
    required this.custom,
    required this.palette,
    required this.slotFor,
    required this.onPatch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'EXPOSURE BY LOCATION',
              style: AppTypography.mono(palette).copyWith(
                fontSize: 12,
                letterSpacing: 1.4,
                color: palette.textTertiary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => BibleNavigationScope.openLocationSet(context),
              icon: Icon(Icons.place_outlined, size: 16, color: palette.accent),
              label: Text(
                'Localizaciones',
                style: TextStyle(color: palette.accent),
              ),
            ),
            TextButton.icon(
              onPressed: () => BibleNavigationScope.openMoodboardForSection(
                context,
                BibleSectionId.exposure,
              ),
              icon: Icon(
                Icons.photo_library_outlined,
                size: 16,
                color: palette.accent,
              ),
              label: Text(
                'Moodboard',
                style: TextStyle(color: palette.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<LocationBasePlan>>(
          stream: db.watchLocationsForProject(projectId),
          builder: (context, locSnap) {
            final plans = locSnap.data ?? [];
            if (plans.isEmpty) {
              return _GlassPanel(
                child: Text(
                  'Sin sets en el proyecto. Importa el guion o abre Localizaciones para crearlos.',
                  style: AppTypography.bodyMedium(palette).copyWith(
                    color: palette.textTertiary,
                  ),
                ),
              );
            }

            return StreamBuilder<List<VisualBibleLocationRef>>(
              stream: db.watchLocationRefsForBible(bibleId),
              builder: (context, refSnap) {
                final refsByPlanId = <int, VisualBibleLocationRef>{
                  for (final r in refSnap.data ?? [])
                    if (r.locationBasePlanId != null) r.locationBasePlanId!: r,
                };
                final refsByName = <String, VisualBibleLocationRef>{
                  for (final r in refSnap.data ?? []) r.locationName: r,
                };

                return StreamBuilder<List<LightingSetup>>(
                  stream: db.watchLightingSetupsForBible(bibleId),
                  builder: (context, lightSnap) {
                    final setups = lightSnap.data ?? [];
                    return Column(
                      children: plans.map((plan) {
                        final refRow = refsByPlanId[plan.id] ??
                            refsByName[plan.locationName];
                        final locRef = refRow != null
                            ? LocationRefModel.fromRow(refRow)
                            : LocationRefModel(
                                id: 0,
                                bibleId: bibleId,
                                locationName: plan.locationName,
                                locationBasePlanId: plan.id,
                                locationSiteId: plan.siteId,
                              );
                        final slot = slotFor(plan.id);
                        final lightingHint = _lightingHintForPlan(
                          plan.id,
                          setups,
                          data,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _LocationExposureCard(
                            plan: plan,
                            locRef: locRef,
                            slot: slot,
                            lightingHint: lightingHint,
                            palette: palette,
                            defaults: (
                              iso: data.nativeIso ?? 800,
                              tStop: data.defaultTStop ?? 'T2.8',
                              nd: bibleJsonString(custom['ndFilter']) ??
                                  data.ndNotes ??
                                  'Clear',
                              shutter:
                                  bibleJsonDouble(custom['shutterAngle']) ??
                                      180.0,
                            ),
                            onPatch: (patch) => onPatch(plan.id, patch),
                            onOpenSet: () =>
                                BibleNavigationScope.openLocationSet(
                              context,
                              setId: plan.id,
                              siteId: plan.siteId,
                            ),
                            onOpenMoodboard: () =>
                                BibleNavigationScope.openMoodboardForSection(
                              context,
                              BibleSectionId.exposure,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  static String? _lightingHintForPlan(
    int planId,
    List<LightingSetup> setups,
    VisualBibleData data,
  ) {
    for (final s in setups) {
      if (s.locationBasePlanId == planId) {
        final note = s.narrativeNote?.trim();
        if (note != null && note.isNotEmpty) return note;
        return 'Setup: ${s.setupName}';
      }
    }
    return data.lightingPhilosophy ?? data.lightingNarrativeIntent;
  }
}

class _LocationExposureCard extends StatelessWidget {
  final LocationBasePlan plan;
  final LocationRefModel locRef;
  final Map<String, dynamic> slot;
  final String? lightingHint;
  final AppPalette palette;
  final ({int iso, String tStop, String nd, double shutter}) defaults;
  final Future<void> Function(Map<String, dynamic> patch) onPatch;
  final VoidCallback onOpenSet;
  final VoidCallback onOpenMoodboard;

  const _LocationExposureCard({
    required this.plan,
    required this.locRef,
    required this.slot,
    required this.lightingHint,
    required this.palette,
    required this.defaults,
    required this.onPatch,
    required this.onOpenSet,
    required this.onOpenMoodboard,
  });

  @override
  Widget build(BuildContext context) {
    final iso = bibleJsonInt(slot['iso']) ?? defaults.iso;
    final tStop = bibleJsonString(slot['tStop']) ?? defaults.tStop;
    final nd = bibleJsonString(slot['nd']) ?? defaults.nd;
    final shutter = bibleJsonDouble(slot['shutter']) ?? defaults.shutter;
    final approach = bibleJsonString(slot['approach']) ?? '';
    final highlight = bibleJsonString(slot['highlightStrategy']) ?? '';
    final shadow = bibleJsonString(slot['shadowStrategy']) ?? '';
    final keyFill = bibleJsonString(slot['keyFill']) ?? '';

    final chips = <(String, String)>[
      if (locRef.solarOrientation?.isNotEmpty == true)
        ('SOLAR', locRef.solarOrientation!),
      if (locRef.availableLightHours?.isNotEmpty == true)
        ('LIGHT HOURS', locRef.availableLightHours!),
      if (locRef.existingPracticals?.isNotEmpty == true)
        ('PRACTICALS', locRef.existingPracticals!),
      if (locRef.lightingNote?.isNotEmpty == true)
        ('LIGHT NOTE', locRef.lightingNote!),
    ];

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.locationName.toUpperCase(),
                  style: AppTypography.mono(palette).copyWith(
                    fontSize: 14,
                    letterSpacing: 1.2,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Abrir set',
                onPressed: onOpenSet,
                icon: Icon(Icons.open_in_new, size: 18, color: palette.accent),
              ),
              IconButton(
                tooltip: 'Moodboard exposición',
                onPressed: onOpenMoodboard,
                icon: Icon(
                  Icons.photo_library_outlined,
                  size: 18,
                  color: palette.accent,
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in chips)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      '${c.$1}: ${c.$2}',
                      style: AppTypography.mono(palette).copyWith(
                        fontSize: 10,
                        letterSpacing: 0.6,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (lightingHint != null && lightingHint!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'LIGHTING SETUP',
              style: AppTypography.mono(palette).copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                color: palette.accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lightingHint!,
              style: AppTypography.bodyMedium(palette).copyWith(
                fontSize: 13,
                color: palette.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _EditableSpec(
                  label: 'ISO',
                  value: '$iso',
                  palette: palette,
                  onTap: () async {
                    final c = TextEditingController(text: '$iso');
                    final v = await ExposureSection._prompt(context, 'ISO', c);
                    final n = int.tryParse(
                      v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '',
                    );
                    if (n == null) return;
                    await onPatch({'iso': n});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _EditableSpec(
                  label: 'T-STOP',
                  value: tStop,
                  palette: palette,
                  onTap: () async {
                    final c = TextEditingController(text: tStop);
                    final v =
                        await ExposureSection._prompt(context, 'T-Stop', c);
                    if (v == null || v.isEmpty) return;
                    await onPatch({'tStop': v});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _EditableSpec(
                  label: 'ND',
                  value: nd,
                  palette: palette,
                  onTap: () async {
                    final c = TextEditingController(text: nd);
                    final v = await ExposureSection._prompt(context, 'ND', c);
                    if (v == null || v.isEmpty) return;
                    await onPatch({'nd': v});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _EditableSpec(
                  label: 'SHUTTER',
                  value: '${shutter.round()}°',
                  palette: palette,
                  onTap: () async {
                    final c = TextEditingController(text: '${shutter.round()}');
                    final v =
                        await ExposureSection._prompt(context, 'Shutter', c);
                    final n = double.tryParse(
                      v?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
                    );
                    if (n == null) return;
                    await onPatch({'shutter': n});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _EditableLine(
            label: 'APPROACH',
            value: approach,
            hint: 'Cómo exponer este set…',
            palette: palette,
            onTap: () async {
              final c = TextEditingController(text: approach);
              final v = await ExposureSection._prompt(
                context,
                'Approach',
                c,
                maxLines: 3,
              );
              if (v == null) return;
              await onPatch({'approach': v});
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _EditableLine(
                  label: 'HIGHLIGHTS',
                  value: highlight,
                  hint: 'Estrategia luces…',
                  palette: palette,
                  onTap: () async {
                    final c = TextEditingController(text: highlight);
                    final v = await ExposureSection._prompt(
                      context,
                      'Highlight strategy',
                      c,
                    );
                    if (v == null) return;
                    await onPatch({'highlightStrategy': v});
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EditableLine(
                  label: 'SHADOWS',
                  value: shadow,
                  hint: 'Estrategia sombras…',
                  palette: palette,
                  onTap: () async {
                    final c = TextEditingController(text: shadow);
                    final v = await ExposureSection._prompt(
                      context,
                      'Shadow strategy',
                      c,
                    );
                    if (v == null) return;
                    await onPatch({'shadowStrategy': v});
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EditableLine(
                  label: 'KEY:FILL',
                  value: keyFill,
                  hint: '3:1',
                  palette: palette,
                  onTap: () async {
                    final c = TextEditingController(text: keyFill);
                    final v = await ExposureSection._prompt(
                      context,
                      'Key:Fill',
                      c,
                    );
                    if (v == null) return;
                    await onPatch({'keyFill': v});
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Frame preview ───────────────────────────────────────────────────────────

class _ExposureFramePreview extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final double crush;
  final double peak;
  final AppPalette palette;
  final VoidCallback onEditCrushPeak;

  const _ExposureFramePreview({
    required this.projectId,
    required this.bibleId,
    required this.crush,
    required this.peak,
    required this.palette,
    required this.onEditCrushPeak,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return _GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1D),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility_outlined,
                    size: 16, color: palette.textTertiary),
                const SizedBox(width: 8),
                Text(
                  'FRAME PREVIEW',
                  style: AppTypography.label(palette).copyWith(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    color: palette.textTertiary,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onEditCrushPeak,
                  child: Text(
                    'LUMA  crush ${crush.round()}% · peak ${peak.round()}%',
                    style: AppTypography.mono(palette).copyWith(
                      fontSize: 10,
                      color: palette.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BibleMoodboardImageTarget(
              projectId: projectId,
              sectionId: BibleSectionId.exposure,
              bibleId: bibleId,
              hint: 'Clic aquí → ⌘V para pegar frame de exposición',
              child: ColoredBox(
              color: Colors.black,
              child: StreamBuilder<List<MoodboardImage>>(
                stream: db.watchMoodboardImagesForSection(
                  projectId,
                  BibleSectionId.exposure,
                ),
                builder: (context, snap) {
                  final imgs = snap.data ?? [];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imgs.isNotEmpty &&
                          File(imgs.first.imagePath).existsSync())
                        Image.file(
                          File(imgs.first.imagePath),
                          fit: BoxFit.cover,
                        )
                      else
                        ColoredBox(
                          color: palette.surfaceOverlay,
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () => MoodboardHelpers.addManualImages(
                                db: db,
                                projectId: projectId,
                                bibleId: bibleId,
                                category: MoodboardCategory.lighting,
                                assignedSections: [BibleSectionId.exposure],
                              ),
                              icon: Icon(
                                Icons.add_photo_alternate_outlined,
                                color: palette.accent,
                              ),
                              label: Text(
                                'Añadir frame',
                                style: TextStyle(color: palette.accent),
                              ),
                            ),
                          ),
                        ),
                      CustomPaint(painter: _ThirdsPainter(palette.accent)),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 36,
                        height: 56,
                        child: InkWell(
                          onTap: onEditCrushPeak,
                          child: CustomPaint(
                            painter: _LumaWavePainter(
                              crush: crush / 100,
                              peak: peak / 100,
                              accent: palette.accent,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFFFB4AB),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'REC',
                              style: AppTypography.mono(palette).copyWith(
                                fontSize: 11,
                                letterSpacing: 1.4,
                                color: const Color(0xFFFFB4AB)
                                    .withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Text(
                          'EXPOSURE MONITOR',
                          style: AppTypography.mono(palette).copyWith(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Small UI atoms ──────────────────────────────────────────────────────────

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

class _SpecScrubber extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final ValueChanged<double> onDrag;
  final VoidCallback onTap;
  final bool accent;

  const _SpecScrubber({
    required this.label,
    required this.value,
    required this.palette,
    required this.onDrag,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: accent
                ? palette.accent.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.mono(palette).copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTypography.mono(palette).copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: accent ? palette.accent : palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '⟷ scrub',
              style: AppTypography.mono(palette).copyWith(
                fontSize: 9,
                color: palette.textTertiary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExposureIndexBar extends StatelessWidget {
  final double baseIso;
  final double exposureIndex;
  final AppPalette palette;
  final ValueChanged<double> onChanged;

  const _ExposureIndexBar({
    required this.baseIso,
    required this.exposureIndex,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final minIso = math.max(100.0, baseIso <= 0 ? 100.0 : baseIso / 4);
    var maxIso = math.min(12800.0, math.max(baseIso, 100.0) * 4);
    if (maxIso <= minIso) maxIso = minIso + 1;
    final value = exposureIndex.clamp(minIso, maxIso);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'EXPOSURE INDEX',
              style: AppTypography.mono(palette).copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                color: palette.textTertiary,
              ),
            ),
            const Spacer(),
            Text(
              'EI ${value.round()}',
              style: AppTypography.mono(palette).copyWith(
                fontSize: 12,
                color: palette.accent,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value,
            min: minIso,
            max: maxIso,
            onChanged: onChanged,
            activeColor: palette.accent,
            inactiveColor: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        Row(
          children: [
            Text(
              'BASE ${baseIso.round()}',
              style: AppTypography.mono(palette).copyWith(
                fontSize: 9,
                color: palette.textTertiary,
              ),
            ),
            const Spacer(),
            Text(
              baseIso <= 0 || value <= 0
                  ? '—'
                  : value > baseIso
                  ? '+${(math.log(value / baseIso) / math.ln2).toStringAsFixed(1)} stop'
                  : value < baseIso
                      ? '${(math.log(value / baseIso) / math.ln2).toStringAsFixed(1)} stop'
                      : '0 stop',
              style: AppTypography.mono(palette).copyWith(
                fontSize: 9,
                color: palette.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PipelineStep extends StatelessWidget {
  final String step;
  final String title;
  final String value;
  final AppPalette palette;
  final VoidCallback onTap;
  final bool accent;

  const _PipelineStep({
    required this.step,
    required this.title,
    required this.value,
    required this.palette,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: accent
                ? palette.accent.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Text(
              step,
              style: AppTypography.mono(palette).copyWith(
                fontSize: 12,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.mono(palette).copyWith(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: accent ? palette.accent : palette.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: AppTypography.bodyMedium(palette).copyWith(
                      fontSize: 14,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, size: 14, color: palette.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _PipelineArrow extends StatelessWidget {
  final AppPalette palette;
  const _PipelineArrow({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Icon(
          Icons.arrow_downward,
          size: 16,
          color: palette.textTertiary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _IntentTag extends StatelessWidget {
  final String label;
  final bool active;
  final AppPalette palette;
  final VoidCallback onTap;

  const _IntentTag({
    required this.label,
    required this.active,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? palette.accent.withValues(alpha: 0.15)
              : palette.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? palette.accent.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.mono(palette).copyWith(
            fontSize: 10,
            letterSpacing: 1.0,
            color: active ? palette.accent : palette.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final VoidCallback onTap;

  const _MetaChip({
    required this.label,
    required this.value,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.mono(palette).copyWith(
                fontSize: 9,
                letterSpacing: 1.0,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTypography.mono(palette).copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableSpec extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final VoidCallback onTap;

  const _EditableSpec({
    required this.label,
    required this.value,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.mono(palette).copyWith(
                fontSize: 9,
                letterSpacing: 1.0,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.mono(palette).copyWith(
                fontSize: 14,
                color: palette.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableLine extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final AppPalette palette;
  final VoidCallback onTap;

  const _EditableLine({
    required this.label,
    required this.value,
    required this.hint,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.mono(palette).copyWith(
              fontSize: 10,
              letterSpacing: 1.1,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? hint : value,
            style: AppTypography.bodyMedium(palette).copyWith(
              fontSize: 13,
              color: value.isEmpty
                  ? palette.textTertiary
                  : palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThirdsPainter extends CustomPainter {
  final Color color;
  _ThirdsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..strokeWidth = 0.8;
    final dx = size.width / 3;
    final dy = size.height / 3;
    canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
    canvas.drawLine(Offset(dx * 2, 0), Offset(dx * 2, size.height), paint);
    canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    canvas.drawLine(Offset(0, dy * 2), Offset(size.width, dy * 2), paint);
  }

  @override
  bool shouldRepaint(covariant _ThirdsPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _LumaWavePainter extends CustomPainter {
  final double crush;
  final double peak;
  final Color accent;

  _LumaWavePainter({
    required this.crush,
    required this.peak,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.black.withValues(alpha: 0.45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(4),
      ),
      bg,
    );

    final path = Path();
    const n = 48;
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final x = t * size.width;
      final envelope = math.sin(t * math.pi);
      final noise = 0.35 +
          0.45 * math.sin(t * 18) * math.sin(t * 7.3) +
          0.2 * math.sin(t * 41);
      final yNorm = (crush + (peak - crush) * envelope * noise).clamp(0.0, 1.0);
      final y = size.height * (1 - yNorm);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final stroke = Paint()
      ..color = accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(path, stroke);

    final crushX = crush * size.width;
    final peakX = peak * size.width;
    final marker = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(crushX, 0),
      Offset(crushX, size.height),
      marker,
    );
    canvas.drawLine(
      Offset(peakX, 0),
      Offset(peakX, size.height),
      marker,
    );
  }

  @override
  bool shouldRepaint(covariant _LumaWavePainter oldDelegate) =>
      oldDelegate.crush != crush ||
      oldDelegate.peak != peak ||
      oldDelegate.accent != accent;
}
