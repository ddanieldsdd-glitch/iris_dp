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

/// Guion técnico: una tabla por escena, como hojas de un documento. Ocupa todo el ancho; por debajo del mínimo, se desplaza entera.
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
        final table = ListView.builder(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          itemCount: scenes.length,
          itemBuilder: (context, i) => _SceneSection(
            key: ValueKey(scenes[i].id),
            scene: scenes[i],
            shots: shotsByScene[scenes[i].id] ?? const [],
            colors: colors,
            cols: cols,
          ),
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
        const SizedBox(height: AppSpacing.sm),
        _TableHeader(cols: widget.cols),
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

/// Colores de la hoja del guion técnico. Es papel: no cambian con el tema de
/// la app, para que la pantalla se parezca al PDF y al Word.
abstract final class ScriptSheetColors {
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111111);
  static const hint = Color(0xFFB0B0B0);
  static const border = Color(0xFF000000);
  static const header = Color(0xFFFCE5CD);
  static const tile = Color(0xFFF2F2F2);
  static const tileBorder = Color(0xFFCFCFCF);

  /// Color de celda según `notesHighlight`.
  static Color? highlight(String? value) => switch (value) {
    'green' => const Color(0xFFD9EAD3),
    'yellow' => const Color(0xFFFFF2CC),
    'red' => const Color(0xFFF4CCCC),
    _ => null,
  };

  static TextStyle text(AppPalette palette) =>
      AppTypography.bodyMedium(palette).copyWith(color: ink);

  static TextStyle hintText(AppPalette palette) =>
      AppTypography.bodyMedium(palette).copyWith(color: hint);
}

const _sheetSide = BorderSide(color: ScriptSheetColors.border);

/// Fila de títulos de columna, una por escena, como en el Word.
class _TableHeader extends StatelessWidget {
  final _Cols cols;
  const _TableHeader({required this.cols});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        SizedBox(width: cols.handle),
        Container(
          decoration: const BoxDecoration(
            color: ScriptSheetColors.header,
            border: Border(
              top: _sheetSide,
              left: _sheetSide,
              bottom: _sheetSide,
            ),
          ),
          child: Row(
            children: [
              _HeaderCell('ESC', cols.esc, palette),
              _HeaderCell('PLANO', cols.plano, palette),
              _HeaderCell('Encuadre', cols.encuadre, palette),
              _HeaderCell('LENTE/ANG/MOV', cols.lens, palette),
              _HeaderCell('F', cols.fStop, palette),
              _HeaderCell('PERS.', cols.personajes, palette),
              _HeaderCell('DUR.', cols.duracion, palette),
              _HeaderCell('ACCIÓN', cols.action, palette),
              _HeaderCell('REFERENCIA', cols.referencia, palette),
              _HeaderCell('PLANTA', cols.planta, palette),
              _HeaderCell('APUNTES', cols.apuntes, palette),
            ],
          ),
        ),
        SizedBox(width: cols.acciones - 1),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final AppPalette palette;

  const _HeaderCell(this.text, this.width, this.palette);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: const BoxDecoration(border: Border(right: _sheetSide)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.label(
          palette,
        ).copyWith(color: ScriptSheetColors.ink, letterSpacing: 0.2),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Celda de la hoja: línea negra a la derecha y, si lo que contiene tiene el
/// foco, borde de acento.
class _Cell extends StatelessWidget {
  final double width;
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Alignment alignment;

  const _Cell({
    required this.width,
    required this.child,
    this.padding = const EdgeInsets.all(6),
    this.color,
    this.alignment = Alignment.topLeft,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: Builder(
        builder: (context) {
          // Depender del foco así repinta la celda sin `setState`.
          final focused = Focus.of(context).hasFocus;
          return Container(
            width: width,
            padding: padding,
            color: color,
            foregroundDecoration: BoxDecoration(
              border: focused
                  ? Border.all(color: palette.accent, width: 2)
                  : const Border(right: _sheetSide),
            ),
            child: Align(alignment: alignment, child: child),
          );
        },
      ),
    );
  }
}

const double _kRowMinHeight = 96;

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
              : Border(top: BorderSide(color: palette.accent, width: 3)),
        ),
        child: child,
      ),
    );
  }
}

