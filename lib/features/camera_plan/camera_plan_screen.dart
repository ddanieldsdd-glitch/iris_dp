import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../goodnotes/goodnotes_pdf_actions.dart';
import '../look_bible/look_bible_model.dart';
import '../../shared/pdf_export/camera_plan_pdf.dart';
import 'camera_plan_grouping.dart';
import 'floor_plan_repository.dart';
import 'light_setup_actions.dart';
import 'plan_data.dart';
import 'plan_global_map.dart';
import 'plan_shot_card.dart';
import 'plan_target.dart';
import 'plan_workspace_screen.dart';

enum _PlanView { map, script }

/// Entrada a las plantas de luz y cámara: un mapa global con miniaturas de
/// localizaciones, sets y esquemas de luz, y una vista por orden de guion.
class CameraPlanScreen extends ConsumerStatefulWidget {
  final int projectId;

  const CameraPlanScreen({super.key, required this.projectId});

  @override
  ConsumerState<CameraPlanScreen> createState() => _CameraPlanScreenState();
}

class _CameraPlanScreenState extends ConsumerState<CameraPlanScreen> {
  _PlanView _view = _PlanView.map;

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
          SegmentedButton<_PlanView>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _PlanView.map,
                icon: Icon(Icons.map_outlined, size: 18),
                label: Text('Mapa'),
              ),
              ButtonSegment(
                value: _PlanView.script,
                icon: Icon(Icons.view_list_outlined, size: 18),
                label: Text('Guion'),
              ),
            ],
            selected: {_view},
            onSelectionChanged: (v) => setState(() => _view = v.first),
          ),
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
        builder: (context, data) => switch (_view) {
          _PlanView.map => PlanGlobalMap(
            projectId: projectId,
            data: data,
            onOpen: _open,
          ),
          _PlanView.script => _ScriptOrderList(data: data, onOpen: _open),
        },
      ),
    );
  }
}

/// Todos los planos, escena a escena, en el orden del guion.
class _ScriptOrderList extends StatelessWidget {
  final PlanProjectData data;
  final void Function(PlanTarget target) onOpen;

  const _ScriptOrderList({required this.data, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scenes = scenesInScriptOrder(data.scenes);
    if (scenes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Sin escenas todavía. Las plantas se pueden empezar desde el '
            'mapa y vincular a los planos después.',
            style: AppTypography.bodyMedium(palette),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (final scene in scenes)
          PlanSceneBlock(
            scene: scene,
            data: data,
            onOpen: onOpen,
            showLocation: true,
          ),
      ],
    );
  }
}
