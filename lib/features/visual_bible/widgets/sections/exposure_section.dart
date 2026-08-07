// /Users/danieldiaz/Documents/IRIS DP/iris_dp/lib/features/visual_bible/widgets/sections/exposure_section.dart
import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_section_shared_widgets.dart';
import '../exposure_overlay_preview.dart';
import '../block_reference_images.dart';
import 'section_scaffold.dart';

class ExposureSection extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<ExposureSection> createState() => _ExposureSectionState();
}

class _ExposureSectionState extends ConsumerState<ExposureSection> {
  Map<String, dynamic> _getCustomData() {
    if (widget.sectionContentJson == null) return {};
    try {
      final decoded = jsonDecode(widget.sectionContentJson!);
      if (decoded is Map<String, dynamic> && decoded.containsKey('_values')) {
        final vals = decoded['_values'] as Map<String, dynamic>;
        if (vals.containsKey('exposureData')) {
          return jsonDecode(vals['exposureData'] as String) as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return {};
  }

  Future<void> _updateCustomData(Map<String, dynamic> update) async {
    final current = _getCustomData();
    final newData = {...current, ...update};
    final db = ref.read(databaseProvider);
    final def = await (db.select(db.bibleSectionDefinitions)
          ..where(
            (d) =>
                d.bibleId.equals(widget.data.id) &
                d.id.equals(BibleSectionId.exposure),
          ))
        .getSingleOrNull();
    if (def != null) {
      final fields =
          BibleSectionFieldsConfig.parse(def.contentJson, BibleSectionId.exposure);
      final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
      values['exposureData'] = jsonEncode(newData);
      await db.upsertBibleSectionDefinition(
        def.copyWith(
          contentJson: drift.Value(
            BibleSectionFieldsConfig.encode(fields, values: values),
          ),
        ),
      );
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final data = widget.data;
    final parsedJson = _getCustomData();

    final List<dynamic> ndScenarios = parsedJson['ndScenarios'] ?? [
      {'scenario': 'Ext. Day Harsh', 'targetStop': 'T5.6', 'iso': 800, 'nd': '1.2', 'irCut': true},
      {'scenario': 'Ext. Day Overcast', 'targetStop': 'T4.0', 'iso': 800, 'nd': '0.6', 'irCut': false},
      {'scenario': 'Ext. Night', 'targetStop': 'T2.0', 'iso': 3200, 'nd': 'Clear', 'irCut': false},
    ];
    final String monitoringMode = parsedJson['monitoringMode'] ?? 'false_color';
    final double dynamicRangeStops = (parsedJson['dynamicRangeStops'] as num?)?.toDouble() ?? 14.0;
    final int dualIso = parsedJson['dualIso'] ?? 3200;
    final double shutterAngle = (parsedJson['shutterAngle'] as num?)?.toDouble() ?? 180.0;

    return BibleSectionScaffold(
      sectionId: BibleSectionId.exposure,
      projectId: widget.projectId,
      data: data,
      onChanged: widget.onChanged,
      sectionContentJson: widget.sectionContentJson,
      narrativeHint: '¿Protegemos highlights o dejamos quemar? ¿Por qué? Cómo la exposición refuerza la narrativa…',
      sectionNumber: '04',
      sectionTitle: 'Exposición',
      fieldWidgets: {
        'globalExposure': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: BibleTechCard(label: 'BASE ISO', value: data.nativeIso?.toString() ?? '800')),
                      const SizedBox(width: 4),
                      Expanded(child: BibleTechCard(label: 'DUAL ISO', value: dualIso.toString())),
                      const SizedBox(width: 4),
                      Expanded(child: BibleTechCard(label: 'SHUTTER ANGLE', value: '$shutterAngle°')),
                      const SizedBox(width: 4),
                      Expanded(child: BibleTechCard(label: 'BASE T-STOP', value: data.defaultTStop ?? '—')),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BibleTextField(
                    label: 'Base ISO',
                    initialValue: data.nativeIso?.toString(),
                    onChanged: (v) {
                      data.nativeIso = int.tryParse(v);
                      widget.onChanged(data);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BibleHeroValue(value: dynamicRangeStops.toStringAsFixed(1), unit: 'stops', label: 'RANGO DINÁMICO'),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Text('SOMBRAS', style: AppTypography.label(palette)),
                      Expanded(
                        child: Slider(
                          value: dynamicRangeStops.clamp(8.0, 20.0),
                          min: 8.0, max: 20.0,
                          divisions: 24,
                          label: '${dynamicRangeStops.toStringAsFixed(1)} stops',
                          onChanged: (v) => _updateCustomData({'dynamicRangeStops': v}),
                          activeColor: palette.accent,
                        ),
                      ),
                      Text('LUCES', style: AppTypography.label(palette)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MONITORING TOOLS', style: AppTypography.titleMedium(palette)),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: ['false_color', 'waveform', 'parade'].map((mode) {
                      final active = monitoringMode == mode;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _updateCustomData({'monitoringMode': mode}),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: active ? palette.accent.withValues(alpha: 0.1) : palette.surfaceElevated,
                              border: Border.all(color: active ? palette.accent : palette.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                mode.toUpperCase(),
                                style: AppTypography.label(palette).copyWith(color: active ? palette.accent : palette.textSecondary),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ND FILTRATION & SCENARIO MAPPING', style: AppTypography.titleMedium(palette)),
                  const SizedBox(height: AppSpacing.md),
                  ...ndScenarios.map((scen) {
                    final map = scen as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(border: Border.all(color: palette.border), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(map['scenario'].toString().toUpperCase(), style: AppTypography.label(palette)),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(child: BibleTechCard(label: 'STOP', value: map['targetStop'] ?? '')),
                              const SizedBox(width: 4),
                              Expanded(child: BibleTechCard(label: 'ISO', value: map['iso']?.toString() ?? '')),
                              const SizedBox(width: 4),
                              Expanded(child: BibleTechCard(label: 'ND', value: map['nd'] ?? '')),
                              const SizedBox(width: 4),
                              Expanded(child: BibleTechCard(label: 'IR CUT', value: map['irCut'] == true ? 'YES' : 'NO')),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton(onPressed: (){}, child: Text('Añadir escenario', style: TextStyle(color: palette.accent))),
                  const SizedBox(height: AppSpacing.sm),
                  BibleTextField(
                    label: 'Notas ND',
                    maxLines: 2,
                    initialValue: data.ndNotes,
                    onChanged: (v) {
                      data.ndNotes = v;
                      widget.onChanged(data);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        'blocks': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Bloques de exposición', style: AppTypography.titleMedium(palette)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _addBlock(context, ref),
                  icon: Icon(Icons.add, color: palette.accent, size: 18),
                  label: Text('Añadir bloque', style: AppTypography.label(palette).copyWith(color: palette.accent)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            StreamBuilder<List<ExposureBlock>>(
              stream: db.watchExposureBlocksForBible(widget.bibleId),
              builder: (context, snap) {
                final blocks = snap.data ?? [];
                return Column(
                  children: blocks.map((row) {
                    final block = ExposureBlockModel.fromRow(row);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(block.blockName, style: AppTypography.titleMedium(palette))),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: palette.error, size: 20),
                                  onPressed: () => db.deleteExposureBlock(block.id),
                                ),
                              ],
                            ),
                            if (block.narrativeIntent?.isNotEmpty == true) Text(block.narrativeIntent!),
                            if (block.keyFillRatio != null) Text('K:F ${block.keyFillRatio}'),
                            if (block.highlightStrategy != null) Text('Highlights: ${block.highlightStrategy}'),
                            if (block.shadowStrategy != null) Text('Sombras: ${block.shadowStrategy}'),
                            if (block.referenceImages.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: ExposureOverlayPreview(imagePath: block.referenceImages.first),
                              ),
                            const SizedBox(height: 8),
                            blockReferenceImagesRow(
                              projectId: widget.projectId,
                              paths: block.referenceImages,
                              onSaved: (path) async {
                                block.referenceImages.add(path);
                                final rows = await db.watchExposureBlocksForBible(widget.bibleId).first;
                                final rw = rows.where((r) => r.id == block.id).firstOrNull;
                                if (rw == null) return;
                                await db.updateExposureBlock(rw.copyWith(referenceImages: drift.Value(jsonEncode(block.referenceImages))));
                              },
                              onAdd: () async {
                                await pickBlockReferenceImage(
                                  projectId: widget.projectId,
                                  onSaved: (path) async {
                                    block.referenceImages.add(path);
                                    final rows = await db.watchExposureBlocksForBible(widget.bibleId).first;
                                    final rw = rows.where((r) => r.id == block.id).firstOrNull;
                                    if (rw == null) return;
                                    await db.updateExposureBlock(rw.copyWith(referenceImages: drift.Value(jsonEncode(block.referenceImages))));
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
        )
      },
    );
  }

  Future<void> _addBlock(BuildContext context, WidgetRef ref) async {
    final palette = context.palette;
    final nameCtrl = TextEditingController();
    final intentCtrl = TextEditingController();
    final ratioCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surfaceElevated,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.lg,
            bottom: MediaQuery.paddingOf(ctx).bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Nuevo bloque de exposición', style: AppTypography.titleMedium(palette)),
                const SizedBox(height: AppSpacing.md),
                BibleTextField(label: 'Nombre', hint: 'Acto I', onChanged: (_) {}, controller: nameCtrl),
                BibleTextField(label: 'Intención narrativa', hint: 'Sombras abiertas para vulnerabilidad…', maxLines: 2, onChanged: (_) {}, controller: intentCtrl),
                BibleTextField(label: 'Ratio K:F', hint: '3:1', onChanged: (_) {}, controller: ratioCtrl),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    await ref.read(databaseProvider).insertExposureBlock(
                      ExposureBlocksCompanion.insert(
                        bibleId: widget.bibleId,
                        blockName: name,
                        narrativeIntent: drift.Value(intentCtrl.text.trim().isEmpty ? null : intentCtrl.text.trim()),
                        keyFillRatio: drift.Value(ratioCtrl.text.trim().isEmpty ? null : ratioCtrl.text.trim()),
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Crear bloque'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
