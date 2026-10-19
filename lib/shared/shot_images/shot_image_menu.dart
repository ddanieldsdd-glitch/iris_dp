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
import '../annotations/annotation_document.dart';
import '../annotations/sketch_pad.dart';
import '../history/edit_history.dart';
import '../history/shot_edits.dart';

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
enum ShotImageTarget {
  reference,
  storyboard,

  /// Boceto de la planta: imagen que hace de planta mientras no se dibuja.
  planSketch,
}

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
  if (target == ShotImageTarget.planSketch) {
    await importShotPlanSketch(
      db: db,
      shot: current,
      sourceBytes: payload.bytes,
      fileName: 'pegada${payload.extension}',
    );
  } else if (target == ShotImageTarget.storyboard) {
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
      final db = ref.read(databaseProvider);
      problem = await recordShotImages(
        db,
        ref.read(editHistoryProvider),
        widget.shot.id,
        () =>
            pasteShotImageFromClipboard(db, widget.shot, target: widget.target),
        label: 'imagen pegada',
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
                switch (widget.target) {
                  ShotImageTarget.storyboard =>
                    'Imagen pegada en el storyboard del plano '
                        '${widget.shot.number}.',
                  ShotImageTarget.planSketch =>
                    'Boceto añadido a la planta del plano '
                        '${widget.shot.number}.',
                  ShotImageTarget.reference =>
                    'Imagen añadida a las referencias del plano '
                        '${widget.shot.number}.',
                },
          ),
        ),
      );
  }

  /// Copia la primera imagen de la casilla, para pegarla en otra.
  Future<void> _copy() async {
    final db = ref.read(databaseProvider);
    final shot = await db.getShotById(widget.shot.id) ?? widget.shot;
    final path = switch (widget.target) {
      ShotImageTarget.storyboard => storyboardImageOf(shot),
      ShotImageTarget.planSketch => planSketchesOf(shot).firstOrNull,
      ShotImageTarget.reference =>
        referenceImagesOf(
              shot,
              await db.watchReferencesForShot(shot.id).first,
            ).firstOrNull ??
            referenceImageOf(shot),
    };
    final done = path != null && await ClipboardImageReader.copyImageFile(path);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            done
                ? 'Imagen copiada. Pégala con ⌘V sobre otra casilla.'
                : 'Esta casilla no tiene imagen que copiar.',
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
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true): _copy,
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): _copy,
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
            message:
                '⌘V pega aquí la imagen copiada · ⌘C la copia · clic para '
                'más opciones',
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

/// Lo que el menú de bocetos necesita de las plantas de cámara y luz, para
/// enseñar y ofrecer los bocetos dibujados allí (entradas `setup:<id>`).
class ShotSketchDelegate {
  /// Miniatura de un boceto dibujado.
  final Widget Function(BuildContext context, Shot shot, int setupId) thumbnail;

  /// El apartado «Bocetos de la planta»: los que hay y dibujar uno nuevo.
  final Widget Function(BuildContext context, Shot shot) section;

  /// Abre el boceto en el editor de planta.
  final Future<void> Function(BuildContext context, Shot shot, int setupId)
  open;

  const ShotSketchDelegate({
    required this.thumbnail,
    required this.section,
    required this.open,
  });
}

/// Menú de una imagen del plano (referencia o storyboard): arrastrarla,
/// pegarla con ⌘V, elegirla del ordenador o del moodboard, y quitarla.
Future<void> showShotImageMenu(
  BuildContext context,
  Shot shot, {
  ShotImageTarget target = ShotImageTarget.reference,
  ShotSketchDelegate? sketches,
  WidgetBuilder? footer,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ReferenceImageMenu(
      shot: shot,
      target: target,
      sketches: sketches,
      footer: footer,
    ),
  );
}

class _ReferenceImageMenu extends ConsumerStatefulWidget {
  final Shot shot;
  final ShotImageTarget target;
  final ShotSketchDelegate? sketches;

  /// Algo más al pie del menú, propio de quien lo abre.
  final WidgetBuilder? footer;
  const _ReferenceImageMenu({
    required this.shot,
    required this.target,
    this.sketches,
    this.footer,
  });

  @override
  ConsumerState<_ReferenceImageMenu> createState() =>
      _ReferenceImageMenuState();
}

class _ReferenceImageMenuState extends ConsumerState<_ReferenceImageMenu> {
  bool _dragging = false;
  bool _busy = false;
  bool _moodboard = false;
  String? _notice;

