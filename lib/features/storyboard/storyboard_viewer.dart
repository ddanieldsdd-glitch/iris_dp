import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/sync/editing_guard.dart';
import '../../core/sync/live_editing_scope.dart';
import '../../core/sync/realtime_hub.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/scene_format.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../shared/rich_text/script_markup.dart';
import '../../shared/shot_images/shot_image_menu.dart';
import '../camera_plan/camera_plan_grouping.dart';
import 'shot_frames_export_sheet.dart';

/// Abre el visor del storyboard en [shot]: los planos del proyecto uno a
/// uno, en orden de guion.
Future<void> showStoryboardViewer(
  BuildContext context, {
  required int projectId,
  required Shot shot,
  void Function(Shot shot)? onMore,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => StoryboardViewer(
        projectId: projectId,
        initialShotId: shot.id,
        onMore: onMore,
      ),
    ),
  );
}

/// Los planos en orden de guion: por escena y, dentro, por su orden.
List<({Scene scene, Shot shot})> storyboardSequence(
  List<Scene> scenes,
  List<Shot> shots,
) {
  final byScene = <int, List<Shot>>{};
  for (final shot in shots) {
    byScene.putIfAbsent(shot.sceneId, () => []).add(shot);
  }
  return [
    for (final scene in scenesInScriptOrder(scenes))
      for (final shot
          in (byScene[scene.id] ?? const <Shot>[]).toList()..sort((a, b) {
            final byOrder = a.sortOrder.compareTo(b.sortOrder);
            return byOrder != 0 ? byOrder : a.number.compareTo(b.number);
          }))
        (scene: scene, shot: shot),
  ];
}

/// Añade un plano al final de [scene]; [shots] son los que ya tiene.
Future<int> createStoryboardShot(
  AppDatabase db,
  Scene scene,
  List<Shot> shots, {
  String? title,
}) {
  final last = shots.fold<int>(
    -1,
    (max, s) => s.sortOrder > max ? s.sortOrder : max,
  );
  return db.insertShot(
    ShotsCompanion.insert(
      sceneId: scene.id,
      projectId: scene.projectId,
      number: shots.length + 1,
      sortOrder: Value(last + 1),
      framing: Value(title == null || title.trim().isEmpty ? null : title),
    ),
  );
}

/// Visor del storyboard. La barra de arriba es fija (título del plano y
/// «Cerrar»), y las flechas pasan de un plano al siguiente.
class StoryboardViewer extends ConsumerStatefulWidget {
  final int projectId;
  final int initialShotId;

  /// Más acciones del plano (exportar, documento de rodaje…).
  final void Function(Shot shot)? onMore;

  const StoryboardViewer({
    super.key,
    required this.projectId,
    required this.initialShotId,
    this.onMore,
  });

  @override
  ConsumerState<StoryboardViewer> createState() => _StoryboardViewerState();
}

class _StoryboardViewerState extends ConsumerState<StoryboardViewer> {
  late int _shotId = widget.initialShotId;

  /// Imagen elegida en la tira del plano; nula = la principal.
  String? _picked;

  void _go(List<({Scene scene, Shot shot})> sequence, int delta) {
    final index = sequence.indexWhere((e) => e.shot.id == _shotId);
    final next = index + delta;
    if (index < 0 || next < 0 || next >= sequence.length) return;
    setState(() {
      _shotId = sequence[next].shot.id;
      _picked = null;
    });
  }

