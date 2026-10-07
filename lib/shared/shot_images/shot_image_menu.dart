import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/clipboard_image_reader.dart';
import '../../core/utils/export_file_saver.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../core/utils/user_error.dart';

const _imageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.heic',
  '.gif',
  '.bmp',
  '.tif',
  '.tiff',
};

/// Qué imagen del plano se está eligiendo.
enum ShotImageTarget { reference, storyboard }

/// Menú de una imagen del plano (referencia o storyboard): arrastrarla,
/// pegarla con ⌘V, elegirla del ordenador o del moodboard, y quitarla.
Future<void> showShotImageMenu(
  BuildContext context,
  Shot shot, {
  ShotImageTarget target = ShotImageTarget.reference,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ReferenceImageMenu(shot: shot, target: target),
  );
}

class _ReferenceImageMenu extends ConsumerStatefulWidget {
  final Shot shot;
  final ShotImageTarget target;
  const _ReferenceImageMenu({required this.shot, required this.target});

  @override
  ConsumerState<_ReferenceImageMenu> createState() =>
      _ReferenceImageMenuState();
}

class _ReferenceImageMenuState extends ConsumerState<_ReferenceImageMenu> {
  bool _dragging = false;
  bool _busy = false;
  bool _moodboard = false;
  String? _notice;

  AppDatabase get _db => ref.read(databaseProvider);

  bool get _story => widget.target == ShotImageTarget.storyboard;

  String get _what => _story ? 'Storyboard' : 'Referencia';

  /// El plano tal como está ahora, no como estaba al abrir el menú.
  Future<Shot> _current() async =>
      await _db.getShotById(widget.shot.id) ?? widget.shot;

