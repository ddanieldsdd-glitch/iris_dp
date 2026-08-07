import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/clipboard_image_reader.dart';
import '../../../core/utils/media_storage.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../services/color_extraction_service.dart';
import '../visual_bible_model.dart';
import 'color_palette_strip.dart';

/// Bloques de colorimetría por escena / localización con refs de imagen.
class ColorScenePalettesPanel extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final List<ColorBlockModel> blocks;

  const ColorScenePalettesPanel({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.blocks,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.palette_outlined, size: 18, color: palette.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'COLORIMETRÍAS POR ESCENA / LOCALIZACIÓN',
                style: AppTypography.label(palette).copyWith(
                      letterSpacing: 0.8,
                      color: palette.accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _addBlock(context, ref),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nueva paleta'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Pega o añade imágenes: la app lee los colores presentes y genera la paleta.',
          style: AppTypography.caption(palette).copyWith(
                color: palette.textSecondary,
              ),
        ),
        const SizedBox(height: 14),
        if (blocks.isEmpty)
          _EmptyColorimetryHint(onAdd: () => _addBlock(context, ref))
        else
          for (final block in blocks) ...[
            _ColorimetryBlockCard(
              projectId: projectId,
              bibleId: bibleId,
              block: block,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Future<void> _addBlock(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva colorimetría'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Escena o localización',
            hintText: 'Ej. INT. APARTAMENTO — NOCHE',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (ok != true || name.isEmpty) return;

    final db = ref.read(databaseProvider);
    await db.insertColorBlock(
      VisualBibleColorBlocksCompanion.insert(
        bibleId: bibleId,
        blockName: name,
        dominantColors: '[]',
        sortOrder: Value(blocks.length),
      ),
    );
  }
}

class _EmptyColorimetryHint extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyColorimetryHint({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Text(
            'Aún no hay colorimetrías. Crea una por escena o localización '
            'y pega referencias para extraer la paleta.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(palette).copyWith(
                  color: palette.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Crear primera paleta'),
          ),
        ],
      ),
    );
  }
}

class _ColorimetryBlockCard extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;
  final ColorBlockModel block;

  const _ColorimetryBlockCard({
    required this.projectId,
    required this.bibleId,
    required this.block,
  });

  @override
  ConsumerState<_ColorimetryBlockCard> createState() =>
      _ColorimetryBlockCardState();
}

class _ColorimetryBlockCardState extends ConsumerState<_ColorimetryBlockCard> {
  bool _busy = false;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _persist(ColorBlockModel model) async {
    final db = ref.read(databaseProvider);
    final row = await (db.select(db.visualBibleColorBlocks)
          ..where((t) => t.id.equals(model.id)))
        .getSingle();
    await db.updateColorBlock(
      row.copyWith(
        blockName: model.blockName,
        dominantColors: jsonEncode(model.dominantColors),
        accentColors: Value(
          model.accentColors.isEmpty ? null : jsonEncode(model.accentColors),
        ),
        referenceImages: Value(
          model.referenceImages.isEmpty
              ? null
              : jsonEncode(model.referenceImages),
        ),
        colorTempKelvin: Value(model.colorTempKelvin),
      ),
    );
  }