  /// Crea un plano al final de la escena que se está viendo y salta a él:
  /// queda listo para ponerle título e imagen, y ya está en el guion técnico.
  Future<void> _newShot(
    Scene scene,
    List<({Scene scene, Shot shot})> sequence,
  ) async {
    final id = await createStoryboardShot(ref.read(databaseProvider), scene, [
      for (final e in sequence)
        if (e.scene.id == scene.id) e.shot,
    ]);
    if (!mounted) return;
    setState(() {
      _shotId = id;
      _picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<Scene>>(
      stream: db.watchScenesForProject(widget.projectId),
      builder: (context, scenes) => StreamBuilder<List<Shot>>(
        stream: db.watchShotsForProject(widget.projectId),
        builder: (context, shots) {
          if (!scenes.hasData || !shots.hasData) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return _page(storyboardSequence(scenes.data!, shots.data!));
        },
      ),
    );
  }

  Widget _page(List<({Scene scene, Shot shot})> sequence) {
    final palette = context.palette;
    var index = sequence.indexWhere((e) => e.shot.id == _shotId);
    if (index < 0) {
      // El plano ya no existe: se cierra.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(backgroundColor: Colors.black);
    }
    final (:scene, :shot) = sequence[index];
    final db = ref.read(databaseProvider);
    // Otro equipo edita este plano: aquí no se toca hasta que termine.
    final lockedBy = ref.watch(
      liveEditingProvider.select((l) => l.holderOf(shot.uid)?.device),
    );

    if (AppLayout.isCompact(context)) {
      return LiveEditingScope(
        child: _compactPage(sequence, index, scene, shot, lockedBy),
      );
    }

    return LiveEditingScope(child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _go(sequence, -1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _go(sequence, 1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                // Barra fija: nada de lo de abajo se le pone encima.
                Container(
                  color: palette.surfaceElevated,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Esc ${scene.label} · Plano ${shot.number}',
                            style: AppTypography.titleMedium(palette),
                          ),
                          Text(
                            '${locationFromCanonical(scene.locationCanonical)}'
                            ' · ${index + 1} de ${sequence.length}',
                            style: AppTypography.caption(palette),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      if (lockedBy != null) ...[
                        const Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: Color(0xFF7F77DD),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Editando en $lockedBy',
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(color: const Color(0xFF7F77DD)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: IgnorePointer(
                          ignoring: lockedBy != null,
                          child: _TitleField(
                          key: ValueKey('titulo_${shot.id}'),
                          initial: scriptMarkupToPlain(shot.framing),
                          // Escribiendo el título, el plano sale bloqueado en
                          // los demás equipos.
                          onFocusChanged: (focused) {
                            final live = ref.read(liveEditingProvider);
                            focused
                                ? live.focusShot(shot.uid)
                                : live.blurShot(shot.uid);
                          },
                          onChanged: (text) => db.updateShotFields(
                            shot.id,
                            ShotsCompanion(
                              framing: Value(text.isEmpty ? null : text),
                            ),
                          ),
                        ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      TextButton.icon(
                        onPressed: lockedBy != null
                            ? null
                            : () async {
                                // Dibujando o cambiando la imagen, el plano
                                // sale bloqueado en los demás equipos.
                                final live = ref.read(liveEditingProvider);
                                live.focusShot(shot.uid);
                                await showShotImageMenu(
                                  context,
                                  shot,
                                  target: ShotImageTarget.storyboard,
                                );
                                live.blurShot(shot.uid);
                              },
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: const Text('Imagen'),
                      ),
                      TextButton.icon(
                        onPressed: () => showShotFramesExportSheet(
                          context,
                          scene: scene,
                          shot: shot,
                        ),
                        icon: const Icon(Icons.ios_share, size: 18),
                        label: const Text('Exportar'),
                      ),
                      TextButton.icon(
                        onPressed: () => _newShot(scene, sequence),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Plano nuevo'),
                      ),
                      if (widget.onMore != null)
                        IconButton(
                          tooltip: 'Más opciones del plano',
                          icon: const Icon(Icons.more_horiz),
                          onPressed: () => widget.onMore!(shot),
                        ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton.tonalIcon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cerrar'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _arrow(
                        'Plano anterior (←)',
                        Icons.chevron_left,
                        index > 0 ? () => _go(sequence, -1) : null,
                      ),
                      Expanded(child: _image(shot)),
                      _arrow(
                        'Plano siguiente (→)',
                        Icons.chevron_right,
                        index < sequence.length - 1
                            ? () => _go(sequence, 1)
                            : null,
                      ),
                    ],
                  ),
                ),
                _strip(shot),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  final _zoom = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  /// El visor en el iPhone (IP.2.2): barra corta con menú, la imagen a lo
  /// ancho (deslizar para pasar de plano, pellizcar para ampliar) y debajo
  /// la ficha del plano.
  Widget _compactPage(
    List<({Scene scene, Shot shot})> sequence,
    int index,
    Scene scene,
    Shot shot,
    String? lockedBy,
  ) {
    final palette = context.palette;
    final db = ref.read(databaseProvider);
    final body = AppTypography.bodyMedium(
      palette,
    ).copyWith(color: palette.textPrimary);
    final optics = [
      shot.lens,
      shot.angle,
      shot.movement,
      shot.fStop,
    ].where((v) => v != null && v.trim().isNotEmpty).join(' · ');
    void go(int delta) {
      _zoom.value = Matrix4.identity();
      _zoomed = false;
      _go(sequence, delta);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: palette.surfaceElevated,
        titleSpacing: AppSpacing.md,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esc ${scene.label} · Plano ${shot.number}',
              style: AppTypography.titleMedium(palette),
            ),
            Text(
              '${index + 1} de ${sequence.length}',
              style: AppTypography.caption(palette),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Más',
            onSelected: (v) async {
              switch (v) {
                case 'image':
                  await showShotImageMenu(
                    context,
                    shot,
                    target: ShotImageTarget.storyboard,
                  );
                case 'export':
                  await showShotFramesExportSheet(
                    context,
                    scene: scene,
                    shot: shot,
                  );
                case 'new':
                  await _newShot(scene, sequence);
                case 'more':
                  widget.onMore?.call(shot);
              }
            },
            itemBuilder: (_) => [
              if (lockedBy == null)
                const PopupMenuItem(value: 'image', child: Text('Imagen')),
              const PopupMenuItem(value: 'export', child: Text('Exportar')),
              const PopupMenuItem(value: 'new', child: Text('Plano nuevo')),
              if (widget.onMore != null)
                const PopupMenuItem(value: 'more', child: Text('Más opciones')),
            ],
          ),
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            GestureDetector(
              // Sin ampliar, deslizar pasa de plano; ampliada, se mueve.
              onHorizontalDragEnd: _zoomed
                  ? null
                  : (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v < -200) go(1);
                      if (v > 200) go(-1);
                    },
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _compactImage(shot),
              ),
            ),
            _strip(shot),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppLayout.gutter(context),
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    locationFromCanonical(scene.locationCanonical),
                    style: AppTypography.caption(palette),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  IgnorePointer(
                    ignoring: lockedBy != null,
                    child: _TitleField(
                      key: ValueKey('titulo_${shot.id}'),
                      initial: scriptMarkupToPlain(shot.framing),
                      onFocusChanged: (focused) {
                        final live = ref.read(liveEditingProvider);
                        focused
                            ? live.focusShot(shot.uid)
                            : live.blurShot(shot.uid);
                      },
                      onChanged: (text) => db.updateShotFields(
                        shot.id,
                        ShotsCompanion(
                          framing: Value(text.isEmpty ? null : text),
                        ),
                      ),
                    ),
                  ),
                  if (lockedBy != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Editando en $lockedBy',
                        style: AppTypography.caption(
                          palette,
                        ).copyWith(color: const Color(0xFF7F77DD)),
                      ),
                    ),
                  if (optics.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(optics, style: AppTypography.mono(palette)),
                  ],
                  if ((shot.action ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(scriptMarkupToPlain(shot.action), style: body),
                  ],
                  if ((shot.notes ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      scriptMarkupToPlain(shot.notes),
                      style: AppTypography.caption(palette),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: index > 0 ? () => go(-1) : null,
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('Anterior'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: index < sequence.length - 1
                              ? () => go(1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('Siguiente'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactImage(Shot shot) {
    final path = _picked ?? storyboardImageOf(shot);
    if (path == null || !File(path).existsSync()) return _image(shot);
    return InteractiveViewer(
      transformationController: _zoom,
      minScale: 1,
      maxScale: 4,
      panEnabled: _zoomed,
      onInteractionEnd: (_) {
        final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
        if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
      },
      child: Center(
        child: Image.file(File(path), fit: BoxFit.contain, cacheWidth: 1600),
      ),
    );
  }

  Widget _arrow(String tooltip, IconData icon, VoidCallback? onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 28),
      ),
    );
  }

  Widget _image(Shot shot) {
    final palette = context.palette;
    final path = _picked ?? storyboardImageOf(shot);
    if (path == null || !File(path).existsSync()) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 48,
              color: palette.textTertiary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Este plano aún no tiene imagen',
              style: AppTypography.bodyMedium(
                palette,
              ).copyWith(color: Colors.white70),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => showShotImageMenu(
                context,
                shot,
                target: ShotImageTarget.storyboard,
              ),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('Elegir o dibujar una imagen'),
            ),
          ],
        ),
      );
    }
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(child: Image.file(File(path), fit: BoxFit.contain)),
    );
  }

  /// Las imágenes del plano (la del storyboard y sus referencias): tocar
  /// una la enseña grande.
  Widget _strip(Shot shot) {
    final palette = context.palette;
    final db = ref.read(databaseProvider);
    return StreamBuilder<List<ShotReference>>(
      stream: db.watchReferencesForShot(shot.id),
      builder: (context, snap) {
        final paths = <String>{
          if (shot.storyboardImagePath case final own?)
            if (File(own).existsSync()) own,
          ...referenceImagesOf(shot, snap.data ?? const []),
        }.toList();
        if (paths.length < 2) return const SizedBox(height: AppSpacing.md);
        final current = _picked ?? storyboardImageOf(shot);
        return Container(
          height: 76,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: paths.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) => InkWell(
              onTap: () => setState(() => _picked = paths[i]),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: paths[i] == current
                        ? palette.accent
                        : Colors.transparent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  File(paths[i]),
                  width: 96,
                  fit: BoxFit.cover,
                  cacheWidth: 300,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// El título del plano: su encuadre, el mismo del guion técnico. Se guarda
/// al salir del campo o con Intro.
class _TitleField extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool>? onFocusChanged;

  const _TitleField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.onFocusChanged,
  });

  @override
  State<_TitleField> createState() => _TitleFieldState();
}

class _TitleFieldState extends State<_TitleField> {
  late final _ctrl = TextEditingController(text: widget.initial);
  late String _saved = widget.initial;

  void _commit() {
    final text = _ctrl.text.trim();
    if (text == _saved) return;
    _saved = text;
    widget.onChanged(text);
  }

  /// Mientras se escribe no se baja nada de la nube.
  VoidCallback? _releaseGuard;

  @override
  void dispose() {
    _commit();
    _releaseGuard?.call();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Focus(
      onFocusChange: (focused) {
        widget.onFocusChanged?.call(focused);
        if (focused) {
          _releaseGuard ??= EditingGuard.hold();
          return;
        }
        _commit();
        _releaseGuard?.call();
        _releaseGuard = null;
      },
      child: TextField(
        controller: _ctrl,
        style: AppTypography.titleMedium(palette),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _commit(),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Título del plano (encuadre): «PP de ALI»',
          hintStyle: AppTypography.bodyMedium(
            palette,
          ).copyWith(color: palette.textTertiary),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
