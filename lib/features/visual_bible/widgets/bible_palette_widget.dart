import 'dart:async';

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

  /// Imágenes del propio punto: «Extraer de una imagen» propone la primera.
  final List<int> preferredImageIds;

  const BiblePaletteWidget({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.colors,
    required this.onChanged,
    this.swatchSize = 96,
    this.preferredImageIds = const [],
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
      selected: preferredImageIds.take(1).toList(),
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

/// Punto de paleta completo: la paleta y, si se quiere, imágenes que la
/// representan y un texto que la desarrolla. El menú «⋯» elige qué se ve;
/// ocultar una parte no borra su contenido.
class BiblePalettePoint extends StatelessWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final String label;
  final IconData icon;

  /// Simbología: cada color con su significado, en lugar de muestras.
  final bool symbolism;
  final double swatchSize;
  final BiblePaletteValue value;
  final ValueChanged<BiblePaletteValue> onChanged;

  const BiblePalettePoint({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.symbolism = false,
    this.swatchSize = 112,
  });

  static const _partLabels = {
    BiblePalettePart.palette: 'Paleta',
    BiblePalettePart.images: 'Imágenes',
    BiblePalettePart.text: 'Texto',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final parts = <Widget>[
      if (value.shows(BiblePalettePart.images))
        BiblePointImages(
          projectId: projectId,
          bibleId: bibleId,
          sectionId: sectionId,
          imageIds: value.imageIds,
          height: 150,
          onChanged: (ids) => onChanged(value.copyWith(imageIds: ids)),
        ),
      if (value.shows(BiblePalettePart.palette))
        symbolism
            ? BiblePaletteSymbolismWidget(
                colors: value.colors,
                onChanged: (colors) => onChanged(value.copyWith(colors: colors)),
              )
            : BiblePaletteWidget(
                projectId: projectId,
                bibleId: bibleId,
                sectionId: sectionId,
                swatchSize: swatchSize,
                preferredImageIds: value.imageIds,
                colors: value.colors,
                onChanged: (colors) => onChanged(value.copyWith(colors: colors)),
              ),
      if (value.shows(BiblePalettePart.text))
        _PaletteText(
          text: value.text,
          hint: symbolism
              ? 'Qué cuenta el color en esta película y por qué…'
              : 'Por qué esta paleta: qué expresa y cómo evoluciona…',
          onChanged: (text) => onChanged(value.copyWith(text: text)),
        ),
    ];

    return BiblePointPanel(
      label: label,
      icon: icon,
      trailing: PopupMenuButton<BiblePalettePart>(
        tooltip: 'Qué se muestra',
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.visibility_outlined,
          size: 18,
          color: palette.textSecondary,
        ),
        onSelected: (part) => onChanged(value.toggled(part)),
        itemBuilder: (_) => [
          for (final part in BiblePalettePart.values)
            CheckedPopupMenuItem(
              value: part,
              checked: value.shows(part),
              // La última parte visible no se puede ocultar.
              enabled: !(value.shows(part) && value.show.length == 1),
              child: Text(_partLabels[part]!),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            parts[i],
          ],
        ],
      ),
    );
  }
}

/// Texto de desarrollo con guardado automático.
class _PaletteText extends StatefulWidget {
  final String text;
  final String hint;
  final ValueChanged<String> onChanged;

  const _PaletteText({
    required this.text,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_PaletteText> createState() => _PaletteTextState();
}

class _PaletteTextState extends State<_PaletteText> {
  late final _controller = TextEditingController(text: widget.text);
  final _focus = FocusNode();
  Timer? _debounce;

  @override
  void didUpdateWidget(_PaletteText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Solo se refresca desde fuera cuando no se está escribiendo.
    if (!_focus.hasFocus && widget.text != _controller.text) {
      _controller.text = widget.text;
    }
  }

  void _flush() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      widget.onChanged(_controller.text);
    }
  }

  @override
  void dispose() {
    _flush();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return TextField(
      controller: _controller,
      focusNode: _focus,
      minLines: 3,
      maxLines: null,
      textCapitalization: TextCapitalization.sentences,
      style: AppTypography.bodyMedium(palette).copyWith(height: 1.5),
      decoration: InputDecoration(
        hintText: widget.hint,
        border: InputBorder.none,
        isDense: true,
      ),
      onChanged: (text) {
        _debounce?.cancel();
        _debounce = Timer(
          const Duration(milliseconds: 500),
          () => widget.onChanged(text),
        );
      },
      onTapOutside: (_) {
        _flush();
        _focus.unfocus();
      },
    );
  }
}