/// Valor de una lista (movimiento, ángulo) como texto de la hoja: al tocarlo
/// abre sus opciones, sin flecha de desplegable.
class _OptionText extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _OptionText({
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
  });

  static const _none = '\u0000';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final current = (value ?? '').trim();
    return PopupMenuButton<String>(
      tooltip: hint,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      color: palette.surfaceElevated,
      onSelected: (v) => onChanged(v == _none ? null : v),
      itemBuilder: (_) => [
        for (final o in {...options, if (current.isNotEmpty) current})
          PopupMenuItem(
            value: o,
            height: 36,
            child: Text(o, style: AppTypography.bodyMedium(palette)),
          ),
        if (current.isNotEmpty) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _none,
            height: 36,
            child: Text(
              'Quitar',
              style: AppTypography.bodyMedium(
                palette,
              ).copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ],
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: Text(
            current.isEmpty ? hint : current,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: current.isEmpty
                ? ScriptSheetColors.hintText(palette)
                : ScriptSheetColors.text(palette),
          ),
        ),
      ),
    );
  }
}

class _ShotRow extends ConsumerStatefulWidget {
  final Shot shot;
  final Scene scene;
  final _Cols cols;

  const _ShotRow({required this.shot, required this.scene, required this.cols});

  @override
  ConsumerState<_ShotRow> createState() => _ShotRowState();
}

