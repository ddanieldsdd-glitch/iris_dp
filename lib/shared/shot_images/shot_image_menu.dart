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

/// Pega en el plano la imagen que haya en el portapapeles. Como referencia
/// se añade a las que ya tenga (un plano puede llevar una por encuadre);
/// como storyboard, sustituye a la anterior. Devuelve `null` si ha ido bien y, si no, por qué no
/// se ha podido, dicho para el usuario.
Future<String?> pasteShotImageFromClipboard(
  AppDatabase db,
  Shot shot, {
  ShotImageTarget target = ShotImageTarget.reference,
}) async {
  final result = await ClipboardImageReader.read();
  final payload = result.payload;
  if (result.status != ClipboardImageReadStatus.success || payload == null) {
    return switch (result.status) {
      ClipboardImageReadStatus.downloadFailed =>
        'Lo copiado es un enlace a una imagen y no se ha podido descargar. '
            'Copia la imagen en sí («Copiar imagen») o arrástrala aquí.',
      ClipboardImageReadStatus.invalidUrl =>
        'Lo copiado es un enlace, pero no lleva a una imagen.',
      ClipboardImageReadStatus.pluginUnavailable =>
        'La app no puede leer el portapapeles hasta que se cierre y se '
            'vuelva a abrir del todo.',
      _ =>
        'En el portapapeles no hay una imagen (hay texto u otra cosa). '
            'Copia la imagen y vuelve a pegar.',
    };
  }
  final current = await db.getShotById(shot.id) ?? shot;
  if (target == ShotImageTarget.storyboard) {
    await importShotStoryboardImage(
      db: db,
      shot: current,
      sourceBytes: payload.bytes,
      fileName: 'pegada${payload.extension}',
    );
  } else {
    await importShotReferenceImage(
      db: db,
      shot: current,
      sourceBytes: payload.bytes,
      fileName: 'pegada${payload.extension}',
      source: ShotReferenceSource.manual,
      keepPrimary: true,
    );
  }
  return null;
}

/// Envuelve la casilla de imagen de un plano para poder pegar en ella sin
/// abrir su menú: con el ratón encima (o tras tocarla), ⌘V pega ahí.
class ShotImagePasteTarget extends ConsumerStatefulWidget {
  final Shot shot;
  final ShotImageTarget target;
  final Widget child;

  const ShotImagePasteTarget({
    super.key,
    required this.shot,
    required this.child,
    this.target = ShotImageTarget.reference,
  });

  @override
  ConsumerState<ShotImagePasteTarget> createState() =>
      _ShotImagePasteTargetState();
}