  Future<void> _addImageBytes(Uint8List bytes, {String ext = '.png'}) async {
    setState(() => _busy = true);
    try {
      final path = await MediaStorage.writeProjectFileBytes(
        projectId: widget.projectId,
        subfolder: 'visual_bible/color_refs',
        bytes: bytes,
        fileName:
            'color_${widget.block.id}_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      final extraction = await ColorExtractionService.extractFromBytes(bytes);
      final hexes = ColorExtractionService.paletteToHex(extraction.palette);
      final model = widget.block;
      model.referenceImages = [...model.referenceImages, path];
      if (hexes.isNotEmpty) {
        // Primera imagen define dominantes; siguientes se acumulan sin duplicar.
        if (model.dominantColors.isEmpty) {
          model.dominantColors = hexes.take(6).toList();
        } else {
          for (final h in hexes.take(4)) {
            if (!model.dominantColors.any(
              (e) => e.toUpperCase().contains(h.replaceFirst('#', '')),
            )) {
              model.dominantColors.add(h);
            }
          }
        }
      }
      if (extraction.estimatedKelvin != null) {
        model.colorTempKelvin ??= extraction.estimatedKelvin;
      }
      await _persist(model);
      if (!mounted) return;
      AppSnackBar.show(
        context,
        hexes.isEmpty
            ? 'Imagen añadida'
            : 'Paleta leída · ${hexes.length} colores',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, 'No se pudo procesar la imagen');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _paste() async {
    final result = await ClipboardImageReader.read();
    final payload = result.payload;
    if (result.status != ClipboardImageReadStatus.success || payload == null) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        'Copia una imagen y pulsa ⌘V aquí para extraer la paleta.',
        isError: true,
      );
      return;
    }
    await _addImageBytes(payload.bytes, ext: payload.extension);
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    for (final file in result.files) {
      final path = file.path;
      Uint8List? bytes = file.bytes;
      if (bytes == null && path != null) {
        bytes = await File(path).readAsBytes();
      }
      if (bytes == null) continue;
      final ext = path != null ? p.extension(path) : '.png';
      await _addImageBytes(bytes, ext: ext.isEmpty ? '.png' : ext);
    }
  }

  Future<void> _removeImage(String path) async {
    final model = widget.block;
    model.referenceImages =
        model.referenceImages.where((p) => p != path).toList();
    await _persist(model);
  }

  Future<void> _applyPaletteFromImage(String path) async {
    setState(() => _busy = true);
    try {
      final extraction = await ColorExtractionService.extractFromFile(path);
      final hexes = ColorExtractionService.paletteToHex(extraction.palette);
      if (hexes.isEmpty) return;
      final model = widget.block;
      model.dominantColors = hexes.take(8).toList();
      if (extraction.estimatedKelvin != null) {
        model.colorTempKelvin = extraction.estimatedKelvin;
      }
      await _persist(model);
      if (!mounted) return;
      AppSnackBar.show(context, 'Paleta aplicada desde la imagen');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: widget.block.blockName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar colorimetría'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || name.isEmpty) return;
    final model = widget.block;
    model.blockName = name;
    await _persist(model);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar colorimetría'),
        content: Text('¿Eliminar «${widget.block.blockName}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(databaseProvider).deleteColorBlock(widget.block.id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final block = widget.block;
    final swatches = block.dominantColors;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.keyV, LogicalKeyboardKey.meta):
            const _PasteColorIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyV, LogicalKeyboardKey.control):
            const _PasteColorIntent(),
      },
      child: Actions(
        actions: {
          _PasteColorIntent: CallbackAction<_PasteColorIntent>(
            onInvoke: (_) {
              _paste();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          child: GestureDetector(
            onTap: () => _focusNode.requestFocus(),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xB31A1A1C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          block.blockName,
                          style: AppTypography.titleMedium(palette).copyWith(
                                fontSize: 15,
                              ),
                        ),
                      ),
                      if (_busy)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      IconButton(
                        tooltip: 'Renombrar',
                        icon: Icon(Icons.edit_outlined,
                            size: 18, color: palette.textSecondary),
                        onPressed: _rename,
                      ),
                      IconButton(
                        tooltip: 'Eliminar',
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: palette.textSecondary),
                        onPressed: _delete,
                      ),
                    ],
                  ),
                  if (block.colorTempKelvin != null) ...[
                    Text(
                      '${block.colorTempKelvin}K',
                      style: AppTypography.mono(palette).copyWith(
                            color: palette.accent,
                            fontSize: 12,
                          ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (swatches.isNotEmpty) ...[
                    SizedBox(
                      height: 28,
                      child: Row(
                        children: [
                          for (final raw in swatches.take(8))
                            Expanded(
                              child: ColoredBox(
                                color: _hexColor(raw) ?? Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (block.referenceImages.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 28,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: palette.border,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.image_outlined,
                              color: palette.textTertiary),
                          const SizedBox(height: 8),
                          Text(
                            'Pega (⌘V) o elige una imagen para leer su colorimetría',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption(palette).copyWith(
                                  color: palette.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final path in block.referenceImages)
                          SizedBox(
                            width: 160,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ColorBlockReferenceCardAsync(
                                  imagePath: path,
                                  onRemove: () => _removeImage(path),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _applyPaletteFromImage(path),
                                  child: const Text('Usar esta paleta'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _busy ? null : _paste,
                        icon: const Icon(Icons.content_paste, size: 16),
                        label: const Text('Pegar imagen'),
                      ),
                      TextButton.icon(
                        onPressed: _busy ? null : _pick,
                        icon: const Icon(Icons.add_photo_alternate_outlined,
                            size: 16),
                        label: const Text('Añadir'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color? _hexColor(String raw) {
    var h = raw.contains('|') ? raw.split('|').last.trim() : raw.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }
}

class _PasteColorIntent extends Intent {
  const _PasteColorIntent();
}
