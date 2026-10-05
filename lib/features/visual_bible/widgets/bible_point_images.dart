import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/clipboard_image_reader.dart';
import '../bible_paste_helpers.dart';
import '../moodboard_helpers.dart';
import 'bible_point_panel.dart';

/// Lee `pointImages[key]` del blob de una sección: ids de imágenes del
/// moodboard que acompañan a un punto.
List<int> biblePointImageIds(Map<String, dynamic> blob, String pointKey) {
  final all = blob['pointImages'];
  final raw = all is Map ? all[pointKey] : null;
  return [
    if (raw is List)
      for (final id in raw)
        if (id is num) id.toInt(),
  ];
}

/// Devuelve el mapa `pointImages` con los ids de [pointKey] sustituidos.
Map<String, dynamic> biblePointImagesWith(
  Map<String, dynamic> blob,
  String pointKey,
  List<int> ids,
) {
  final all = blob['pointImages'];
  return {
    if (all is Map)
      for (final entry in all.entries) entry.key.toString(): entry.value,
    pointKey: ids,
  };
}

/// Imágenes del moodboard que refuerzan el texto de un punto.
class BiblePointImages extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final List<int> imageIds;
  final ValueChanged<List<int>> onChanged;
  final double height;

  const BiblePointImages({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.imageIds,
    required this.onChanged,
    this.height = 96,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImages(projectId),
      builder: (context, snap) {
        final all = snap.data ?? const <MoodboardImage>[];
        final byId = {for (final image in all) image.id: image};
        final linked = [
          for (final id in imageIds)
            if (byId[id] != null) byId[id]!,
        ];
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final image in linked)
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () async {
                  final remove = await showBibleImageViewer(
                    context,
                    path: image.imagePath,
                    removeLabel: 'Quitar de este punto',
                  );
                  if (remove == true) {
                    onChanged([...imageIds]..remove(image.id));
                  }
                },
                child: BibleImageThumb(path: image.imagePath, height: height),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () async {
                final picked = await showMoodboardImagePicker(
                  context,
                  projectId: projectId,
                  bibleId: bibleId,
                  sectionId: sectionId,
                  selected: imageIds,
                );
                if (picked != null) onChanged(picked);
              },
              child: Container(
                height: height,
                width: linked.isEmpty ? 168 : height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 20,
                      color: palette.textSecondary,
                    ),
                    if (linked.isEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'AÑADIR IMÁGENES',
                        style: BiblePointPanel.labelStyle(palette),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Miniatura de una imagen local, con el alto fijo y el ancho de la imagen.
class BibleImageThumb extends StatelessWidget {
  final String path;
  final double height;
  final double? width;

  const BibleImageThumb({
    super.key,
    required this.path,
    required this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: height,
        width: width ?? height * 16 / 9,
        child: file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : ColoredBox(color: context.palette.surfaceOverlay),
      ),
    );
  }
}

/// Muestra una imagen a tamaño grande. Devuelve `true` si se pide quitarla.
Future<bool?> showBibleImageViewer(
  BuildContext context, {
  required String path,
  String? removeLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: InteractiveViewer(
              child: File(path).existsSync()
                  ? Image.file(File(path), fit: BoxFit.contain)
                  : const SizedBox(height: 200),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (removeLabel != null)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(removeLabel),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Elige imágenes del moodboard del proyecto. Devuelve los ids elegidos, o
/// `null` si se cancela.
Future<List<int>?> showMoodboardImagePicker(
  BuildContext context, {
  required int projectId,
  required int bibleId,
  required String sectionId,
  required List<int> selected,
  bool single = false,
}) {
  return showDialog<List<int>>(
    context: context,
    builder: (_) => _MoodboardImagePicker(
      projectId: projectId,
      bibleId: bibleId,
      sectionId: sectionId,
      initial: selected,
      single: single,
    ),
  );
}

class _MoodboardImagePicker extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final List<int> initial;
  final bool single;

  const _MoodboardImagePicker({
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.initial,
    required this.single,
  });

  @override
  ConsumerState<_MoodboardImagePicker> createState() =>
      _MoodboardImagePickerState();
}

class _MoodboardImagePickerState extends ConsumerState<_MoodboardImagePicker> {
  late final List<int> _selected = [...widget.initial];

  /// Aviso bajo la rejilla (p. ej. portapapeles sin imagen).
  String? _notice;

  void _select(Iterable<int> ids) {
    if (!mounted) return;
    setState(() {
      _notice = null;
      for (final id in ids) {
        if (_selected.contains(id)) continue;
        if (widget.single) _selected.clear();
        _selected.add(id);
      }
    });
  }

  /// Pega la imagen del portapapeles en el moodboard y la deja elegida.
  Future<void> _paste() async {
    final db = ref.read(databaseProvider);
    final status = await BiblePasteHelpers.pasteFromClipboard(
      onPayload: (payload) async => _select([
        await MoodboardHelpers.addImageFromBytesAssigned(
          db: db,
          projectId: widget.projectId,
          bibleId: widget.bibleId,
          bytes: payload.bytes,
          extension: payload.extension,
          assignedSections: [widget.sectionId],
        ),
      ]),
    );
    if (status != ClipboardImageReadStatus.success && mounted) {
      setState(() => _notice = 'No hay ninguna imagen en el portapapeles.');
    }
  }

  /// Importa archivos y deja elegidos los que entren.
  Future<void> _import() async {
    final db = ref.read(databaseProvider);
    Future<Set<int>> ids() async => {
      for (final image in await db.watchMoodboardImages(widget.projectId).first)
        image.id,
    };
    final before = await ids();
    await MoodboardHelpers.addManualImages(
      db: db,
      projectId: widget.projectId,
      bibleId: widget.bibleId,
      assignedSections: [widget.sectionId],
    );
    _select((await ids()).difference(before));
  }

  void _toggle(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        if (widget.single) _selected.clear();
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _paste,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _paste,
      },
      child: Focus(autofocus: true, child: _dialog(context, palette, db)),
    );
  }

  Widget _dialog(BuildContext context, AppPalette palette, AppDatabase db) {
    return AlertDialog(
      title: Text(
        widget.single
            ? 'Elegir imagen del moodboard'
            : 'Imágenes del moodboard',
      ),
      content: SizedBox(
        width: 640,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                _notice ??
                    'Elige del moodboard, importa un archivo o pega una '
                        'imagen con ⌘V.',
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: _notice == null ? null : palette.error),
              ),
            ),
            Expanded(child: _grid(palette, db)),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _import,
          icon: const Icon(Icons.upload_file_outlined, size: 16),
          label: const Text('Importar archivo'),
        ),
        TextButton.icon(
          onPressed: _paste,
          icon: const Icon(Icons.content_paste, size: 16),
          label: const Text('Pegar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(widget.single ? 'Elegir' : 'Usar ${_selected.length}'),
        ),
      ],
    );
  }

  Widget _grid(AppPalette palette, AppDatabase db) {
    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImages(widget.projectId),
      builder: (context, snap) {
        final images = snap.data ?? const <MoodboardImage>[];
        if (images.isEmpty) {
          return Center(
            child: Text(
              'El moodboard del proyecto está vacío.\n'
              'Importa un archivo o pega una imagen con ⌘V.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(palette),
            ),
          );
        }
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 16 / 9,
          ),
          itemCount: images.length,
          itemBuilder: (context, i) {
            final image = images[i];
            final on = _selected.contains(image.id);
            return InkWell(
              onTap: () => _toggle(image.id),
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        width: 2,
                        color: on ? palette.accent : Colors.transparent,
                      ),
                    ),
                    child: BibleImageThumb(
                      path: image.imagePath,
                      height: 90,
                      width: 160,
                    ),
                  ),
                  if (on)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: palette.accent,
                        child: widget.single
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              )
                            : Text(
                                '${_selected.indexOf(image.id) + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
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