  /// Aviso que no es un error («Imagen copiada»).
  String? _info;

  AppDatabase get _db => ref.read(databaseProvider);

  bool get _story => widget.target == ShotImageTarget.storyboard;

  bool get _sketch => widget.target == ShotImageTarget.planSketch;

  String get _what => switch (widget.target) {
    ShotImageTarget.storyboard => 'Storyboard',
    ShotImageTarget.planSketch => 'Boceto de planta',
    ShotImageTarget.reference => 'Referencia',
  };

  /// Bocetos de planta del plano, al día: los da la base en [build].
  List<String> _sketches = const [];
  Stream<Shot?>? _shotChanges;

  /// El plano tal como está ahora, no como estaba al abrir el menú.
  Future<Shot> _current() async =>
      await _db.getShotById(widget.shot.id) ?? widget.shot;

  Future<void> _run(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
      _info = null;
    });
    try {
      final done = await recordShotImages(
        _db,
        ref.read(editHistoryProvider),
        widget.shot.id,
        action,
      );
      if (done && mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _notice = userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fromComputer(String source) => _run(() async {
    if (!_story && !_sketch) {
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
      dialogTitle: '$_what · Plano ${widget.shot.number}',
    );
    final bytes = file?.bytes;
    if (file == null || bytes == null || bytes.isEmpty) return false;
    if (_sketch) {
      await importShotPlanSketch(
        db: _db,
        shot: await _current(),
        sourceBytes: bytes,
        fileName: file.name,
      );
      return false;
    }
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
    if (_sketch) {
      for (final path in images) {
        await importShotPlanSketch(
          db: _db,
          shot: await _current(),
          sourcePath: path,
        );
      }
      return false;
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

  /// Pone el dibujo del storyboard entre las referencias del plano.
  Future<void> _useStoryboard() => _run(() async {
    final shot = await _current();
    final path = shot.storyboardImagePath;
    if (path == null || !File(path).existsSync()) {
      setState(() => _notice = 'Este plano no tiene dibujo de storyboard.');
      return false;
    }
    await importShotReferenceImage(
      db: _db,
      shot: shot,
      sourcePath: path,
      source: ShotReferenceSource.storyboard,
      keepPrimary: true,
    );
    return true;
  });

  Future<void> _paste() => _run(() async {
    final problem = await pasteShotImageFromClipboard(
      _db,
      await _current(),
      target: widget.target,
    );
    if (problem == null) return !_sketch;
    setState(() => _notice = problem);
    return false;
  });

  /// Viñeta del plano anterior de la escena, para el papel cebolla, con
  /// su etiqueta («Plano 1»).
  Future<(ImageProvider, String)?> _previousStoryboardFrame() async {
    if (widget.target != ShotImageTarget.storyboard) return null;
    final shot = await _current();
    final shots = await _db.getShotsForScene(shot.sceneId);
    final index = shots.indexWhere((s) => s.id == shot.id);
    for (var i = index - 1; i >= 0; i--) {
      final path = shots[i].storyboardImagePath;
      if (path != null && File(path).existsSync()) {
        return (FileImage(File(path)), 'Plano ${shots[i].number}');
      }
    }
    return null;
  }

  /// Abre el lienzo blanco y guarda el dibujo como imagen del plano. Con
  /// [editing], sigue un dibujo que ya estaba: el nuevo ocupa su sitio.
  Future<void> _draw({String? editing}) async {
    if (_busy) return;
    final onionSkin = await _previousStoryboardFrame();
    if (!mounted) return;
    final result = await showSketchPad(
      context,
      title: '$_what · Plano ${widget.shot.number}',
      initial: editing == null
          ? const AnnotationDocument()
          : readSketchDocument(editing),
      aspectRatio: _sketch ? 4 / 3 : 16 / 9,
      purpose: _sketch
          ? SketchSheetPurpose.lightingPlan
          : SketchSheetPurpose.storyboard,
      onionSkin: onionSkin?.$1,
      onionSkinLabel: onionSkin?.$2,
    );
    if (result == null || !mounted) return;
    await _run(() async {
      final shot = await _current();
      final String stored;
      switch (widget.target) {
        case ShotImageTarget.storyboard:
          stored = await importShotStoryboardImage(
            db: _db,
            shot: shot,
            sourceBytes: result.png,
            fileName: 'dibujo.png',
          );
        case ShotImageTarget.planSketch:
          final at = editing == null
              ? -1
              : planSketchEntriesOf(shot).indexOf(editing);
          stored = await importShotPlanSketch(
            db: _db,
            shot: shot,
            sourceBytes: result.png,
            fileName: 'dibujo.png',
          );
          if (at >= 0) {
            await reorderShotPlanSketches(
              db: _db,
              shot: shot,
              path: stored,
              to: at,
            );
            await removeShotPlanSketch(db: _db, shot: shot, path: editing!);
          }
        case ShotImageTarget.reference:
          final before = await _db.watchReferencesForShot(shot.id).first;
          final old = before.where((r) => r.imagePath == editing).firstOrNull;
          stored = await importShotReferenceImage(
            db: _db,
            shot: shot,
            sourceBytes: result.png,
            fileName: 'dibujo.png',
            source: ShotReferenceSource.manual,
            keepPrimary: true,
          );
          if (old != null) {
            final after = await _db.watchReferencesForShot(shot.id).first;
            final fresh = after.where((r) => r.imagePath == stored).firstOrNull;
            if (fresh != null) {
              await reorderShotReference(
                db: _db,
                shot: await _current(),
                reference: fresh,
                to: before.indexOf(old),
              );
            }
            await deleteShotReferenceEntry(
              db: _db,
              shot: await _current(),
              reference: old,
            );
          }
      }
      await writeSketchDocument(stored, result.document);
      return false;
    });
  }

  /// Cambia de sitio una referencia; la primera es la principal.
  Future<void> _moveReference(ShotReference reference, int to) =>
      _run(() async {
        await reorderShotReference(
          db: _db,
          shot: await _current(),
          reference: reference,
          to: to,
        );
        return false;
      });

  Future<void> _moveSketch(String path, int to) => _run(() async {
    await reorderShotPlanSketches(
      db: _db,
      shot: await _current(),
      path: path,
      to: to,
    );
    return false;
  });

  /// Copia una imagen al portapapeles, para pegarla en otra casilla.
  Future<void> _copy(String path) async {
    final done = await ClipboardImageReader.copyImageFile(path);
    if (!mounted) return;
    setState(() {
      _notice = done ? null : 'No se ha podido copiar la imagen.';
      _info = done ? 'Imagen copiada. Pégala con ⌘V sobre otra casilla.' : null;
    });
  }

  /// Quita uno de los bocetos de planta; el menú sigue abierto.
  Future<void> _removeSketch(String path) => _run(() async {
    await removeShotPlanSketch(db: _db, shot: await _current(), path: path);
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
    if (_sketch) {
      final db = _db;
      _shotChanges = (db.select(
        db.shots,
      )..where((s) => s.id.equals(widget.shot.id))).watchSingleOrNull();
    }
    if (widget.target == ShotImageTarget.reference) {
      // Una referencia antigua puede no tener fila propia: se le da para que
      // salga en la lista y se pueda quitar.
      // La base se coge ya: el menú puede cerrarse antes de acabar.
      final db = _db;
      final shot = widget.shot;
      _references = db.watchReferencesForShot(shot.id);
      () async {
        await ensureShotReferencesSynced(
          db: db,
          shot: await db.getShotById(shot.id) ?? shot,
        );
      }();
    }
  }

  Stream<List<ShotReference>>? _references;

  @override
  Widget build(BuildContext context) {
    if (_sketch) {
      return StreamBuilder<Shot?>(
        stream: _shotChanges,
        builder: (context, snap) {
          _sketches = [
            for (final entry in planSketchEntriesOf(snap.data ?? widget.shot))
              if (planSketchSetupId(entry) == null || widget.sketches != null)
                entry,
          ];
          return _dialog(context, const []);
        },
      );
    }
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
    final own = switch (widget.target) {
      ShotImageTarget.storyboard => widget.shot.storyboardImagePath,
      ShotImageTarget.planSketch =>
        _sketches.where((e) => planSketchSetupId(e) == null).firstOrNull,
      ShotImageTarget.reference => references.firstOrNull?.imagePath,
    };
    final path =
        own ??
        switch (widget.target) {
          ShotImageTarget.storyboard => widget.shot.referenceImagePath,
          ShotImageTarget.planSketch => null,
          ShotImageTarget.reference => widget.shot.storyboardImagePath,
        };
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
            // Con bocetos y opciones el menú crece: que se pueda recorrer.
            child: SingleChildScrollView(
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
                      _imageStrip(
                        [for (final r in references) r.imagePath],
                        onRemove: (i) => _removeReference(references[i]),
                        onMove: (from, to) =>
                            _moveReference(references[from], to),
                      ),
                    ],
                    if (_sketch && _sketches.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _imageStrip(
                        _sketches,
                        onRemove: (i) => _removeSketch(_sketches[i]),
                        onMove: (from, to) => _moveSketch(_sketches[from], to),
                      ),
                    ],
                    if (_sketch && widget.sketches != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      widget.sketches!.section(context, widget.shot),
                    ],
                    if (_sketch) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Una foto de la libreta o un esquema ya hecho: hace '
                        'de planta del plano mientras no esté dibujada, y '
                        'sale también en Plantas de cámara y luz.',
                        style: AppTypography.caption(palette),
                      ),
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
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : _draw,
                          icon: const Icon(Icons.draw_outlined, size: 18),
                          label: const Text('Dibujar'),
                        ),
                        // El dibujo del storyboard, como una referencia más
                        // del plano (sale en el guion técnico y al exportar).
                        if (!_story &&
                            !_sketch &&
                            widget.shot.storyboardImagePath != null &&
                            File(widget.shot.storyboardImagePath!).existsSync())
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : _useStoryboard,
                            icon: const Icon(Icons.movie_filter_outlined, size: 18),
                            label: const Text('Usar el dibujo del storyboard'),
                          ),
                        if (_story && hasOwn && isEditableSketch(own))
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : () => _draw(editing: own),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Editar dibujo'),
                          ),
                        if (!_story && !_sketch)
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
                  if (widget.footer != null && !_moodboard) ...[
                    const SizedBox(height: AppSpacing.md),
                    widget.footer!(context),
                  ],
                  if (_info != null && _notice == null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_info!, style: AppTypography.bodyMedium(palette)),
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
                          switch (widget.target) {
                            ShotImageTarget.storyboard =>
                              'Arrastra otra imagen aquí o pégala con ⌘V '
                                  'para cambiarla',
                            ShotImageTarget.planSketch =>
                              'Arrastra o pega con ⌘V más bocetos',
                            ShotImageTarget.reference =>
                              'Arrastra o pega con ⌘V más imágenes: una '
                                  'por encuadre',
                          },
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

  /// Las imágenes del plano en su orden, cada una con su «quitar».
  Widget _imageStrip(
    List<String> paths, {
    required void Function(int index) onRemove,
    required void Function(int from, int to) onMove,
  }) {
    Widget chip(String tooltip, IconData icon, VoidCallback? onTap) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: _busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: onTap == null ? 0.25 : 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: Colors.white),
          ),
        ),
      );
    }

    return SizedBox(
      height: 76,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        itemCount: paths.length,
        onReorderItem: onMove,
        itemBuilder: (context, i) {
          final path = paths[i];
          // Un boceto dibujado en la planta, no una imagen.
          final setupId = planSketchSetupId(path);
          return Padding(
            key: ValueKey(path),
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ReorderableDragStartListener(
                  index: i,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: setupId == null
                          ? Image.file(
                              File(path),
                              width: 124,
                              height: 76,
                              fit: BoxFit.cover,
                              cacheWidth: 300,
                            )
                          : Tooltip(
                              message: 'Abrir el boceto en la planta',
                              child: GestureDetector(
                                onTap: () => widget.sketches?.open(
                                  context,
                                  widget.shot,
                                  setupId,
                                ),
                                child: SizedBox(
                                  width: 124,
                                  height: 76,
                                  child: widget.sketches?.thumbnail(
                                    context,
                                    widget.shot,
                                    setupId,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 4,
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
                  child: chip(
                    'Quitar esta imagen',
                    Icons.close,
                    () => onRemove(i),
                  ),
                ),
                Positioned(
                  left: 2,
                  right: 2,
                  bottom: 2,
                  child: Row(
                    children: [
                      chip(
                        'Mover delante',
                        Icons.chevron_left,
                        i == 0 ? null : () => onMove(i, i - 1),
                      ),
                      const SizedBox(width: 2),
                      chip(
                        'Mover detrás',
                        Icons.chevron_right,
                        i == paths.length - 1 ? null : () => onMove(i, i + 1),
                      ),
                      const Spacer(),
                      if (setupId == null && isEditableSketch(path)) ...[
                        chip(
                          'Editar dibujo',
                          Icons.edit_outlined,
                          () => _draw(editing: path),
                        ),
                        const SizedBox(width: 2),
                      ],
                      if (setupId == null)
                        chip(
                          'Copiar esta imagen',
                          Icons.copy,
                          () => _copy(path),
                        ),
                    ],
                  ),
                ),
              ],
            ),
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
