import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../goodnotes/goodnotes_pdf_actions.dart';
import '../look_bible/look_bible_model.dart';
import '../../shared/pdf_export/shooting_plan_pdf.dart';
import '../export_center/export_center_screen.dart';
import '../export_center/export_selection.dart';
import 'camera_plan_grouping.dart';
import 'floor_plan_repository.dart';
import 'light_setup_actions.dart';
import 'plan_repair_dialog.dart';
import 'plan_site_sets.dart';
import 'plan_data.dart';
import 'plan_global_map.dart';
import 'plan_index.dart';
import 'plan_scene_board.dart';
import 'plan_target.dart';
import 'plan_trash_ui.dart';
import 'plan_workspace_screen.dart';
import 'project_focus.dart';

/// Entrada a las plantas de luz y cámara. A la izquierda, el índice
/// (localizaciones, sets y escenas, o las escenas en orden de guion); a la
/// derecha, lo que se haya tocado: el tablero de una escena, la ficha de
/// una localización o todo el proyecto.
class CameraPlanScreen extends ConsumerStatefulWidget {
  final int projectId;

  const CameraPlanScreen({super.key, required this.projectId});

  @override
  ConsumerState<CameraPlanScreen> createState() => _CameraPlanScreenState();
}

class _CameraPlanScreenState extends ConsumerState<CameraPlanScreen> {
  bool _byScript = false;

  /// Lo que se está viendo. `null` = aún no se ha tocado nada: se enseña la
  /// primera escena o, si no hay, todo el proyecto.
  PlanPick? _pick;

  /// En una localización, el mapa en vez de sus sets.
  bool _siteMap = false;

  int get projectId => widget.projectId;

  void _open(PlanTarget target) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PlanWorkspaceScreen(projectId: projectId, initial: target),
      ),
    );
  }

  Future<void> _onNew(String action) async {
    final db = ref.read(databaseProvider);
    switch (action) {
      case 'site':
        final name = await askPlanName(
          context,
          title: 'Nueva localización',
          hint: 'Bosque, hospital, casa de Gala…',
        );
        if (name == null) return;
        await db.insertSite(
          LocationSitesCompanion.insert(projectId: projectId, name: name),
        );
      case 'free':
        final setup = await FloorPlanRepository(
          db,
        ).createLightSetup(projectId: projectId);
        if (!mounted) return;
        _open(PlanTarget.lightSetup(setup.id, setup.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final focusProvider = projectFocusProvider(projectId);
    final focusScene = ref.watch(focusProvider.select((f) => f.sceneId));
    // Si se ha trabajado en otra escena, al volver se ve esa.
    ref.listen(focusProvider.select((f) => f.sceneId), (_, next) {
      if (next != null && _pick?.kind == PlanPickKind.scene) {
        setState(() => _pick = null);
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text(
          'Plantas de luz y cámara',
          style: AppTypography.titleLarge(palette),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Nuevo',
            icon: Icon(Icons.add, color: palette.textSecondary),
            onSelected: _onNew,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'site', child: Text('Nueva localización')),
              PopupMenuItem(value: 'free', child: Text('Nueva planta libre')),
            ],
          ),
          IconButton(
            tooltip: 'Ordenar la planta',
            icon: Icon(Icons.auto_fix_high, color: palette.textSecondary),
            onPressed: () => showPlanRepairDialog(
              context,
              ref.read(databaseProvider),
              projectId,
            ),
          ),
          IconButton(
            tooltip: 'Papelera de plantas',
            icon: Icon(Icons.delete_outline, color: palette.textSecondary),
            onPressed: () => PlanTrashScreen.open(context, projectId),
          ),
          IconButton(
            tooltip: 'Exportar',
            icon: Icon(Icons.ios_share, color: palette.textSecondary),
            onPressed: () => ExportCenterScreen.open(
              context,
              projectId: projectId,
              document: ExportDocument.shootingPlan,
            ),
          ),
          GoodNotesPdfActions(
            projectId: projectId,
            moduleType: GoodNotesModuleType.plantaCamara,
            filenameBase: 'planta_camara',
            buildPdfBytes: () async {
              final db = ref.read(databaseProvider);
              final project = await db.getProject(projectId);
              if (project == null) return Uint8List(0);
              final source = await ExportSource.load(db, projectId);
              if (source == null) return Uint8List(0);
              return ShootingPlanPdf.build(
                db: db,
                project: project,
                sections: resolveExportSections(
                  source,
                  const ExportSelection(),
                ),
              );
            },
          ),
        ],
      ),
      body: PlanDataBuilder(
        projectId: projectId,
        builder: (context, data) => LayoutBuilder(
          builder: (context, constraints) {
            final scenes = scenesInScriptOrder(data.scenes);
            var pick =
                _pick ??
                (scenes.isEmpty
                    ? const PlanPick.overview()
                    : PlanPick.scene(
                        data.scene(focusScene)?.id ?? scenes.first.id,
                      ));
            // Lo que se veía puede haberse borrado.
            if ((pick.kind == PlanPickKind.scene &&
                    data.scene(pick.id) == null) ||
                (pick.kind == PlanPickKind.site &&
                    data.site(pick.id) == null)) {
              pick = const PlanPick.overview();
            }
            final wide = constraints.maxWidth >= 900;
            final index = PlanIndex(
              data: data,
              byScript: _byScript,
              onByScript: (v) => setState(() => _byScript = v),
              pick: pick,
              onPick: (p) {
                setState(() {
                  _pick = p;
                  _siteMap = false;
                });
                if (p.kind == PlanPickKind.scene) {
                  ref.read(focusProvider.notifier).focusScene(p.id!);
                }
                if (!wide) Navigator.of(context).maybePop();
              },
            );
            final content = switch (pick.kind) {
              PlanPickKind.scene => PlanSceneBoard(
                projectId: projectId,
                scene: data.scene(pick.id)!,
                data: data,
                onOpen: _open,
              ),
              PlanPickKind.site when !_siteMap => PlanSiteSets(
                projectId: projectId,
                site: data.site(pick.id)!,
                data: data,
                onOpen: _open,
                onMap: () => setState(() => _siteMap = true),
              ),
              PlanPickKind.site => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: TextButton.icon(
                      onPressed: () => setState(() => _siteMap = false),
                      icon: const Icon(Icons.view_list_outlined, size: 16),
                      label: const Text('Sets de la localización'),
                    ),
                  ),
                  Expanded(
                    child: PlanGlobalMap(
                      projectId: projectId,
                      data: data,
                      onOpen: _open,
                      siteId: pick.id,
                      onScene: (scene) =>
                          setState(() => _pick = PlanPick.scene(scene.id)),
                    ),
                  ),
                ],
              ),
              PlanPickKind.overview => PlanGlobalMap(
                projectId: projectId,
                data: data,
                onOpen: _open,
                onScene: (scene) =>
                    setState(() => _pick = PlanPick.scene(scene.id)),
              ),
            };
            if (wide) {
              return Row(
                children: [
                  index,
                  Expanded(child: content),
                ],
              );
            }
            // En estrecho, el índice se abre desde un botón.
            return Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => FractionallySizedBox(
                        heightFactor: 0.85,
                        child: index,
                      ),
                    ),
                    icon: const Icon(Icons.menu_open, size: 18),
                    label: const Text('Escenas y localizaciones'),
                  ),
                ),
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
    );
  }
}
