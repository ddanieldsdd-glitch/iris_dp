import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../core/utils/scene_format.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../core/utils/scene_characters.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_button.dart';
import '../camera_plan/camera_plan_status_cell.dart';
import '../goodnotes/goodnotes_pdf_actions.dart';
import '../look_bible/look_bible_model.dart';
import '../../shared/pdf_export/technical_script_pdf.dart';
import 'scene_form_sheet.dart';
import '../../core/utils/shot_technical_options.dart';
import '../../core/widgets/inline_edit_field.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/scene_meta_display.dart';

// Re-export para compatibilidad con imports existentes.
const kMovements = kShotMovements;
const kAngles = kShotAngles;

class TechnicalScriptScreen extends ConsumerWidget {
  final int projectId;
  const TechnicalScriptScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('Guion técnico', style: AppTypography.titleLarge(palette)),
        actions: [
          GoodNotesPdfActions(
            projectId: projectId,
            moduleType: GoodNotesModuleType.guionTecnico,
            filenameBase: 'guion_tecnico',
            buildPdfBytes: () async {
              final db = ref.read(databaseProvider);
              final project = await db.getProject(projectId);
              if (project == null) return Uint8List(0);
              final scenes = await db.watchScenesForProject(projectId).first;
              final shotsByScene = <int, List<Shot>>{};
              for (final scene in scenes) {
                shotsByScene[scene.id] = await db
                    .watchShotsForScene(scene.id)
                    .first;
              }
              return TechnicalScriptPdfExporter.buildBytes(
                project: project,
                scenes: scenes,
                shotsByScene: shotsByScene,
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf_outlined, color: palette.accent),
            onPressed: () => _exportPdf(context, ref),
          ),
          IconButton(
            tooltip: 'Añadir escena',
            icon: Icon(Icons.add, color: palette.accent),
            onPressed: () => showSceneFormSheet(context, projectId: projectId),
          ),
        ],
      ),
      body: StreamBuilder<List<Scene>>(
        stream: db.watchScenesForProject(projectId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final scenes = snap.data!;
          if (scenes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sin escenas. Importa el guion o añade una manualmente.',
                    style: AppTypography.bodyMedium(palette),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Añadir escena',
                    icon: Icons.add,
                    onTap: () =>
                        showSceneFormSheet(context, projectId: projectId),
                  ),
                ],
              ),
            );
          }
          return StreamBuilder<List<LocationSite>>(
            stream: db.watchSitesForProject(projectId),
            builder: (context, siteSnap) {
              return StreamBuilder<List<LocationBasePlan>>(
                stream: db.watchLocationsForProject(projectId),
                builder: (context, locSnap) {
                  final colors = ProjectColorScheme.resolve(
                    sites: siteSnap.data ?? [],
                    sets: locSnap.data ?? [],
                    scenes: scenes,
                  );
                  return StreamBuilder<List<Shot>>(
                    stream: db.watchShotsForProject(projectId),
                    builder: (context, shotSnap) {
                      final shotsByScene = <int, List<Shot>>{};
                      for (final shot in shotSnap.data ?? const <Shot>[]) {
                        shotsByScene
                            .putIfAbsent(shot.sceneId, () => [])
                            .add(shot);
                      }
                      return _ScriptTable(
                        scenes: scenes,
                        shotsByScene: shotsByScene,
                        colors: colors,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    try {
      final project = await db.getProject(projectId);
      if (project == null) return;

      final scenes = await db.watchScenesForProject(projectId).first;
      if (scenes.isEmpty) {
        if (!context.mounted) return;
        AppSnackBar.show(context, 'No hay escenas para exportar.');
        return;
      }

      final shotsByScene = <int, List<Shot>>{};
      for (final scene in scenes) {
        shotsByScene[scene.id] = await db.watchShotsForScene(scene.id).first;
      }

      final path = await TechnicalScriptPdfExporter.exportAndSave(
        project: project,
        scenes: scenes,
        shotsByScene: shotsByScene,
      );

      if (!context.mounted) return;
      if (path != null) {
        AppSnackBar.show(context, 'PDF guardado en $path');
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.show(context, userFriendlyError(e));
    }
  }
}

/// Tabla del guion técnico: cabecera de columnas fija y una sección por
/// escena. Ocupa todo el ancho; por debajo del mínimo, se desplaza entera.
class _ScriptTable extends StatelessWidget {
  final List<Scene> scenes;
  final Map<int, List<Shot>> shotsByScene;
  final ProjectColorScheme colors;

  const _ScriptTable({
    required this.scenes,
    required this.shotsByScene,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          constraints.maxWidth,
          AppLayout.technicalScriptTableWidth,
        );
        final cols = _Cols.forWidth(width);
        final table = Column(
          children: [
            _TableHeader(cols: cols),
            Expanded(
              child: ListView.builder(
                itemCount: scenes.length,
                itemBuilder: (context, i) => _SceneSection(
                  key: ValueKey(scenes[i].id),
                  scene: scenes[i],
                  shots: shotsByScene[scenes[i].id] ?? const [],
                  colors: colors,
                  cols: cols,
                ),
              ),
            ),
          ],
        );
        if (width <= constraints.maxWidth) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: table,
          ),
        );
      },
    );
  }
}

/// Anchos de columna para un ancho de tabla dado. Los mínimos suman
/// [AppLayout.technicalScriptTableWidth]; lo que sobra se reparte entre las
/// columnas de texto largo y la referencia.
class _Cols {
  final double handle;
  final double esc;
  final double plano;
  final double encuadre;
  final double lens;
  final double fStop;
  final double personajes;
  final double duracion;
  final double action;
  final double referencia;
  final double planta;
  final double apuntes;
  final double acciones;

  const _Cols._({
    required this.handle,
    required this.esc,
    required this.plano,
    required this.encuadre,
    required this.lens,
    required this.fStop,
    required this.personajes,
    required this.duracion,
    required this.action,
    required this.referencia,
    required this.planta,
    required this.apuntes,
    required this.acciones,
  });

  factory _Cols.forWidth(double width) {
    final extra = math.max(0.0, width - AppLayout.technicalScriptTableWidth);
    double grow(double base, int weight) => base + extra * weight / 12;
    return _Cols._(
      handle: 28,
      esc: 40,
      plano: 52,
      encuadre: grow(130, 3),
      lens: 150,
      fStop: 52,
      personajes: 110,
      duracion: 56,
      action: grow(160, 5),
      referencia: grow(104, 1),
      planta: 64,
      apuntes: grow(120, 3),
      acciones: 80,
    );
  }
}

Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final palette = context.palette;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(title, style: AppTypography.titleMedium(palette)),
      content: Text(body, style: AppTypography.bodyMedium(palette)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            'Eliminar',
            style: AppTypography.bodyMedium(
              palette,
            ).copyWith(color: palette.error),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class _SceneSection extends ConsumerStatefulWidget {
  final Scene scene;
  final List<Shot> shots;
  final ProjectColorScheme colors;
  final _Cols cols;

  const _SceneSection({
    super.key,
    required this.scene,
    required this.shots,
    required this.colors,
    required this.cols,
  });

  @override
  ConsumerState<_SceneSection> createState() => _SceneSectionState();
}

class _SceneSectionState extends ConsumerState<_SceneSection> {
  /// Orden recién soltado, mientras la base de datos no lo devuelve.
  List<int>? _pendingOrder;

  @override
  void didUpdateWidget(_SceneSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pending = _pendingOrder;
    if (pending == null) return;
    final ids = [for (final s in widget.shots) s.id];
    if (listEquals(ids, pending) || ids.length != pending.length) {
      _pendingOrder = null;
    }
  }

  List<Shot> get _orderedShots {
    final pending = _pendingOrder;
    if (pending == null) return widget.shots;
    final byId = {for (final s in widget.shots) s.id: s};
    if (pending.any((id) => !byId.containsKey(id))) return widget.shots;
    return [for (final id in pending) byId[id]!];
  }

  /// Coloca el plano arrastrado delante del que ocupa [beforeIndex]
  /// (`shots.length` = al final).
  void _moveBefore(List<Shot> shots, int draggedId, int beforeIndex) {
    final ids = [for (final s in shots) s.id];
    final from = ids.indexOf(draggedId);
    if (from < 0) return;
    final to = beforeIndex > from ? beforeIndex - 1 : beforeIndex;
    if (to == from) return;
    ids.insert(to, ids.removeAt(from));
    setState(() => _pendingOrder = ids);
    ref.read(databaseProvider).reorderShotsInScene(widget.scene.id, ids);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final palette = context.palette;
    final scene = widget.scene;
    final shots = _orderedShots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SceneHeader(
          scene: scene,
          shotCount: shots.length,
          colors: widget.colors,
        ),
        // Columna con claves y no una lista reordenable: al cambiar el orden
        // las filas se mueven sin desmontarse, y lo que tengan a medias (foco,
        // avisos, menús) sigue en su sitio.
        for (var i = 0; i < shots.length; i++)
          _ShotDropTarget(
            key: ValueKey(shots[i].id),
            sceneId: scene.id,
            shotId: shots[i].id,
            onDrop: (draggedId) => _moveBefore(shots, draggedId, i),
            child: _ShotRow(shot: shots[i], scene: scene, cols: widget.cols),
          ),
        _ShotDropTarget(
          sceneId: scene.id,
          shotId: null,
          onDrop: (draggedId) => _moveBefore(shots, draggedId, shots.length),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => db.insertShot(
                ShotsCompanion.insert(
                  sceneId: scene.id,
                  projectId: scene.projectId,
                  number: shots.length + 1,
                  sortOrder: Value(shots.length),
                ),
              ),
              icon: Icon(Icons.add, color: palette.accent, size: 16),
              label: Text(
                'Añadir plano',
                style: AppTypography.label(
                  palette,
                ).copyWith(color: palette.accent),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _SceneHeader extends ConsumerWidget {
  final Scene scene;
  final int shotCount;
  final ProjectColorScheme colors;

  const _SceneHeader({
    required this.scene,
    required this.shotCount,
    required this.colors,
  });

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final planos = switch (shotCount) {
      0 => 'No tiene planos.',
      1 => 'Se borra también su plano, con su referencia y su planta.',
      _ =>
        'Se borran también sus $shotCount planos, con sus referencias y sus '
            'plantas.',
    };
    final ok = await _confirmDelete(
      context,
      title: 'Eliminar la escena ${scene.number}',
      body: '$planos Las demás escenas conservan su número.',
    );
    if (!ok) return;
    try {
      await ref.read(databaseProvider).deleteScene(scene.id);
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, userFriendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final accent = colors.sceneColor(scene);
    final locationName = locationFromCanonical(scene.locationCanonical);

    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border(
          left: BorderSide(color: accent, width: 5),
          bottom: BorderSide(color: palette.divider),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(top: 4, right: AppSpacing.sm),
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SceneMetaDisplay(
                  intExt: scene.intExt,
                  dayNight: scene.dayNight,
                  location: locationName,
                  style: AppTypography.titleMedium(
                    palette,
                  ).copyWith(color: palette.textPrimary, letterSpacing: 0.5),
                  iconSize: 18,
                ),
                if (scene.description != null &&
                    scene.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    scene.description!,
                    style: AppTypography.bodyMedium(
                      palette,
                    ).copyWith(color: palette.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar escena',
            icon: Icon(
              Icons.edit_outlined,
              color: palette.textSecondary,
              size: 18,
            ),
            onPressed: () => showSceneFormSheet(
              context,
              projectId: scene.projectId,
              scene: scene,
            ),
          ),
          IconButton(
            tooltip: 'Eliminar escena',
            icon: Icon(
              Icons.delete_outline,
              color: palette.textSecondary,
              size: 18,
            ),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final _Cols cols;
  const _TableHeader({required this.cols});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      child: Row(
        children: [
          _HeaderCell('', cols.handle, palette),
          _HeaderCell('ESC', cols.esc, palette),
          _HeaderCell('PLANO', cols.plano, palette),
          _HeaderCell('ENCUADRE', cols.encuadre, palette),
          _HeaderCell('LENTE / MOV / ANG', cols.lens, palette),
          _HeaderCell('F', cols.fStop, palette),
          _HeaderCell('PERS.', cols.personajes, palette),
          _HeaderCell('DUR.', cols.duracion, palette),
          _HeaderCell('ACCIÓN', cols.action, palette),
          _HeaderCell('REFERENCIA', cols.referencia, palette),
          _HeaderCell('PLANTA', cols.planta, palette),
          _HeaderCell('APUNTES', cols.apuntes, palette),
          _HeaderCell('', cols.acciones, palette, last: true),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final AppPalette palette;
  final bool last;

  const _HeaderCell(this.text, this.width, this.palette, {this.last = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(right: BorderSide(color: palette.divider, width: 0.5)),
      ),
      child: Text(
        text,
        style: AppTypography.caption(palette),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Celda de la tabla: línea a la derecha y, si lo que contiene tiene el foco,
/// borde de acento.
class _Cell extends StatelessWidget {
  final double width;
  final Widget child;
  final EdgeInsets padding;
  final bool last;

  const _Cell({
    required this.width,
    required this.child,
    this.padding = const EdgeInsets.all(6),
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: Builder(
        builder: (context) {
          // Depender del foco así repinta la celda sin `setState`, también
          // cuando la fila cambia de sitio en mitad de un arrastre.
          final focused = Focus.of(context).hasFocus;
          return Container(
            width: width,
            padding: padding,
            foregroundDecoration: BoxDecoration(
              border: focused
                  ? Border.all(color: palette.accent, width: 1.5)
                  : last
                  ? null
                  : Border(
                      right: BorderSide(color: palette.divider, width: 0.5),
                    ),
            ),
            child: Align(alignment: Alignment.topLeft, child: child),
          );
        },
      ),
    );
  }
}

const double _kRowMinHeight = 104;

/// Plano que se está arrastrando para cambiarlo de sitio en su escena.
class _ShotDrag {
  final int shotId;
  final int sceneId;
  const _ShotDrag({required this.shotId, required this.sceneId});
}

/// Hueco donde soltar un plano: delante de [child]. Marca con una línea de
/// acento dónde va a caer.
class _ShotDropTarget extends StatelessWidget {
  final int sceneId;

  /// Plano de esta fila; nulo en el hueco del final de la escena.
  final int? shotId;
  final ValueChanged<int> onDrop;
  final Widget child;

  const _ShotDropTarget({
    super.key,
    required this.sceneId,
    required this.shotId,
    required this.onDrop,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DragTarget<_ShotDrag>(
      onWillAcceptWithDetails: (d) =>
          d.data.sceneId == sceneId && d.data.shotId != shotId,
      onAcceptWithDetails: (d) => onDrop(d.data.shotId),
      builder: (context, candidates, rejected) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: candidates.isEmpty
              ? null
              : Border(top: BorderSide(color: palette.accent, width: 2)),
        ),
        child: child,
      ),
    );
  }
}

/// Alto fijo para los desplegables: el que calculan por adelantado es menor
/// que el que acaban ocupando, y la fila se quedaba corta.
Widget _dropdownBox(Widget dropdown) => SizedBox(height: 24, child: dropdown);

class _ShotRow extends ConsumerWidget {
  final Shot shot;
  final Scene scene;
  final _Cols cols;

  const _ShotRow({required this.shot, required this.scene, required this.cols});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final palette = context.palette;

    final highlightColor = switch (shot.notesHighlight) {
      'green' => palette.highlightGreen,
      'yellow' => palette.highlightYellow,
      'red' => palette.highlightRed,
      _ => null,
    };

    return Container(
      decoration: BoxDecoration(
        color: highlightColor,
        border: Border(bottom: BorderSide(color: palette.divider, width: 0.5)),
      ),
      child: IntrinsicHeight(
        // El mínimo deja sitio a la celda de lente (texto y dos desplegables)
        // aunque su alto calculado por adelantado se quede corto.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRowMinHeight),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cell(
                width: cols.handle,
                padding: EdgeInsets.zero,
                child: Draggable<_ShotDrag>(
                  data: _ShotDrag(shotId: shot.id, sceneId: scene.id),
                  axis: Axis.vertical,
                  dragAnchorStrategy: pointerDragAnchorStrategy,
                  // El texto a medias se guarda antes de mover la fila.
                  onDragStarted: () =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  feedback: Material(
                    color: palette.surfaceElevated,
                    elevation: 6,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        'Plano ${shot.number}'
                        '${(shot.framing ?? '').trim().isEmpty ? '' : ' · ${shot.framing!.trim()}'}',
                        style: AppTypography.bodyMedium(
                          palette,
                        ).copyWith(color: palette.textPrimary),
                      ),
                    ),
                  ),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Tooltip(
                      message: 'Arrastra para cambiar el orden',
                      child: SizedBox(
                        width: cols.handle,
                        height: 32,
                        child: Icon(
                          Icons.drag_indicator,
                          size: 16,
                          color: palette.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _Cell(
                width: cols.esc,
                child: Text(
                  '${scene.number}',
                  style: AppTypography.mono(palette),
                ),
              ),
              _Cell(
                width: cols.plano,
                child: Text(
                  '${shot.number}',
                  style: AppTypography.mono(
                    palette,
                  ).copyWith(color: palette.accent),
                ),
              ),
              _Cell(
                width: cols.encuadre,
                child: InlineEditField(
                  flat: true,
                  value: shot.framing,
                  hint: 'PD, PMC...',
                  palette: palette,
                  minLines: 2,
                  onChanged: (v) => db.updateShotFields(
                    shot.id,
                    ShotsCompanion(framing: Value(v)),
                  ),
                ),
              ),
              _Cell(
                width: cols.lens,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InlineEditField(
                      flat: true,
                      value: shot.lens,
                      hint: '50mm',
                      palette: palette,
                      onChanged: (v) => db.updateShotFields(
                        shot.id,
                        ShotsCompanion(lens: Value(v)),
                      ),
                    ),
                    _dropdownBox(
                      InlineDropdownField(
                        value: shot.movement,
                        options: kMovements,
                        hint: '—',
                        palette: palette,
                        onChanged: (v) => db.updateShotFields(
                          shot.id,
                          ShotsCompanion(movement: Value(v)),
                        ),
                      ),
                    ),
                    _dropdownBox(
                      InlineDropdownField(
                        value: shot.angle,
                        options: kAngles,
                        hint: '—',
                        palette: palette,
                        onChanged: (v) => db.updateShotFields(
                          shot.id,
                          ShotsCompanion(angle: Value(v)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _Cell(
                width: cols.fStop,
                child: InlineEditField(
                  flat: true,
                  value: shot.fStop,
                  hint: 'T2.8',
                  palette: palette,
                  onChanged: (v) => db.updateShotFields(
                    shot.id,
                    ShotsCompanion(fStop: Value(v)),
                  ),
                ),
              ),
              _Cell(
                width: cols.personajes,
                child: InlineEditField(
                  flat: true,
                  value: decodeSceneCharacters(shot.charactersJson).join(', '),
                  hint: 'Ana, Luis…',
                  palette: palette,
                  minLines: 2,
                  onChanged: (v) => db.updateShotFields(
                    shot.id,
                    ShotsCompanion(
                      charactersJson: Value(
                        encodeSceneCharacters(parseCharactersInput(v)),
                      ),
                    ),
                  ),
                ),
              ),
              _Cell(
                width: cols.duracion,
                child: InlineEditField(
                  flat: true,
                  value: shot.durationSeconds?.toString(),
                  hint: 'seg',
                  palette: palette,
                  onChanged: (v) => db.updateShotFields(
                    shot.id,
                    ShotsCompanion(
                      durationSeconds: Value(int.tryParse(v.trim())),
                    ),
                  ),
                ),
              ),
              _Cell(
                width: cols.action,
                child: InlineEditField(
                  flat: true,
                  value: shot.action,
                  hint: 'Descripción de la acción...',
                  minLines: 3,
                  palette: palette,
                  onChanged: (v) => db.updateShotFields(
                    shot.id,
                    ShotsCompanion(action: Value(v)),
                  ),
                ),
              ),
              _Cell(
                width: cols.referencia,
                padding: const EdgeInsets.all(4),
                child: SizedBox(
                  width: double.infinity,
                  child: _ReferenceCell(shot: shot),
                ),
              ),
              _Cell(
                width: cols.planta,
                padding: const EdgeInsets.all(4),
                child: SizedBox(
                  width: double.infinity,
                  child: CameraPlanStatusCell(
                    shot: shot,
                    sceneNumber: scene.number,
                    scene: scene,
                  ),
                ),
              ),
              _Cell(
                width: cols.apuntes,
                child: InlineEditField(
                  flat: true,
                  value: shot.notes,
                  hint: 'Apuntes...',
                  minLines: 3,
                  palette: palette,
                  onChanged: (v) => db.updateShotFields(
                    shot.id,
                    ShotsCompanion(notes: Value(v)),
                  ),
                ),
              ),
              _Cell(
                width: cols.acciones,
                last: true,
                child: _ActionsCell(shot: shot, scene: scene),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Color de la fila y acciones del plano: añadir al documento y eliminar.
class _ActionsCell extends ConsumerWidget {
  final Shot shot;
  final Scene scene;

  const _ActionsCell({required this.shot, required this.scene});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await _confirmDelete(
      context,
      title: 'Eliminar el plano ${shot.number}',
      body:
          'Se borran también sus referencias y su planta, y se quita de los '
          'documentos de rodaje. Los planos siguientes se renumeran.',
    );
    if (!ok) return;
    try {
      await ref.read(databaseProvider).deleteShot(shot.id);
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, userFriendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final palette = context.palette;

    Widget dot(String? value, Color color) => _HighlightDot(
      color: color,
      selected: shot.notesHighlight == value,
      onTap: () => db.updateShotFields(
        shot.id,
        ShotsCompanion(notesHighlight: Value(value)),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot('green', palette.highlightGreen),
            const SizedBox(width: 4),
            dot('yellow', palette.highlightYellow),
            const SizedBox(width: 4),
            dot('red', palette.highlightRed),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HighlightDot(
              color: palette.divider,
              selected: shot.notesHighlight == null,
              onTap: () => db.updateShotFields(
                shot.id,
                const ShotsCompanion(notesHighlight: Value(null)),
              ),
              icon: Icons.close,
              size: 10,
            ),
            const SizedBox(width: 6),
            _RowAction(
              tooltip: 'Eliminar plano',
              icon: Icons.delete_outline,
              color: palette.textSecondary,
              onTap: () => _delete(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}

class _RowAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RowAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 14,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _HighlightDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final double size;

  const _HighlightDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size + 6,
        height: size + 6,
        decoration: BoxDecoration(
          color: icon != null
              ? null
              : color.withValues(alpha: selected ? 1 : 0.35),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : color,
            width: selected ? 2 : 1,
          ),
        ),
        child: icon != null
            ? Icon(icon, size: size, color: context.palette.textTertiary)
            : null,
      ),
    );
  }
}

class _ReferenceCell extends ConsumerWidget {
  final Shot shot;
  const _ReferenceCell({required this.shot});

  Future<void> _import(
    BuildContext context,
    WidgetRef ref, {
    required String source,
  }) async {
    final db = ref.read(databaseProvider);
    try {
      await pickAndImportShotReference(
        db: db,
        shot: shot,
        source: source,
        dialogTitle: 'Referencia · Plano ${shot.number}',
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(context, userFriendlyError(e));
      }
    }
  }

  void _showImportOptions(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surfaceElevated,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Referencia · Plano ${shot.number}',
                style: AppTypography.titleMedium(palette),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading: Icon(
                  Icons.photo_camera_outlined,
                  color: palette.accent,
                ),
                title: Text(
                  'Captura Artemis',
                  style: AppTypography.bodyLarge(palette),
                ),
                subtitle: Text(
                  'Exportada desde la app Artemis',
                  style: AppTypography.caption(palette),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _import(
                    context,
                    ref,
                    source: ShotReferenceSource.artemisCapture,
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: palette.textSecondary,
                ),
                title: Text(
                  'Imagen manual',
                  style: AppTypography.bodyLarge(palette),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _import(context, ref, source: ShotReferenceSource.manual);
                },
              ),
              ListTile(
                leading: Icon(Icons.view_in_ar_outlined, color: palette.accent),
                title: Text(
                  'Render Unreal',
                  style: AppTypography.bodyLarge(palette),
                ),
                subtitle: Text(
                  'Frame PNG del Movie Render Queue',
                  style: AppTypography.caption(palette),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _import(
                    context,
                    ref,
                    source: ShotReferenceSource.unrealRender,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeImage(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final path = shot.referenceImagePath;
    if (path == null) return;

    final refs = await db.watchReferencesForShot(shot.id).first;
    ShotReference? match;
    for (final r in refs) {
      if (r.imagePath == path) {
        match = r;
        break;
      }
    }

    try {
      if (match != null) {
        final current = await db.getShotById(shot.id) ?? shot;
        await deleteShotReferenceEntry(db: db, shot: current, reference: match);
      } else {
        await db.updateShot(
          shot.copyWith(referenceImagePath: const Value(null)),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.show(context, userFriendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final path = shot.referenceImagePath;
    final hasImage = path != null && File(path).existsSync();

    return GestureDetector(
      onTap: () => _showImportOptions(context, ref),
      onLongPress: hasImage ? () => _removeImage(context, ref) : null,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: palette.surfaceOverlay.withValues(alpha: 0.4),
          border: Border.all(color: palette.divider),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(path), fit: BoxFit.cover),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_camera_outlined,
                    color: palette.textTertiary,
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ref.',
                    style: AppTypography.caption(palette),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}
