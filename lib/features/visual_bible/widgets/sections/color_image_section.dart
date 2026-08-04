import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/media_storage.dart';
import '../../../../core/widgets/app_card.dart';
import '../../bible_section_fields.dart';
import '../../services/color_extraction_service.dart';
import '../../bible_paste_helpers.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_paste_zone.dart';
import '../color_palette_strip.dart';
import 'section_scaffold.dart';

class ColorImageSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final int bibleId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const ColorImageSection({
    super.key,
    required this.data,
    required this.projectId,
    required this.bibleId,
    this.sectionContentJson,
    required this.onChanged,
  });

  static const _colorSpaces = ['Rec.709', 'P3-D65', 'HDR10', 'HLG'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    final lutLabel = BibleSectionFieldsConfig.labelFor(
      sectionContentJson,
      BibleSectionId.colorImage,
      'lut',
      'LUT y color science',
    );
    final blocksLabel = BibleSectionFieldsConfig.labelFor(
      sectionContentJson,
      BibleSectionId.colorImage,
      'blocks',
      'Paletas por bloque',
    );

    return BibleSectionScaffold(
      sectionId: BibleSectionId.colorImage,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Qué emoción transmite esta paleta y este LUT? '
          'Cómo el color apoya la narrativa…',
      fieldWidgets: {
        'lut': AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lutLabel, style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.md),
              BibleTextField(
                label: 'LUT de trabajo (rodaje / log)',
                hint: 'S-Log3 → Rec.709',
                initialValue: data.workingLutName,
                onChanged: (v) {
                  data.workingLutName = v.trim().isEmpty ? null : v.trim();
                  onChanged(data);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              BibleTextField(
                label: 'LUT creativo',
                hint: 'Look final de intención',
                initialValue: data.creativeLutName,
                onChanged: (v) {
                  data.creativeLutName = v.trim().isEmpty ? null : v.trim();
                  onChanged(data);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              BibleTextField(
                label: 'Descripción del LUT creativo',
                hint: 'Qué hace al look final…',
                maxLines: 3,
                initialValue: data.creativeLutDescription,
                onChanged: (v) {
                  data.creativeLutDescription =
                      v.trim().isEmpty ? null : v.trim();
                  onChanged(data);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              BibleDropdown(
                label: 'Espacio de color de entrega',
                options: _colorSpaces,
                value: data.deliveryColorSpace,
                onChanged: (v) {
                  data.deliveryColorSpace = v;
                  onChanged(data);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              BibleTextField(
                label: 'Color science de cámara',
                hint: 'Cómo renderiza skin tones y highlights…',
                maxLines: 3,
                initialValue: data.colorScienceNotes,
                onChanged: (v) {
                  data.colorScienceNotes = v.trim().isEmpty ? null : v.trim();
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
            Text(blocksLabel, style: AppTypography.titleMedium(palette)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _addBlock(context, ref),
              icon: Icon(Icons.add, color: palette.accent, size: 18),
              label: Text('Añadir bloque',
                  style: AppTypography.label(palette)
                      .copyWith(color: palette.accent)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        StreamBuilder<List<VisualBibleColorBlock>>(
          stream: db.watchColorBlocksForBible(bibleId),
          builder: (context, snap) {
            final blocks = snap.data ?? [];
            return Column(
              children: blocks.map((row) {
                final block = ColorBlockModel.fromRow(row);
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
                              child: Text(block.blockName,
                                  style: AppTypography.titleMedium(palette)),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: palette.error, size: 20),
                              onPressed: () => db.deleteColorBlock(block.id),
                            ),
                          ],
                        ),
                        if (block.emotionalIntent?.isNotEmpty == true)
                          Text(block.emotionalIntent!),
                        if (block.swatches.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ColorPaletteStrip(colors: block.swatches, height: 22),
                        ],
                        if (block.colorTempKelvin != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('${block.colorTempKelvin}K estimado'),
                          ),
                        if (block.referenceImages.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          ...block.referenceImages.map(
                            (path) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: ColorBlockReferenceCardAsync(
                                imagePath: path,
                                onRemove: () => _removeReference(
                                  ref,
                                  block,
                                  path,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        BibleTargetZone(
                          hint:
                              'Clic aquí → ⌘V para pegar ref en este bloque (paleta)',
                          onPaste: (payload) async {
                            final stored =
                                await BiblePasteHelpers.savePayloadToProject(
                              projectId: projectId,
                              subfolder: 'bible_blocks',
                              payload: payload,
                              prefix: 'ref',
                            );
                            if (stored != null) {
                              await _attachImagePathToBlock(
                                ref,
                                block,
                                stored,
                              );
                            }
                          },
                          onMoodboardDropped: (payload) =>
                              _attachMoodboardToBlock(
                            ref,
                            block,
                            payload.imagePath,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton.icon(
                          onPressed: () => _addReference(context, ref, block),
                          icon: const Icon(Icons.add_photo_alternate_outlined,
                              size: 16),
                          label: const Text('Asociar imagen'),
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

  Future<void> _addReference(
    BuildContext context,
    WidgetRef ref,
    ColorBlockModel block,
  ) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final sourcePath = result.files.single.path;
    if (sourcePath == null) return;

    final ext = sourcePath.contains('.') ? '.${sourcePath.split('.').last}' : '.jpg';
    final stored = await MediaStorage.copyFileIntoProject(
      projectId: projectId,
      sourcePath: sourcePath,
      subfolder: 'bible_blocks',
      fileName: 'ref_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    if (stored == null) return;

    await _attachImagePathToBlock(ref, block, stored);
  }

  Future<void> _attachMoodboardToBlock(
    WidgetRef ref,
    ColorBlockModel block,
    String sourcePath,
  ) async {
    final ext = sourcePath.contains('.') ? '.${sourcePath.split('.').last}' : '.jpg';
    final stored = await MediaStorage.copyFileIntoProject(
      projectId: projectId,
      sourcePath: sourcePath,
      subfolder: 'bible_blocks',
      fileName: 'ref_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    if (stored == null) return;
    await _attachImagePathToBlock(ref, block, stored);
  }

  Future<void> _attachImagePathToBlock(
    WidgetRef ref,
    ColorBlockModel block,
    String storedPath,
  ) async {
    final extraction = await ColorExtractionService.extractFromFile(storedPath);
    final db = ref.read(databaseProvider);
    final rows = await db.watchColorBlocksForBible(bibleId).first;
    final row = rows.where((r) => r.id == block.id).firstOrNull;
    if (row == null) return;

    final images = List<String>.from(block.referenceImages)..add(storedPath);
    await db.updateColorBlock(
      row.copyWith(
        referenceImages: Value(jsonEncode(images)),
        dominantColors:
            jsonEncode(ColorExtractionService.paletteToHex(extraction.palette)),
        colorTempKelvin: Value(extraction.estimatedKelvin),
      ),
    );
  }

  Future<void> _removeReference(
    WidgetRef ref,
    ColorBlockModel block,
    String path,
  ) async {
    final db = ref.read(databaseProvider);
    final rows = await db.watchColorBlocksForBible(bibleId).first;
    final row = rows.where((r) => r.id == block.id).firstOrNull;
    if (row == null) return;

    final images = List<String>.from(block.referenceImages)..remove(path);
    await db.updateColorBlock(
      row.copyWith(
        referenceImages: Value(
          images.isEmpty ? null : jsonEncode(images),
        ),
      ),
    );
  }

  Future<void> _addBlock(BuildContext context, WidgetRef ref) async {
    final palette = context.palette;
    final nameCtrl = TextEditingController();
    final intentCtrl = TextEditingController();
    final tempCtrl = TextEditingController();
    final colors = <Color>[const Color(0xFF1A1A2E)];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surfaceElevated,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
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
                    Text('Nuevo bloque de color',
                        style: AppTypography.titleMedium(palette)),
                    const SizedBox(height: AppSpacing.md),
                    BibleTextField(
                      label: 'Nombre',
                      hint: 'Acto I',
                      onChanged: (_) {},
                      controller: nameCtrl,
                    ),
                    BibleTextField(
                      label: 'Intención emocional',
                      hint: 'Tensión, frío distante…',
                      maxLines: 2,
                      onChanged: (_) {},
                      controller: intentCtrl,
                    ),
                    BibleTextField(
                      label: 'Temperatura (K)',
                      hint: '3200',
                      onChanged: (_) {},
                      controller: tempCtrl,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          allowMultiple: false,
                        );
                        final path = result?.files.single.path;
                        if (path == null) return;
                        final extraction =
                            await ColorExtractionService.extractFromFile(path);
                        setSt(() {
                          colors
                            ..clear()
                            ..addAll(extraction.palette);
                          if (extraction.estimatedKelvin != null) {
                            tempCtrl.text =
                                extraction.estimatedKelvin.toString();
                          }
                        });
                      },
                      icon: const Icon(Icons.colorize, size: 18),
                      label: const Text('Extraer de imagen'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (colors.isNotEmpty)
                      ColorPaletteStrip(colors: colors),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        final hexes = ColorExtractionService.paletteToHex(colors);
                        await ref.read(databaseProvider).insertColorBlock(
                              VisualBibleColorBlocksCompanion.insert(
                                bibleId: bibleId,
                                blockName: name,
                                emotionalIntent: Value(
                                  intentCtrl.text.trim().isEmpty
                                      ? null
                                      : intentCtrl.text.trim(),
                                ),
                                dominantColors: jsonEncode(hexes),
                                colorTempKelvin: Value(
                                  int.tryParse(tempCtrl.text.trim()),
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
      },
    );
  }
}

