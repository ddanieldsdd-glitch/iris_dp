import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'floor_plan_json.dart';
import 'floor_plan_repository.dart';
import 'floor_plan_scope.dart';
import 'light_overrides.dart';
import 'light_setup_actions.dart';
import 'plan_trash_service.dart';

/// Grupos de sets (SG.2): sets con el mismo fondo que comparten la luz.
/// Lo que está en la luz del grupo se cambia una vez y se ve en todos.
class SetGroupActions {
  final BuildContext context;
  final AppDatabase db;

  SetGroupActions(this.context, this.db);

  /// Crea un grupo en [siteId] con [sets]. Pregunta el nombre y si la luz
  /// del primero con luces pasa a ser la del grupo. `null` si se cancela.
  Future<SetGroup?> createWith({
    required int projectId,
    required int siteId,
    required List<LightSetup> sets,
  }) async {
    final lit = <LightSetup>[
      for (final s in sets)
        if (_lights(s).isNotEmpty) s,
    ];
    final answer = await _askNewGroup(lit);
    if (answer == null) return null;
    final existing = await db.getSetGroupsForProject(projectId);
    final id = await db.insertSetGroup(
      SetGroupsCompanion.insert(
        projectId: projectId,
        locationSiteId: Value(siteId),
        name: answer.name,
        sortOrder: Value(existing.length),
      ),
    );
    for (final s in sets) {
      await db.assignLightSetupToGroup(s.id, id);
    }
    if (answer.shareFrom != null) await shareLight(answer.shareFrom!, id);
    return db.getSetGroupById(id);
  }

  /// Mete el set en el grupo (o lo saca con [groupId] nulo).
  Future<void> moveTo(LightSetup setup, int? groupId) =>
      db.assignLightSetupToGroup(setup.id, groupId);

  Future<void> rename(SetGroup group) async {
    final name = await askPlanName(
      context,
      title: 'Nombre del grupo',
      initial: group.name,
    );
    if (name != null) await db.updateSetGroup(group.copyWith(name: name));
  }

  /// El grupo va a la papelera; sus sets se quedan, sin grupo.
  Future<void> delete(SetGroup group) async {
    await PlanTrashService(db).deleteSetGroup(group.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '«${group.name}» está en la papelera de plantas. Sus sets se '
          'quedan, sin grupo.',
        ),
      ),
    );
  }

  /// Las luces del set pasan a la luz del grupo: desde ahí se ven en todos
  /// sus sets. Las que ya estén en el grupo en el mismo sitio no se repiten.
  Future<void> shareLight(LightSetup setup, int groupId) async {
    final repo = FloorPlanRepository(db);
    final group = await db.getSetGroupById(groupId);
    if (group == null) return;
    final own = await repo.loadElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setup.id,
    );
    final shared = [...FloorPlanJson.decode(group.planJson)];
    LightOverrides.ensureUids([...own, ...shared]);
    final keep = <PlanElement>[];
    for (final e in own) {
      if (e.type != ElementType.light) {
        keep.add(e);
        continue;
      }
      final repeated = shared.any(
        (g) =>
            g.type == e.type &&
            g.lightType == e.lightType &&
            (g.position - e.position).distance < 1,
      );
      if (!repeated) shared.add(e..layer = PlanLayer.light);
    }
    await repo.saveGroupElements(groupId, shared);
    await repo.saveElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setup.id,
      elements: keep,
    );
  }

  static List<PlanElement> _lights(LightSetup s) => [
    for (final e in FloorPlanJson.decode(s.planJson))
      if (e.type == ElementType.light) e,
  ];

  Future<({String name, LightSetup? shareFrom})?> _askNewGroup(
    List<LightSetup> lit,
  ) {
    final palette = context.palette;
    final controller = TextEditingController();
    LightSetup? shareFrom = lit.firstOrNull;
    return showDialog<({String name, LightSetup? shareFrom})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: palette.surfaceElevated,
          title: Text(
            'Grupo de sets',
            style: AppTypography.titleMedium(palette),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Fondo fachada, contraplano barra…',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Los sets del grupo comparten la luz: se cambia una vez y '
                  'cambia en todos. Cada set y cada plano puede añadir la '
                  'suya.',
                  style: AppTypography.caption(palette),
                ),
                if (lit.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Luz del grupo, para empezar',
                    style: AppTypography.label(palette),
                  ),
                  RadioGroup<LightSetup?>(
                    groupValue: shareFrom,
                    onChanged: (v) => setState(() => shareFrom = v),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final s in lit)
                          RadioListTile<LightSetup?>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: s,
                            title: Text(
                              'La de «${s.name}» '
                              '(${_lights(s).length} luces)',
                            ),
                          ),
                        const RadioListTile<LightSetup?>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: null,
                          title: Text('Vacía: cada set con la suya'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                Navigator.pop(ctx, (
                  name: name.isEmpty ? 'Grupo' : name,
                  shareFrom: shareFrom,
                ));
              },
              child: const Text('Crear grupo'),
            ),
          ],
        ),
      ),
    );
  }
}
