import 'dart:convert';

import 'package:drift/drift.dart' show Value;
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
import '../exposure_overlay_preview.dart';
import '../block_reference_images.dart';
import 'section_scaffold.dart';

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

  static const _highlights = [
    'Protegidas',
    'Roll-off suave',
    'Quemadas intencionadas',
  ];
  static const _shadows = [
    'Abiertas (detalle en negros)',
    'Aplastadas (blacks cerrados)',
    'Mixtas',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    final globalLabel = BibleSectionFieldsConfig.labelFor(
      sectionContentJson,
      BibleSectionId.exposure,
      'globalExposure',
      'Exposición global',
    );
    final blocksLabel = BibleSectionFieldsConfig.labelFor(
      sectionContentJson,
      BibleSectionId.exposure,
      'blocks',
      'Bloques de exposición',
    );

    return BibleSectionScaffold(
      sectionId: BibleSectionId.exposure,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Protegemos highlights o dejamos quemar? ¿Por qué? '
          'Cómo la exposición refuerza la narrativa…',
      fieldWidgets: {
        'globalExposure': AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(globalLabel, style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: BibleDropdown(
                      label: 'Altas luces (global)',
                      options: _highlights,
                      value: data.highlightBehavior,
                      onChanged: (v) {
                        data.highlightBehavior = v;
                        onChanged(data);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BibleDropdown(
                      label: 'Sombras (global)',
                      options: _shadows,
                      value: data.shadowBehavior,
                      onChanged: (v) {
                        data.shadowBehavior = v;
                        onChanged(data);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: BibleTextField(
                      label: 'Ratio K:F (día)',
                      hint: '3:1',
                      initialValue: data.keyFillRatioDay,
                      onChanged: (v) {
                        data.keyFillRatioDay =
                            v.trim().isEmpty ? null : v.trim();
                        onChanged(data);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BibleTextField(
                      label: 'Ratio K:F (noche)',
                      hint: '5:1',
                      initialValue: data.keyFillRatioNight,
                      onChanged: (v) {
                        data.keyFillRatioNight =
                            v.trim().isEmpty ? null : v.trim();
                        onChanged(data);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              BibleTextField(
                label: 'Notas ND (fijo, variable, IR-ND)',
                hint: 'ND 0.6 exterior, IR-ND en LED…',
                maxLines: 3,
                initialValue: data.ndNotes,
                onChanged: (v) {
                  data.ndNotes = v.trim().isEmpty ? null : v.trim();
                  onChanged(data);
                },
              ),
            ],
          ),
        ),
        'blocks': Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(
          children: [
            Text(
              blocksLabel,
              style: AppTypography.titleMedium(palette),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _addBlock(context, ref),
              icon: Icon(Icons.add, color: palette.accent, size: 18),
              label: Text(
                'Añadir bloque',
                style: AppTypography.label(palette).copyWith(color: palette.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        StreamBuilder<List<ExposureBlock>>(
          stream: db.watchExposureBlocksForBible(bibleId),
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
                            Expanded(
                              child: Text(
                                block.blockName,
                                style: AppTypography.titleMedium(palette),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: palette.error, size: 20),
                              onPressed: () =>
                                  db.deleteExposureBlock(block.id),
                            ),
                          ],
                        ),
                        if (block.narrativeIntent?.isNotEmpty == true)
                          Text(block.narrativeIntent!),
                        if (block.keyFillRatio != null)
                          Text('K:F ${block.keyFillRatio}'),
                        if (block.highlightStrategy != null)
                          Text('Highlights: ${block.highlightStrategy}'),
                        if (block.shadowStrategy != null)
                          Text('Sombras: ${block.shadowStrategy}'),
                        if (block.referenceImages.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ExposureOverlayPreview(
                              imagePath: block.referenceImages.first,
                            ),
                          ),
                        const SizedBox(height: 8),
                        blockReferenceImagesRow(
                          projectId: projectId,
                          paths: block.referenceImages,
                          onSaved: (path) async {
                            block.referenceImages.add(path);
                            final rows = await db
                                .watchExposureBlocksForBible(bibleId)
                                .first;
                            final row = rows
                                .where((r) => r.id == block.id)
                                .firstOrNull;
                            if (row == null) return;
                            await db.updateExposureBlock(
                              row.copyWith(
                                referenceImages: Value(
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
                                final rows =
                                    await db.watchExposureBlocksForBible(bibleId).first;
                                final row =
                                    rows.where((r) => r.id == block.id).firstOrNull;
                                if (row == null) return;
                                await db.updateExposureBlock(
                                  row.copyWith(
                                    referenceImages: Value(
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
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.paddingOf(ctx).bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Nuevo bloque de exposición',
                    style: AppTypography.titleMedium(palette)),
                const SizedBox(height: AppSpacing.md),
                BibleTextField(
                  label: 'Nombre',
                  hint: 'Acto I',
                  onChanged: (_) {},
                  controller: nameCtrl,
                ),
                BibleTextField(
                  label: 'Intención narrativa',
                  hint: 'Sombras abiertas para vulnerabilidad…',
                  maxLines: 2,
                  onChanged: (_) {},
                  controller: intentCtrl,
                ),
                BibleTextField(
                  label: 'Ratio K:F',
                  hint: '3:1',
                  onChanged: (_) {},
                  controller: ratioCtrl,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    await ref.read(databaseProvider).insertExposureBlock(
                          ExposureBlocksCompanion.insert(
                            bibleId: bibleId,
                            blockName: name,
                            narrativeIntent: Value(
                              intentCtrl.text.trim().isEmpty
                                  ? null
                                  : intentCtrl.text.trim(),
                            ),
                            keyFillRatio: Value(
                              ratioCtrl.text.trim().isEmpty
                                  ? null
                                  : ratioCtrl.text.trim(),
                            ),
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