class _ShotImagePasteTargetState extends ConsumerState<ShotImagePasteTarget> {
  final _focus = FocusNode(debugLabel: 'imagen del plano');
  bool _busy = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    if (_busy) return;
    setState(() => _busy = true);
    String? problem;
    try {
      problem = await pasteShotImageFromClipboard(
        ref.read(databaseProvider),
        widget.shot,
        target: widget.target,
      );
    } catch (e) {
      problem = userFriendlyError(e);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            problem ??
                (widget.target == ShotImageTarget.storyboard
                    ? 'Imagen pegada en el storyboard del plano '
                          '${widget.shot.number}.'
                    : 'Imagen añadida a las referencias del plano '
                          '${widget.shot.number}.'),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _paste,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _paste,
      },
      child: Focus(
        focusNode: _focus,
        onFocusChange: (_) => setState(() {}),
        child: MouseRegion(
          // Con el ratón encima, la casilla coge el foco (salvo que se esté
          // escribiendo en otra): ⌘V pega aquí.
          onEnter: (_) {
            final focused = FocusManager.instance.primaryFocus?.context?.widget;
            if (focused is! EditableText) _focus.requestFocus();
          },
          onExit: (_) {
            if (_focus.hasPrimaryFocus) _focus.unfocus();
          },
          child: Tooltip(
            message: '⌘V pega aquí la imagen copiada · clic para más opciones',
            waitDuration: const Duration(milliseconds: 700),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: _focus.hasPrimaryFocus
                    ? Border.all(color: palette.accent, width: 2)
                    : null,
              ),
              child: Opacity(opacity: _busy ? 0.5 : 1, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

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
        keepPrimary: true,
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

  /// Pone en el plano las imágenes de [paths]. La referencia las admite
  /// todas, una detrás de otra; el storyboard se queda con la primera.
  Future<void> _fromPaths(List<String> paths) => _run(() async {
    final images = [
      for (final path in paths)
        if (_imageExtensions.contains(p.extension(path).toLowerCase()) &&
            File(path).existsSync())
          path,
    ];
    if (images.isEmpty) {
      setState(() => _notice = 'Ese archivo no es una imagen.');
      return false;
    }
    if (_story) {
      await importShotStoryboardImage(
        db: _db,
        shot: await _current(),
        sourcePath: images.first,
      );
      return true;
    }
    for (final path in images) {
      await importShotReferenceImage(
        db: _db,
        shot: await _current(),
        sourcePath: path,
        source: ShotReferenceSource.manual,
        keepPrimary: true,
      );
    }
    return true;
  });

  Future<void> _fromPath(String path) => _fromPaths([path]);

  Future<void> _paste() => _run(() async {
    final problem = await pasteShotImageFromClipboard(
      _db,
      await _current(),
      target: widget.target,
    );
    if (problem == null) return true;
    setState(() => _notice = problem);
    return false;
  });

  /// Quita la imagen propia del storyboard.
  Future<void> _remove() => _run(() async {
    await _db.updateShotFields(
      widget.shot.id,
      const ShotsCompanion(storyboardImagePath: Value(null)),
    );
    return true;
  });

  /// Quita una de las referencias; el menú sigue abierto con las demás.
  Future<void> _removeReference(ShotReference reference) => _run(() async {
    await deleteShotReferenceEntry(
      db: _db,
      shot: await _current(),
      reference: reference,
    );
    return false;
  });

  @override
  void initState() {
    super.initState();
    if (widget.target == ShotImageTarget.reference) {
      // Una referencia antigua puede no tener fila propia: se le da para que
      // salga en la lista y se pueda quitar.
      // La base se coge ya: el menú puede cerrarse antes de acabar.
      final db = _db;
      final shot = widget.shot;
      _references = () async* {
        await ensureShotReferencesSynced(
          db: db,
          shot: await db.getShotById(shot.id) ?? shot,
        );
        yield* db.watchReferencesForShot(shot.id);
      }();
    }
  }

  Stream<List<ShotReference>>? _references;

  @override
  Widget build(BuildContext context) {
    if (_story) return _dialog(context, const []);
    return StreamBuilder<List<ShotReference>>(
      stream: _references,
      builder: (context, snap) => _dialog(context, [
        for (final reference in snap.data ?? const <ShotReference>[])
          if (File(reference.imagePath).existsSync()) reference,
      ]),
    );
  }

  /// [references] son las imágenes de referencia propias del plano; vacío
  /// en el menú del storyboard.
  Widget _dialog(BuildContext context, List<ShotReference> references) {
    final palette = context.palette;
    // La imagen propia de este uso; si no la tiene, se enseña la heredada
    // del otro, que no se puede quitar desde aquí.
    final own = _story
        ? widget.shot.storyboardImagePath
        : references.firstOrNull?.imagePath;
    final path =
        own ??
        (_story
            ? widget.shot.referenceImagePath
            : widget.shot.storyboardImagePath);
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
                    if (references.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _referenceStrip(palette, references),
                    ],
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
                        if (hasOwn && _story)
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
        _fromPaths([for (final file in details.files) file.path]);
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
                          _story
                              ? 'Arrastra otra imagen aquí o pégala con ⌘V '
                                    'para cambiarla'
                              : 'Arrastra o pega con ⌘V más imágenes: una '
                                    'por encuadre',
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

  /// Las referencias del plano en su orden, cada una con su «quitar».
  Widget _referenceStrip(AppPalette palette, List<ShotReference> references) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: references.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final reference = references[i];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(reference.imagePath),
                  width: 104,
                  height: 64,
                  fit: BoxFit.cover,
                  cacheWidth: 300,
                ),
              ),
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Tooltip(
                  message: 'Quitar esta imagen',
                  child: InkWell(
                    onTap: _busy ? null : () => _removeReference(reference),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
