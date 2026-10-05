import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../goodnotes/goodnotes_pdf_actions.dart';
import '../look_bible/look_bible_model.dart';
import '../../shared/pdf_export/camera_plan_pdf.dart';
import 'camera_plan_grouping.dart';
import 'floor_plan_repository.dart';
import 'light_setup_actions.dart';
import 'plan_data.dart';
import 'plan_global_map.dart';
import 'plan_index.dart';
import 'plan_scene_board.dart';
import 'plan_target.dart';
import 'plan_workspace_screen.dart';

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
          GoodNotesPdfActions(
            projectId: projectId,
            moduleType: GoodNotesModuleType.plantaCamara,
            filenameBase: 'planta_camara',
            buildPdfBytes: () async {
              final db = ref.read(databaseProvider);
              final project = await db.getProject(projectId);
              if (project == null) return Uint8List(0);
              final scenes = await db.watchScenesForProject(projectId).first;
              return CameraPlanPdfExporter.buildBytes(
                project: project,
                scenes: scenes,
                db: db,
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
                    : PlanPick.scene(scenes.first.id));
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
                setState(() => _pick = p);
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
              PlanPickKind.site => PlanGlobalMap(
                projectId: projectId,
                data: data,
                onOpen: _open,
                siteId: pick.id,
                onScene: (scene) =>
                    setState(() => _pick = PlanPick.scene(scene.id)),
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
