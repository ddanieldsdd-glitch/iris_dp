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
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../core/utils/scene_format.dart';
import '../../core/utils/scene_characters.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_button.dart';
import '../camera_plan/camera_plan_editor.dart';
import '../camera_plan/plan_data.dart';
import '../camera_plan/plan_thumbnail.dart';
import '../locations/locations_screen.dart';
import '../goodnotes/goodnotes_pdf_actions.dart';
import '../look_bible/look_bible_model.dart';
import '../../shared/pdf_export/technical_script_pdf.dart';
import '../locations/location_picker.dart';
import '../locations/where_field.dart';
import 'scene_form_sheet.dart';
import 'table/editable_cell.dart';
import 'table/reference_image_menu.dart';
import 'table/script_sheet_theme.dart';
import 'technical_script_settings.dart';
import '../../core/utils/shot_technical_options.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/scene_meta_display.dart';

// Re-export para compatibilidad con imports existentes.
const kMovements = kShotMovements;
const kAngles = kShotAngles;

/// Plano en el que se está trabajando: el de la última celda tocada. La barra
/// de formato actúa sobre él.
final _activeShotProvider = StateProvider.autoDispose<int?>((ref) => null);

class TechnicalScriptScreen extends ConsumerWidget {
  final int projectId;
  const TechnicalScriptScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final settings = ref.watch(technicalScriptSettingsProvider);
    final theme = ScriptSheetTheme.resolve(settings, palette);

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
      body: Column(
        children: [
          _FormatBar(settings: settings),
          Expanded(
            child: PlanDataBuilder(
              projectId: projectId,
              builder: (context, data) {
                if (data.scenes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Sin escenas. Importa el guion o añade una '
                          'manualmente.',
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
                return ScriptSheet(
                  theme: theme,
                  child: _PlanDataScope(
                    data: data,
                    child: _ScriptTable(data: data, settings: settings),
                  ),
                );
              },
            ),
          ),
        ],
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

/// Datos de plantas del proyecto, al alcance de la celda de planta sin
/// obligar a repintar la fila entera cuando cambian.
class _PlanDataScope extends InheritedWidget {
  final PlanProjectData data;

  const _PlanDataScope({required this.data, required super.child});

  static PlanProjectData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PlanDataScope>()!.data;

  @override
  bool updateShouldNotify(_PlanDataScope oldWidget) => oldWidget.data != data;
}

/// Barra de formato del guion técnico: vista, tipografía, columnas y color
/// del plano en el que se está trabajando.
class _FormatBar extends ConsumerWidget {
  final TechnicalScriptSettings settings;
  const _FormatBar({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final notifier = ref.read(technicalScriptSettingsProvider.notifier);
    final activeShot = ref.watch(_activeShotProvider);
    final label = AppTypography.bodyMedium(
      palette,
    ).copyWith(color: palette.textPrimary);

    Widget divider() => Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: palette.divider,
    );

    Widget iconButton({
      required String tooltip,
      required IconData icon,
      required VoidCallback? onTap,
    }) => IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      color: palette.textPrimary,
      disabledColor: palette.textTertiary,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );

    Future<void> setRowColor(String? value) async {
      if (activeShot == null) return;
      await ref
          .read(databaseProvider)
          .updateShotFields(
            activeShot,
            ShotsCompanion(notesHighlight: Value(value)),
          );
    }

    final swatches = ScriptSheetTheme.resolve(
      settings.copyWith(view: ScriptView.sheet),
      palette,
    );

    return Container(
      height: 44,
      width: double.infinity,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            SegmentedButton<ScriptView>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(
                  value: ScriptView.sheet,
                  icon: Icon(Icons.description_outlined, size: 16),
                  label: Text('Hoja'),
                ),
                ButtonSegment(
                  value: ScriptView.dark,
                  icon: Icon(Icons.dark_mode_outlined, size: 16),
                  label: Text('Oscura'),
                ),
              ],
              selected: {settings.view},
              onSelectionChanged: (s) =>
                  notifier.update((v) => v.copyWith(view: s.first)),
            ),
            divider(),
            PopupMenuButton<String>(
              tooltip: 'Tipografía de la tabla',
              color: palette.surfaceElevated,
              onSelected: (f) =>
                  notifier.update((v) => v.copyWith(fontFamily: f)),
              itemBuilder: (_) => [
                for (final f in kScriptFonts.entries)
                  CheckedPopupMenuItem(
                    value: f.key,
                    checked: settings.fontFamily == f.key,
                    child: Text(f.value),
                  ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kScriptFonts[settings.fontFamily] ?? settings.fontFamily,
                    style: label,
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            iconButton(
              tooltip: 'Letra más pequeña',
              icon: Icons.remove,
              onTap: settings.fontSize <= TechnicalScriptSettings.minFontSize
                  ? null
                  : () => notifier.update(
                      (v) => v.copyWith(fontSize: v.fontSize - 1),
                    ),
            ),
            Container(
              width: 34,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(settings.fontSize.round().toString(), style: label),
            ),
            iconButton(
              tooltip: 'Letra más grande',
              icon: Icons.add,
              onTap: settings.fontSize >= TechnicalScriptSettings.maxFontSize
                  ? null
                  : () => notifier.update(
                      (v) => v.copyWith(fontSize: v.fontSize + 1),
                    ),
            ),
            divider(),
            Tooltip(
              message: activeShot == null
                  ? 'Toca un plano para darle color'
                  : 'Color del plano',
              child: Opacity(
                opacity: activeShot == null ? 0.4 : 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.format_color_fill,
                      size: 18,
                      color: palette.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    for (final c in kScriptRowColors)
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Tooltip(
                          message: scriptRowColorLabel(c),
                          child: InkResponse(
                            radius: 14,
                            onTap: activeShot == null
                                ? null
                                : () => setRowColor(c),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: swatches.rowFill(c),
                                shape: BoxShape.circle,
                                border: Border.all(color: palette.border),
                              ),
                            ),
                          ),
                        ),
                      ),
                    iconButton(
                      tooltip: 'Quitar el color del plano',
                      icon: Icons.format_color_reset_outlined,
                      onTap: activeShot == null
                          ? null
                          : () => setRowColor(null),
                    ),
                  ],
                ),
              ),
            ),
            divider(),
            PopupMenuButton<String>(
              tooltip: 'Columnas visibles',
              color: palette.surfaceElevated,
              onSelected: notifier.toggleColumn,
              itemBuilder: (_) => [
                for (final c in ScriptColumn.optional)
                  CheckedPopupMenuItem(
                    value: c,
                    checked: settings.shows(c),
                    child: Text(ScriptColumn.label(c)),
                  ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.view_column_outlined,
                    size: 18,
                    color: palette.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text('Columnas', style: label),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Guion técnico: una tabla por escena, como hojas de un documento. Ocupa
/// todo el ancho; por debajo del mínimo, se desplaza entera.
class _ScriptTable extends StatelessWidget {
  final PlanProjectData data;
  final TechnicalScriptSettings settings;

  const _ScriptTable({required this.data, required this.settings});

  @override
  Widget build(BuildContext context) {
    final shotsByScene = <int, List<Shot>>{};
    for (final shot in data.shots) {
      shotsByScene.putIfAbsent(shot.sceneId, () => []).add(shot);
    }
    final scenes = data.scenes;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = _Cols.minWidth(settings);
        final width = math.max(constraints.maxWidth, minWidth);
        final cols = _Cols.forWidth(width, settings);
        final table = ListView.builder(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          itemCount: scenes.length + 1,
          // Al crear o borrar una escena las demás cambian de índice: con
          // esto conservan su estado (y la fila de nueva escena sigue
          // abierta para la siguiente).
          findChildIndexCallback: (key) {
            if (key == _newSceneKey) return scenes.length;
            if (key is ValueKey<int>) {
              final i = scenes.indexWhere((s) => s.id == key.value);
              return i < 0 ? null : i;
            }
            return null;
          },
          itemBuilder: (context, i) => i == scenes.length
              ? _NewSceneRow(
                  key: _newSceneKey,
                  projectId: scenes.first.projectId,
                  last: scenes.last,
                )
              : _SceneSection(
                  key: ValueKey(scenes[i].id),
                  scene: scenes[i],
                  shots: shotsByScene[scenes[i].id] ?? const [],
                  colors: data.colors,
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

const _newSceneKey = ValueKey<String>('new-scene');

/// Al final de la tabla: crear una escena diciendo solo dónde ocurre. Toma
/// INT/EXT y el momento de la última escena; se cambian luego en la suya.
class _NewSceneRow extends ConsumerStatefulWidget {
  final int projectId;
  final Scene last;

  const _NewSceneRow({super.key, required this.projectId, required this.last});

  @override
  ConsumerState<_NewSceneRow> createState() => _NewSceneRowState();
}

class _NewSceneRowState extends ConsumerState<_NewSceneRow> {
  final _where = GlobalKey<WhereFieldState>();
  bool _open = false;
  bool _creating = false;

  Future<void> _create(LocationChoice choice) async {
    if (_creating) return;
    _creating = true;
    try {
      await createSceneAt(
        db: ref.read(databaseProvider),
        projectId: widget.projectId,
        choice: choice,
        intExt: widget.last.intExt,
        dayNight: widget.last.dayNight,
      );
      // Listo para la siguiente.
      _where.currentState?.clear();
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, userFriendlyError(e));
    } finally {
      _creating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: TextButton.icon(
            onPressed: () => setState(() => _open = true),
            icon: Icon(Icons.add, color: palette.accent, size: 18),
            label: Text(
              'Nueva escena',
              style: AppTypography.label(
                palette,
              ).copyWith(color: palette.accent),
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 520,
        margin: const EdgeInsets.only(left: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nueva escena',
                    style: AppTypography.titleMedium(palette),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _open = false),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            WhereField(
              key: _where,
              projectId: widget.projectId,
              autofocus: true,
              listHeight: 190,
              onChanged: (choice) {
                if (choice != null) _create(choice);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Elige un lugar o escribe uno nuevo y pulsa Intro. La escena se '
              'crea como ${widget.last.intExt} · ${widget.last.dayNight}; se '
              'cambia después con el lápiz.',
              style: AppTypography.caption(palette),
            ),
          ],
        ),
      ),
    );
  }
}

/// Anchos de columna para un ancho de tabla dado. Las columnas ocultas
/// miden cero; lo que sobra se reparte entre las de texto largo y la
/// referencia.
@immutable
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

  static _Cols _min(TechnicalScriptSettings s) => _Cols._(
    handle: 28,
    esc: 40,
    plano: 52,
    encuadre: 150,
    lens: 140,
    fStop: s.shows(ScriptColumn.fStop) ? 52 : 0,
    personajes: s.shows(ScriptColumn.personajes) ? 110 : 0,
    duracion: s.shows(ScriptColumn.duracion) ? 56 : 0,
    action: 220,
    referencia: 140,
    planta: s.shows(ScriptColumn.planta) ? 110 : 0,
    apuntes: 140,
    acciones: 40,
  );

  List<double> get _all => [
    handle,
    esc,
    plano,
    encuadre,
    lens,
    fStop,
    personajes,
    duracion,
    action,
    referencia,
    planta,
    apuntes,
    acciones,
  ];

  static double minWidth(TechnicalScriptSettings s) =>
      _min(s)._all.fold(0, (a, b) => a + b);

  factory _Cols.forWidth(double width, TechnicalScriptSettings s) {
    final m = _min(s);
    final extra = math.max(0.0, width - minWidth(s));
    double grow(double base, int weight) => base + extra * weight / 12;
    return _Cols._(
      handle: m.handle,
      esc: m.esc,
      plano: m.plano,
      encuadre: grow(m.encuadre, 3),
      lens: m.lens,
      fStop: m.fStop,
      personajes: m.personajes,
      duracion: m.duracion,
      action: grow(m.action, 5),
      referencia: grow(m.referencia, 1),
      planta: m.planta,
      apuntes: grow(m.apuntes, 3),
      acciones: m.acciones,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _Cols && listEquals(other._all, _all);

  @override
  int get hashCode => Object.hashAll(_all);
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

  /// Filas ya construidas. Devolver el mismo widget cuando ni el plano, ni la
  /// escena, ni las columnas han cambiado hace que Flutter no repinte esa
  /// fila aunque cambie otra cosa del proyecto.
  final _rows = <int, _ShotRow>{};

  _ShotRow _rowFor(Shot shot) {
    final cached = _rows[shot.id];
    if (cached != null &&
        cached.shot == shot &&
        cached.scene == widget.scene &&
        cached.cols == widget.cols) {
      return cached;
    }
    return _rows[shot.id] = _ShotRow(
      shot: shot,
      scene: widget.scene,
      cols: widget.cols,
    );
  }

  /// Un plano soltado aquí: si es de esta escena cambia de sitio; si viene
  /// de otra, se pasa a esta.
  void _dropBefore(List<Shot> shots, _ShotDrag drag, int beforeIndex) {
    if (drag.sceneId == widget.scene.id) {
      _moveBefore(shots, drag.shotId, beforeIndex);
      return;
    }
    ref
        .read(databaseProvider)
        .moveShotToScene(
          drag.shotId,
          widget.scene.id,
          beforeIndex: beforeIndex,
        );
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
    _rows.removeWhere((id, _) => !shots.any((s) => s.id == id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SceneHeader(
          scene: scene,
          shotCount: shots.length,
          colors: widget.colors,
        ),
        const SizedBox(height: AppSpacing.sm),
        _TableHeader(
          cols: widget.cols,
          sceneColor: widget.colors.sceneColor(scene),
        ),
        // Columna con claves y no una lista reordenable: al cambiar el orden
        // las filas se mueven sin desmontarse, y lo que tengan a medias (foco,
        // avisos, menús) sigue en su sitio.
        for (var i = 0; i < shots.length; i++)
          _ShotDropTarget(
            key: ValueKey(shots[i].id),
            sceneId: scene.id,
            shotId: shots[i].id,
            onDrop: (drag) => _dropBefore(shots, drag, i),
            child: _rowFor(shots[i]),
          ),
        _ShotDropTarget(
          sceneId: scene.id,
          shotId: null,
          onDrop: (drag) => _dropBefore(shots, drag, shots.length),
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
                  location: '${scene.number}. $locationName',
                  style: AppTypography.titleMedium(
                    palette,
                  ).copyWith(color: palette.textPrimary, letterSpacing: 0.5),
                  iconSize: 18,
                ),
                if (scene.offScript) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: palette.highlightYellow.withValues(alpha: 1),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Ya no está en el guion literario. Se conserva '
                          'con sus planos; puedes eliminarla cuando no la '
                          'necesites.',
                          style: AppTypography.caption(palette).copyWith(
                            color: palette.highlightYellow.withValues(alpha: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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

/// Fila de títulos de columna, una por escena, con el color de la escena.
class _TableHeader extends StatelessWidget {
  final _Cols cols;
  final Color sceneColor;
  const _TableHeader({required this.cols, required this.sceneColor});

  @override
  Widget build(BuildContext context) {
    final sheet = ScriptSheet.of(context);
    final side = sheet.side;

    Widget cell(String text, double width) => width == 0
        ? const SizedBox.shrink()
        : Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            decoration: BoxDecoration(border: Border(right: side)),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: sheet.headerText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );

    return Row(
      children: [
        SizedBox(width: cols.handle),
        Container(
          decoration: BoxDecoration(
            color: sheet.headerFill(sceneColor),
            border: Border(top: side, left: side, bottom: side),
          ),
          child: Row(
            children: [
              cell('ESC', cols.esc),
              cell('PLANO', cols.plano),
              cell('Encuadre', cols.encuadre),
              cell('LENTE/ANG/MOV', cols.lens),
              cell('F', cols.fStop),
              cell('PERS.', cols.personajes),
              cell('DUR.', cols.duracion),
              cell('ACCIÓN', cols.action),
              cell('REFERENCIA', cols.referencia),
              cell('PLANTA', cols.planta),
              cell('APUNTES', cols.apuntes),
            ],
          ),
        ),
      ],
    );
  }
}

/// Celda de la hoja: línea a la derecha y, si lo que contiene tiene el foco,
/// borde de acento.
class _Cell extends StatelessWidget {
  final double width;
  final Widget child;
  final EdgeInsets padding;
  final Alignment alignment;

  const _Cell({
    required this.width,
    required this.child,
    this.padding = const EdgeInsets.all(6),
    this.alignment = Alignment.topLeft,
  });

  @override
  Widget build(BuildContext context) {
    if (width == 0) return const SizedBox.shrink();
    final sheet = ScriptSheet.of(context);
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
            foregroundDecoration: BoxDecoration(
              border: focused
                  ? Border.all(color: sheet.accent, width: 2)
                  : Border(right: sheet.side),
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

/// Hueco donde soltar un plano, de esta escena o de otra: delante de
/// [child]. Marca con una línea de acento dónde va a caer.
class _ShotDropTarget extends StatelessWidget {
  final int sceneId;

  /// Plano de esta fila; nulo en el hueco del final de la escena.
  final int? shotId;
  final ValueChanged<_ShotDrag> onDrop;
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
      onWillAcceptWithDetails: (d) => d.data.shotId != shotId,
      onAcceptWithDetails: (d) => onDrop(d.data),
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
/// abre sus opciones, con «＋» para añadir una propia.
class _OptionText extends ConsumerWidget {
  final String? value;
  final String hint;

  /// true = movimiento de cámara; false = ángulo.
  final bool movement;
  final ValueChanged<String?> onChanged;

  const _OptionText({
    required this.value,
    required this.hint,
    required this.movement,
    required this.onChanged,
  });

  static const _none = '\u0000none';
  static const _add = '\u0000add';

  Future<void> _addNew(BuildContext context, WidgetRef ref) async {
    final palette = context.palette;
    final ctrl = TextEditingController();
    final what = movement ? 'movimiento' : 'ángulo';
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text('Nuevo $what', style: AppTypography.titleMedium(palette)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: AppTypography.bodyLarge(palette),
          decoration: InputDecoration(
            hintText: movement ? 'Ej. CAMERA CAR, SLIDER' : 'Ej. Holandés',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    if (name == null) return;
    final notifier = ref.read(technicalScriptSettingsProvider.notifier);
    final saved = movement
        ? await notifier.addMovement(name, kMovements)
        : await notifier.addAngle(name, kAngles);
    if (saved != null) onChanged(saved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final sheet = ScriptSheet.of(context);
    final custom = ref.watch(
      technicalScriptSettingsProvider.select(
        (s) => movement ? s.customMovements : s.customAngles,
      ),
    );
    final builtIn = movement ? kMovements : kAngles;
    final current = (value ?? '').trim();
    final menuText = AppTypography.bodyMedium(palette);

    return PopupMenuButton<String>(
      tooltip: hint,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      color: palette.surfaceElevated,
      onSelected: (v) {
        if (v == _add) {
          _addNew(context, ref);
        } else {
          onChanged(v == _none ? null : v);
        }
      },
      itemBuilder: (menuContext) => [
        for (final o in {
          ...builtIn,
          ...custom,
          if (current.isNotEmpty) current,
        })
          PopupMenuItem(
            value: o,
            height: 36,
            child: Row(
              children: [
                Expanded(child: Text(o, style: menuText)),
                if (custom.contains(o))
                  InkResponse(
                    radius: 14,
                    onTap: () {
                      Navigator.pop(menuContext);
                      final notifier = ref.read(
                        technicalScriptSettingsProvider.notifier,
                      );
                      movement
                          ? notifier.removeMovement(o)
                          : notifier.removeAngle(o);
                    },
                    child: Tooltip(
                      message: 'Quitar de la lista',
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: palette.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _add,
          height: 36,
          child: Row(
            children: [
              Icon(Icons.add, size: 16, color: palette.accent),
              const SizedBox(width: 6),
              Text(
                movement ? 'Añadir movimiento…' : 'Añadir ángulo…',
                style: menuText.copyWith(color: palette.accent),
              ),
            ],
          ),
        ),
        if (current.isNotEmpty)
          PopupMenuItem(
            value: _none,
            height: 36,
            child: Text(
              'Quitar',
              style: menuText.copyWith(color: palette.textSecondary),
            ),
          ),
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
            style: current.isEmpty ? sheet.hintText : sheet.text,
          ),
        ),
      ),
    );
  }
}

/// Fila de un plano.
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
    final sheet = ScriptSheet.of(context);
    final shot = widget.shot;
    final scene = widget.scene;
    final cols = widget.cols;
    final active = ref.watch(_activeShotProvider.select((id) => id == shot.id));

    Widget field({
      required String? value,
      required String hintText,
      required ValueChanged<String> onChanged,
      int minLines = 1,
      TextAlign align = TextAlign.start,
    }) => EditableCell(
      value: value,
      hint: hintText,
      style: sheet.text,
      hintStyle: sheet.hintText,
      minLines: minLines,
      textAlign: align,
      onChanged: onChanged,
    );

    void write(ShotsCompanion fields) => db.updateShotFields(shot.id, fields);

    Widget side(Widget child) => ValueListenableBuilder<bool>(
      valueListenable: _hovered,
      builder: (context, hovered, child) => AnimatedOpacity(
        opacity: hovered || active ? 1 : 0.35,
        duration: const Duration(milliseconds: 120),
        child: child,
      ),
      child: child,
    );

    final sheetRow = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (focused) ref.read(_activeShotProvider.notifier).state = shot.id;
      },
      child: Container(
        decoration: BoxDecoration(
          color: sheet.rowFill(shot.notesHighlight) ?? sheet.paper,
          border: Border(left: sheet.side, bottom: sheet.side),
        ),
        child: IntrinsicHeight(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _kRowMinHeight),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Cell(
                  width: cols.esc,
                  alignment: Alignment.center,
                  child: Text('${scene.number}', style: sheet.text),
                ),
                _Cell(
                  width: cols.plano,
                  alignment: Alignment.center,
                  child: Text('${shot.number}', style: sheet.text),
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
                        movement: false,
                        onChanged: (v) =>
                            write(ShotsCompanion(angle: Value(v))),
                      ),
                      _OptionText(
                        value: shot.movement,
                        hint: 'Movimiento',
                        movement: true,
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
                    value: decodeSceneCharacters(
                      shot.charactersJson,
                    ).join(', '),
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
                    child: _PlanCell(shot: shot, scene: scene),
                  ),
                ),
                _Cell(
                  width: cols.apuntes,
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
                        color: active ? palette.accent : palette.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          sheetRow,
          SizedBox(
            width: cols.acciones - sheet.lineWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: side(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MoveShotButton(shot: shot),
                    const SizedBox(height: 10),
                    _DeleteShotButton(shot: shot),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Miniatura de la planta del plano. Al tocarla abre la planta; si la escena
/// aún no tiene set, lleva a la localización para elegirlo o crearlo.
class _PlanCell extends StatelessWidget {
  final Shot shot;
  final Scene scene;

  const _PlanCell({required this.shot, required this.scene});

  @override
  Widget build(BuildContext context) {
    final sheet = ScriptSheet.of(context);
    final data = _PlanDataScope.of(context);
    final setId = shot.locationBasePlanId ?? scene.locationId;
    final own = [...data.lightOfShot(shot), ...data.ownOfShot(shot)];
    final base = data.baseOfShot(shot);
    final hasDrawing = own.isNotEmpty || base.isNotEmpty;

    final String caption;
    final IconData icon;
    if (setId != null) {
      caption = 'Abrir planta';
      icon = Icons.grid_on_outlined;
    } else if (scene.locationSiteId != null) {
      caption = 'Elegir set';
      icon = Icons.add_location_alt_outlined;
    } else {
      caption = 'Elegir localización';
      icon = Icons.add_location_alt_outlined;
    }

    void open() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => setId != null
              ? CameraPlanEditor.shot(
                  projectId: shot.projectId,
                  shotId: shot.id,
                  shotLabel: 'Esc ${scene.number} · Plano ${shot.number}',
                )
              : LocationsScreen(
                  projectId: shot.projectId,
                  initialSiteId: scene.locationSiteId,
                ),
        ),
      );
    }

    return Tooltip(
      message: caption,
      child: GestureDetector(
        onTap: open,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            height: 84,
            child: hasDrawing
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: PlanThumbnail(
                      elements: own,
                      inherited: base,
                      focus: data.zoneOf(data.set(setId)),
                      emptyIcon: Icons.videocam_outlined,
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: sheet.tile,
                      border: Border.all(color: sheet.tileBorder),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: sheet.hint, size: 20),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            caption,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: sheet.hintText.copyWith(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Fuera de la hoja: pasar el plano a otra escena.
class _MoveShotButton extends ConsumerWidget {
  final Shot shot;

  const _MoveShotButton({required this.shot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final scenes = _PlanDataScope.of(context).scenes;
    final others = [
      for (final s in scenes)
        if (s.id != shot.sceneId) s,
    ];
    return PopupMenuButton<int>(
      tooltip: 'Mover a otra escena',
      padding: EdgeInsets.zero,
      enabled: others.isNotEmpty,
      color: palette.surfaceElevated,
      onSelected: (sceneId) =>
          ref.read(databaseProvider).moveShotToScene(shot.id, sceneId),
      itemBuilder: (_) => [
        for (final s in others)
          PopupMenuItem(
            value: s.id,
            height: 36,
            child: Text(
              '${s.number}. ${s.locationCanonical}'
              '${s.offScript ? ' · fuera del guion' : ''}',
              style: AppTypography.bodyMedium(palette),
            ),
          ),
      ],
      child: Icon(
        Icons.drive_file_move_outline,
        size: 18,
        color: others.isEmpty ? palette.textTertiary : palette.textSecondary,
      ),
    );
  }
}

/// Fuera de la hoja: eliminar el plano.
class _DeleteShotButton extends ConsumerWidget {
  final Shot shot;

  const _DeleteShotButton({required this.shot});

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
    final palette = context.palette;
    return Tooltip(
      message: 'Eliminar plano',
      child: InkResponse(
        onTap: () => _delete(context, ref),
        radius: 14,
        child: Icon(
          Icons.delete_outline,
          size: 18,
          color: palette.textSecondary,
        ),
      ),
    );
  }
}

/// Imagen de referencia del plano; tocarla abre su menú.
class _ReferenceCell extends ConsumerWidget {
  final Shot shot;
  const _ReferenceCell({required this.shot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheet = ScriptSheet.of(context);
    final path = shot.referenceImagePath;
    final hasImage = path != null && File(path).existsSync();

    return GestureDetector(
      onTap: () => showReferenceImageMenu(context, shot),
      child: Container(
        height: 84,
        decoration: BoxDecoration(
          color: hasImage ? null : sheet.tile,
          border: hasImage ? null : Border.all(color: sheet.tileBorder),
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
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: sheet.hint,
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ref.',
                    style: sheet.hintText.copyWith(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}