class _ShotRowState extends ConsumerState<_ShotRow> {
  /// Con el ratón encima, el asa y las acciones se ven del todo.
  final _hovered = ValueNotifier(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final palette = context.palette;
    final shot = widget.shot;
    final scene = widget.scene;
    final cols = widget.cols;
    final text = ScriptSheetColors.text(palette);
    final hint = ScriptSheetColors.hintText(palette);

    Widget field({
      required String? value,
      required String hintText,
      required ValueChanged<String> onChanged,
      int minLines = 1,
      TextAlign align = TextAlign.start,
    }) => InlineEditField(
      flat: true,
      value: value,
      hint: hintText,
      palette: palette,
      style: text,
      hintStyle: hint,
      minLines: minLines,
      textAlign: align,
      onChanged: onChanged,
    );

    void write(ShotsCompanion fields) => db.updateShotFields(shot.id, fields);

    Widget side(Widget child) => ValueListenableBuilder<bool>(
      valueListenable: _hovered,
      builder: (context, hovered, child) => AnimatedOpacity(
        opacity: hovered ? 1 : 0.35,
        duration: const Duration(milliseconds: 120),
        child: child,
      ),
      child: child,
    );

    final sheet = Container(
      decoration: const BoxDecoration(
        color: ScriptSheetColors.paper,
        border: Border(left: _sheetSide, bottom: _sheetSide),
      ),
      child: IntrinsicHeight(
        // El mínimo deja sitio a la celda de lente aunque su alto calculado
        // por adelantado se quede corto.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRowMinHeight),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cell(
                width: cols.esc,
                alignment: Alignment.center,
                child: Text('${scene.number}', style: text),
              ),
              _Cell(
                width: cols.plano,
                alignment: Alignment.center,
                child: Text('${shot.number}', style: text),
              ),
              _Cell(
                width: cols.encuadre,
                alignment: Alignment.center,
                child: field(
                  value: shot.framing,
                  hintText: 'PD, PMC...',
                  align: TextAlign.center,
                  onChanged: (v) => write(ShotsCompanion(framing: Value(v))),
                ),
              ),
              _Cell(
                width: cols.lens,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    field(
                      value: shot.lens,
                      hintText: '50mm',
                      align: TextAlign.center,
                      onChanged: (v) => write(ShotsCompanion(lens: Value(v))),
                    ),
                    _OptionText(
                      value: shot.angle,
                      hint: 'Ángulo',
                      options: kAngles,
                      onChanged: (v) => write(ShotsCompanion(angle: Value(v))),
                    ),
                    _OptionText(
                      value: shot.movement,
                      hint: 'Movimiento',
                      options: kMovements,
                      onChanged: (v) =>
                          write(ShotsCompanion(movement: Value(v))),
                    ),
                  ],
                ),
              ),
              _Cell(
                width: cols.fStop,
                alignment: Alignment.center,
                child: field(
                  value: shot.fStop,
                  hintText: 'T2.8',
                  align: TextAlign.center,
                  onChanged: (v) => write(ShotsCompanion(fStop: Value(v))),
                ),
              ),
              _Cell(
                width: cols.personajes,
                child: field(
                  value: decodeSceneCharacters(shot.charactersJson).join(', '),
                  hintText: 'Ana, Luis…',
                  minLines: 2,
                  onChanged: (v) => write(
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
                alignment: Alignment.center,
                child: field(
                  value: shot.durationSeconds?.toString(),
                  hintText: 'seg',
                  align: TextAlign.center,
                  onChanged: (v) => write(
                    ShotsCompanion(
                      durationSeconds: Value(int.tryParse(v.trim())),
                    ),
                  ),
                ),
              ),
              _Cell(
                width: cols.action,
                child: field(
                  value: shot.action,
                  hintText: 'Descripción de la acción...',
                  minLines: 3,
                  onChanged: (v) => write(ShotsCompanion(action: Value(v))),
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
                color: ScriptSheetColors.highlight(shot.notesHighlight),
                child: field(
                  value: shot.notes,
                  hintText: 'Apuntes...',
                  minLines: 3,
                  onChanged: (v) => write(ShotsCompanion(notes: Value(v))),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: cols.handle,
            child: side(
              Draggable<_ShotDrag>(
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
                      height: 36,
                      child: Icon(
                        Icons.drag_indicator,
                        size: 18,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          sheet,
          SizedBox(
            width: cols.acciones - 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 0, 0),
              child: side(_ActionsCell(shot: shot)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fuera de la hoja: color de la celda de apuntes y eliminar el plano.
class _ActionsCell extends ConsumerWidget {
  final Shot shot;

  const _ActionsCell({required this.shot});

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

    Widget dot(String value) => Tooltip(
      message: 'Color de la celda de apuntes',
      child: _HighlightDot(
        color: ScriptSheetColors.highlight(value)!,
        selected: shot.notesHighlight == value,
        onTap: () => db.updateShotFields(
          shot.id,
          ShotsCompanion(
            // Tocar el color que ya tiene lo quita.
            notesHighlight: Value(shot.notesHighlight == value ? null : value),
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot('green'),
            const SizedBox(width: 4),
            dot('yellow'),
            const SizedBox(width: 4),
            dot('red'),
          ],
        ),
        const SizedBox(height: 8),
        _RowAction(
          tooltip: 'Eliminar plano',
          icon: Icons.delete_outline,
          color: palette.textSecondary,
          onTap: () => _delete(context, ref),
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

  const _HighlightDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 1 : 0.55),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : color,
            width: selected ? 2 : 1,
          ),
        ),
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
        height: 84,
        decoration: BoxDecoration(
          color: hasImage ? null : ScriptSheetColors.tile,
          border: hasImage
              ? null
              : Border.all(color: ScriptSheetColors.tileBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [Image.file(File(path), fit: BoxFit.contain)],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: ScriptSheetColors.hint,
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ref.',
                    style: AppTypography.caption(
                      palette,
                    ).copyWith(color: ScriptSheetColors.hint),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}
