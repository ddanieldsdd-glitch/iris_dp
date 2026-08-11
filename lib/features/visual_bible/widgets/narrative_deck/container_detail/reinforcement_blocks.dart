import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../moodboard_helpers.dart';
import '../../../visual_bible_model.dart';
import '../../../moodboard_palette_extractor.dart';
import '../../bible_form_widgets.dart';
import '../../bible_paste_zone.dart';
import '../../color_palette_strip.dart';
import '../container_detail/palette_target_viewer.dart';

/// Bloques de refuerzo (texto + imagen) bajo la paleta del contenedor.
class ReinforcementBlocks extends StatelessWidget {
  final int projectId;
  final int bibleId;
  final NarrativeCardModel card;
  final AppDatabase db;
  final AppPalette palette;
  final ValueChanged<List<ContainerReinforcementBlock>> onChanged;

  const ReinforcementBlocks({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.card,
    required this.db,
    required this.palette,
    required this.onChanged,
  });

  void _update(List<ContainerReinforcementBlock> blocks) {
    onChanged(blocks);
  }

  Future<void> _addTextBlock() async {
    final blocks = [...card.reinforcementBlocks];
    blocks.add(ContainerReinforcementBlock.text(''));
    _update(blocks);
  }

  Future<void> _addImageBlock(int imageId) async {
    final blocks = [...card.reinforcementBlocks];
    blocks.add(ContainerReinforcementBlock.image(imageId));
    _update(blocks);
  }

  @override
  Widget build(BuildContext context) {
    final blocks = card.reinforcementBlocks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'REFUERZOS',
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  color: palette.textTertiary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _addTextBlock,
              icon: const Icon(Icons.notes_outlined, size: 16),
              label: const Text('Texto'),
              style: TextButton.styleFrom(
                foregroundColor: palette.textSecondary,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (blocks.isEmpty)
          Text(
            'Añade textos o imágenes que refuercen la intención del contenedor.',
            style: AppTypography.bodyMedium(palette).copyWith(
              fontSize: 12,
              color: palette.textTertiary,
            ),
          ),
        for (var i = 0; i < blocks.length; i++) ...[
          _ReinforcementBlockTile(
            block: blocks[i],
            index: i,
            projectId: projectId,
            bibleId: bibleId,
            card: card,
            db: db,
            palette: palette,
            onTextChanged: (text) {
              final next = [...blocks];
              next[i] = next[i].copyWith(text: text);
              _update(next);
            },
            onRemove: () {
              final next = [...blocks]..removeAt(i);
              _update(next);
            },
          ),
          const SizedBox(height: 12),
        ],
        BibleTargetZone(
          hint: 'Añadir imagen de refuerzo',
          minHeight: 80,
          onPaste: (payload) async {
            final id = await MoodboardHelpers.addImageForNarrativeCard(
              db: db,
              projectId: projectId,
              bibleId: bibleId,
              cardId: card.id,
              sectionId: card.sectionId,
              bytes: payload.bytes,
              extension: payload.extension,
              locationBasePlanId: card.locationBasePlanId,
            );
            await _addImageBlock(id);
          },
          onMoodboardDropped: (drag) async {
            await MoodboardHelpers.linkMoodboardToSection(
              db: db,
              projectId: projectId,
              payload: drag,
              sectionId: card.sectionId,
              locationBasePlanId: card.locationBasePlanId,
              cardId: card.id,
            );
            if (drag.moodboardImageId != null) {
              await _addImageBlock(drag.moodboardImageId!);
            }
          },
          child: Container(
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              '⌘V o arrastra imagen de refuerzo',
              style: AppTypography.bodyMedium(palette).copyWith(
                fontSize: 12,
                color: palette.textTertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReinforcementBlockTile extends StatelessWidget {
  final ContainerReinforcementBlock block;
  final int index;
  final int projectId;
  final int bibleId;
  final NarrativeCardModel card;
  final AppDatabase db;
  final AppPalette palette;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onRemove;

  const _ReinforcementBlockTile({
    required this.block,
    required this.index,
    required this.projectId,
    required this.bibleId,
    required this.card,
    required this.db,
    required this.palette,
    required this.onTextChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  block.isText ? 'TEXTO' : 'IMAGEN',
                  style: AppTypography.mono(palette).copyWith(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: palette.textTertiary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: palette.textTertiary,
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (block.isText)
              BibleTextField(
                label: 'Bloque ${index + 1}',
                initialValue: block.text ?? '',
                maxLines: 4,
                onChanged: onTextChanged,
              )
            else if (block.imageId != null)
              _ReinforcementImage(
                imageId: block.imageId!,
                db: db,
                palette: palette,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReinforcementImage extends StatelessWidget {
  final int imageId;
  final AppDatabase db;
  final AppPalette palette;

  const _ReinforcementImage({
    required this.imageId,
    required this.db,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MoodboardImage?>(
      future: (db.select(db.moodboardImages)..where((m) => m.id.equals(imageId)))
          .getSingleOrNull(),
      builder: (context, snap) {
        final row = snap.data;
        if (row == null) {
          return Text(
            'Imagen no encontrada',
            style: AppTypography.bodyMedium(palette).copyWith(
              color: palette.textTertiary,
            ),
          );
        }
        final path = row.imagePath;
        final hasFile = File(path).existsSync();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasFile)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(path),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 8),
            FutureBuilder(
              future: db.getMoodboardImageMeta(imageId),
              builder: (context, metaSnap) {
                final metaMap = metaSnap.data;
                final hex = metaMap?['paletteHex'] is List
                    ? (metaMap!['paletteHex'] as List)
                        .map((e) => e.toString())
                        .toList()
                    : <String>[];
                if (hex.isEmpty && hasFile) {
                  return PaletteTargetViewerAsync(
                    imagePath: path,
                    paletteHex: const [],
                    size: PaletteTargetSize.small,
                    palette: palette,
                  );
                }
                final colors = hex
                    .map(MoodboardPaletteExtractor.fromHex)
                    .whereType<Color>()
                    .toList();
                if (colors.isEmpty) return const SizedBox.shrink();
                return ColorPaletteStrip(colors: colors, height: 14);
              },
            ),
          ],
        );
      },
    );
  }
}
