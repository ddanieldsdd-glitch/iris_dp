import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_palette.dart';
import '../moodboard_palette_extractor.dart';
import 'bible_point_images.dart';
import 'bible_point_panel.dart';
import 'bible_visual_color_sheet.dart';

/// Paleta de color editable: muestras con código y nombre.
///
/// Se usa como punto de cualquier sección y como complemento de otro punto.
/// Los colores se pueden añadir a mano o extraer de una imagen del moodboard.
class BiblePaletteWidget extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final List<BiblePaletteColor> colors;
  final ValueChanged<List<BiblePaletteColor>> onChanged;

  /// Lado de cada muestra.
  final double swatchSize;

  const BiblePaletteWidget({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.colors,
    required this.onChanged,
    this.swatchSize = 96,
  });

  Future<void> _edit(BuildContext context, int? index) async {
    final current = index == null ? null : colors[index];
    final picked = await BibleVisualColorSheet.show(
      context,
      title: 'Color de la paleta',
      initialName: current?.name ?? '',
      initialColor:
          MoodboardPaletteExtractor.fromHex(current?.hex ?? '') ??
          const Color(0xFF1B3A4B),
      nameHint: 'Nombre del color',
      canDelete: index != null,
    );
    if (picked == null) return;
    final next = [...colors];
    if (picked.delete) {
      if (index != null) next.removeAt(index);
    } else {
      final color = BiblePaletteColor(hex: picked.hex, name: picked.name);
      if (index != null) {
        next[index] = color;
      } else {
        next.add(color);
      }
    }
    onChanged(next);
  }

  Future<void> _extract(BuildContext context, WidgetRef ref) async {
    final picked = await showMoodboardImagePicker(
      context,
      projectId: projectId,
      bibleId: bibleId,
      sectionId: sectionId,
      selected: const [],
      single: true,
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;
    final images = await ref
        .read(databaseProvider)
        .watchMoodboardImages(projectId)
        .first;
    final image = images.where((i) => i.id == picked.first).firstOrNull;
    if (image == null) return;
    final extracted = await MoodboardPaletteExtractor.fromFile(
      image.imagePath,
      count: 8,
    );
    if (!context.mounted) return;
    if (extracted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer esa imagen.')),
      );
      return;
    }
    final chosen = await showDialog<List<Color>>(
      context: context,
      builder: (_) => _ExtractedColorsDialog(
        path: image.imagePath,
        colors: extracted,
      ),
    );
    if (chosen == null || chosen.isEmpty) return;
    final existing = colors.map((c) => c.hex.toUpperCase()).toSet();
    onChanged([
      ...colors,
      for (final color in chosen)
        if (!existing.contains(MoodboardPaletteExtractor.toHex(color)))
          BiblePaletteColor(hex: MoodboardPaletteExtractor.toHex(color)),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final label = BiblePointPanel.labelStyle(palette);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 16,
          children: [
            for (var i = 0; i < colors.length; i++)
              _Swatch(
                size: swatchSize,
                color:
                    MoodboardPaletteExtractor.fromHex(colors[i].hex) ??
                    palette.surfaceOverlay,
                hex: colors[i].hex,
                name: colors[i].name,
                onTap: () => _edit(context, i),
              ),
            _Swatch.add(size: swatchSize, onTap: () => _edit(context, null)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: () => _extract(context, ref),
          icon: Icon(
            Icons.colorize_outlined,
            size: 16,
            color: palette.textSecondary,
          ),
          label: Text('EXTRAER DE UNA IMAGEN', style: label),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final double size;
  final Color? color;
  final String hex;
  final String name;
  final VoidCallback onTap;

  const _Swatch({
    required this.size,
    required Color this.color,
    required this.hex,
    required this.name,
    required this.onTap,
  });

  const _Swatch.add({required this.size, required this.onTap})
    : color = null,
      hex = '',
      name = '';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: size,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.borderBright),
              ),
              child: color == null
                  ? Center(
                      child: Icon(Icons.add, color: palette.textSecondary),
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              color == null ? 'AÑADIR' : hex.toUpperCase(),
              style: AppTypography.mono(palette).copyWith(fontSize: 11),
            ),
            if (name.isNotEmpty)
              Text(
                name.toUpperCase(),
                style: BiblePointPanel.labelStyle(
                  palette,
                ).copyWith(fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

/// Deja elegir qué colores extraídos de una imagen se añaden a la paleta.
class _ExtractedColorsDialog extends StatefulWidget {
  final String path;
  final List<Color> colors;

  const _ExtractedColorsDialog({required this.path, required this.colors});

  @override
  State<_ExtractedColorsDialog> createState() => _ExtractedColorsDialogState();
}

class _ExtractedColorsDialogState extends State<_ExtractedColorsDialog> {
  late final Set<int> _selected = {
    for (var i = 0; i < widget.colors.length && i < 5; i++) i,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AlertDialog(
      title: const Text('Colores de la imagen'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BibleImageThumb(path: widget.path, height: 160, width: 460),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Marca los colores que quieres añadir.',
              style: AppTypography.bodyMedium(palette),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < widget.colors.length; i++)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(
                      () => _selected.contains(i)
                          ? _selected.remove(i)
                          : _selected.add(i),
                    ),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.colors[i],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          width: _selected.contains(i) ? 3 : 1,
                          color: _selected.contains(i)
                              ? palette.accent
                              : palette.borderBright,
                        ),
                      ),
                      child: _selected.contains(i)
                          ? const Icon(
                              Icons.check,
                              size: 18,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, [
            for (final i in _selected.toList()..sort()) widget.colors[i],
          ]),
          child: Text('Añadir ${_selected.length}'),
        ),
      ],
    );
  }
}

/// Simbología de color: cada color con su nombre y lo que significa en la
/// película.
class BiblePaletteSymbolismWidget extends StatelessWidget {
  final List<BiblePaletteColor> colors;
  final ValueChanged<List<BiblePaletteColor>> onChanged;

  const BiblePaletteSymbolismWidget({
    super.key,
    required this.colors,
    required this.onChanged,
  });

  Future<void> _edit(BuildContext context, int? index) async {
    final current = index == null ? null : colors[index];
    final picked = await BibleVisualColorSheet.show(
      context,
      title: 'Color y significado',
      initialName: current?.name ?? '',
      initialColor:
          MoodboardPaletteExtractor.fromHex(current?.hex ?? '') ??
          const Color(0xFF1B3A4B),
      nameHint: 'Nombre del color',
      canDelete: index != null,
      includeMeaning: true,
      initialMeaning: current?.note ?? '',
    );
    if (picked == null) return;
    final next = [...colors];
    if (picked.delete) {
      if (index != null) next.removeAt(index);
    } else {
      final color = BiblePaletteColor(
        hex: picked.hex,
        name: picked.name,
        note: picked.meaning ?? '',
      );
      if (index != null) {
        next[index] = color;
      } else {
        next.add(color);
      }
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = BiblePointPanel.labelStyle(palette);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < colors.length; i++)
          InkWell(
            onTap: () => _edit(context, i),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          MoodboardPaletteExtractor.fromHex(colors[i].hex) ??
                          palette.surfaceOverlay,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: palette.borderBright),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            if (colors[i].name.isNotEmpty) colors[i].name,
                            colors[i].hex,
                          ].join(' · ').toUpperCase(),
                          style: label.copyWith(color: palette.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          colors[i].note.isEmpty
                              ? 'Toca para escribir qué significa…'
                              : colors[i].note,
                          style: AppTypography.bodyMedium(palette).copyWith(
                            color: colors[i].note.isEmpty
                                ? palette.textTertiary
                                : palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _edit(context, null),
            icon: Icon(Icons.add, size: 16, color: palette.accent),
            label: Text('AÑADIR COLOR', style: label),
          ),
        ),
      ],
    );
  }
}