  Future<void> _run(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final done = await action();
      if (done && mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _notice = userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fromComputer(String source) => _run(() async {
    if (!_story) {
      final path = await pickAndImportShotReference(
        db: _db,
        shot: await _current(),
        source: source,
        dialogTitle: 'Referencia · Plano ${widget.shot.number}',
      );
      return path != null;
    }
    final file = await UserFilePicker.pickImage(
      dialogTitle: 'Storyboard · Plano ${widget.shot.number}',
    );
    final bytes = file?.bytes;
    if (file == null || bytes == null || bytes.isEmpty) return false;
    await importShotStoryboardImage(
      db: _db,
      shot: await _current(),
      sourceBytes: bytes,
      fileName: file.name,
    );
    return true;
  });

  Future<void> _fromPath(String path, {String? notImageNotice}) =>
      _run(() async {
        if (!_imageExtensions.contains(p.extension(path).toLowerCase()) ||
            !File(path).existsSync()) {
          setState(
            () => _notice = notImageNotice ?? 'Ese archivo no es una imagen.',
          );
          return false;
        }
        if (_story) {
          await importShotStoryboardImage(
            db: _db,
            shot: await _current(),
            sourcePath: path,
          );
        } else {
          await importShotReferenceImage(
            db: _db,
            shot: await _current(),
            sourcePath: path,
            source: ShotReferenceSource.manual,
          );
        }
        return true;
      });

  Future<void> _paste() => _run(() async {
    final result = await ClipboardImageReader.read();
    final payload = result.payload;
    if (result.status != ClipboardImageReadStatus.success || payload == null) {
      setState(() => _notice = 'No hay ninguna imagen en el portapapeles.');
      return false;
    }
    if (_story) {
      await importShotStoryboardImage(
        db: _db,
        shot: await _current(),
        sourceBytes: payload.bytes,
        fileName: 'pegada${payload.extension}',
      );
    } else {
      await importShotReferenceImage(
        db: _db,
        shot: await _current(),
        sourceBytes: payload.bytes,
        fileName: 'pegada${payload.extension}',
        source: ShotReferenceSource.manual,
      );
    }
    return true;
  });

  Future<void> _remove() => _run(() async {
    final shot = await _current();
    if (_story) {
      await _db.updateShotFields(
        shot.id,
        const ShotsCompanion(storyboardImagePath: Value(null)),
      );
      return true;
    }
    final path = shot.referenceImagePath;
    if (path == null) return true;
    final refs = await _db.watchReferencesForShot(shot.id).first;
    final match = refs.where((r) => r.imagePath == path).firstOrNull;
    if (match != null) {
      await deleteShotReferenceEntry(db: _db, shot: shot, reference: match);
    } else {
      await _db.updateShotFields(
        shot.id,
        const ShotsCompanion(referenceImagePath: Value(null)),
      );
    }
    return true;
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // La imagen propia de este uso; si no la tiene, se enseña la heredada
    // del otro, que no se puede quitar desde aquí.
    final own = _story
        ? widget.shot.storyboardImagePath
        : widget.shot.referenceImagePath;
    final shown = _story
        ? storyboardImageOf(widget.shot)
        : referenceImageOf(widget.shot);
    final path = shown;
    final hasOwn = own != null && File(own).existsSync();
    final hasImage = path != null && File(path).existsSync();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _paste,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _paste,
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: palette.surfaceElevated,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (_moodboard)
                        IconButton(
                          tooltip: 'Volver',
                          icon: const Icon(Icons.arrow_back, size: 18),
                          onPressed: () => setState(() => _moodboard = false),
                        ),
                      Expanded(
                        child: Text(
                          _moodboard
                              ? 'Elegir del moodboard'
                              : '$_what · Plano ${widget.shot.number}',
                          style: AppTypography.titleMedium(palette),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_moodboard)
                    _moodboardGrid(palette)
                  else ...[
                    _dropZone(palette, hasImage ? path : null),
                    if (hasImage && !hasOwn) ...[
                      const SizedBox(height: 6),
                      Text(
                        _story
                            ? 'Es la imagen de referencia del plano. Pon '
                                  'otra aquí si el storyboard debe llevar una '
                                  'distinta.'
                            : 'Es la imagen del storyboard. Pon otra aquí si '
                                  'la referencia debe ser distinta.',
                        style: AppTypography.caption(palette),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _busy
                              ? null
                              : () => _fromComputer(ShotReferenceSource.manual),
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Del ordenador'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _moodboard = true;
                                  _notice = null;
                                }),
                          icon: const Icon(Icons.dashboard_outlined, size: 18),
                          label: const Text('Del moodboard'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : _paste,
                          icon: const Icon(Icons.content_paste, size: 18),
                          label: const Text('Pegar'),
                        ),
                        if (!_story)
                          PopupMenuButton<String>(
                            tooltip: 'Más orígenes',
                            color: palette.surfaceElevated,
                            enabled: !_busy,
                            onSelected: _fromComputer,
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: ShotReferenceSource.artemisCapture,
                                child: Text('Captura de Artemis'),
                              ),
                              PopupMenuItem(
                                value: ShotReferenceSource.unrealRender,
                                child: Text('Render de Unreal'),
                              ),
                            ],
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              child: Text(
                                'Más orígenes',
                                style: AppTypography.bodyMedium(palette),
                              ),
                            ),
                          ),
                        if (hasOwn)
                          TextButton.icon(
                            onPressed: _busy ? null : _remove,
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: palette.error,
                            ),
                            label: Text(
                              'Quitar',
                              style: AppTypography.bodyMedium(
                                palette,
                              ).copyWith(color: palette.error),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (_notice != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _notice!,
                      style: AppTypography.bodyMedium(
                        palette,
                      ).copyWith(color: palette.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropZone(AppPalette palette, String? currentPath) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        if (details.files.isEmpty) return;
        _fromPath(details.files.first.path);
      },
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: _dragging
              ? palette.accent.withValues(alpha: 0.14)
              : palette.surfaceOverlay.withValues(alpha: 0.4),
          border: Border.all(
            color: _dragging ? palette.accent : palette.border,
            width: _dragging ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: _busy
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                fit: StackFit.expand,
                children: [
                  if (currentPath != null)
                    Opacity(
                      opacity: _dragging ? 0.3 : 1,
                      child: Image.file(File(currentPath), fit: BoxFit.contain),
                    ),
                  if (currentPath == null || _dragging)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 34,
                          color: _dragging
                              ? palette.accent
                              : palette.textTertiary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _dragging
                              ? 'Suelta la imagen'
                              : 'Arrastra una imagen aquí',
                          style: AppTypography.bodyLarge(palette),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'o pégala con ⌘V',
                          style: AppTypography.caption(palette),
                        ),
                      ],
                    )
                  else
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.55),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Arrastra otra imagen aquí o pégala con ⌘V '
                          'para cambiarla',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _moodboardGrid(AppPalette palette) {
    return SizedBox(
      height: 380,
      child: StreamBuilder<List<MoodboardImage>>(
        stream: _db.watchMoodboardImages(widget.shot.projectId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final images = [
            for (final image in snap.data!)
              if (File(image.imagePath).existsSync()) image,
          ];
          if (images.isEmpty) {
            return Center(
              child: Text(
                'El moodboard de este proyecto aún no tiene imágenes.',
                style: AppTypography.bodyMedium(palette),
              ),
            );
          }
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 16 / 10,
            ),
            itemCount: images.length,
            itemBuilder: (context, i) {
              final image = images[i];
              return Tooltip(
                message: (image.caption ?? '').trim().isEmpty
                    ? 'Usar esta imagen'
                    : image.caption!.trim(),
                child: InkWell(
                  onTap: _busy ? null : () => _fromPath(image.imagePath),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(image.imagePath),
                      fit: BoxFit.cover,
                      cacheWidth: 300,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
