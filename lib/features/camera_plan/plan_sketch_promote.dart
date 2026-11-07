import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/shot_reference_import.dart';
import 'camera_plan_grouping.dart';
import 'floor_plan_repository.dart';
import 'plan_data.dart';

/// Dónde puede quedar la planta oficial.
class _Place {
  final String label;
  final int? setId;
  final int? siteId;

  const _Place(this.label, {this.setId, this.siteId});
}

/// Convierte un boceto en planta oficial: pide nombre, dónde queda y qué
/// planos se ruedan con ella. Devuelve la planta, o nula si se cancela.
Future<LightSetup?> showPromoteSketchDialog(
  BuildContext context,
  AppDatabase db,
  PlanProjectData data,
  LightSetup sketch,
) async {
  final palette = context.palette;
  final scene = data.scene(sketch.sceneId);
  final places = [
    for (final site in data.sites) ...[
      for (final set in data.setsOfSite(site.id))
        _Place('${site.name} › ${set.locationName}', setId: set.id),
      _Place('${site.name} › Luz general', siteId: site.id),
    ],
    for (final set in data.orphanSets) _Place(set.locationName, setId: set.id),
    const _Place('Planta libre, sin localización'),
  ];
  final wantedSet = sketch.locationBasePlanId ?? scene?.locationId;
  final wantedSite =
      sketch.locationSiteId ??
      (scene == null ? null : data.siteIdOfScene(scene));
  var place = places.firstWhere(
    (p) => wantedSet != null
        ? p.setId == wantedSet
        : wantedSite != null
        ? p.siteId == wantedSite
        : p.setId == null && p.siteId == null,
    orElse: () => places.last,
  );

  final entry = 'setup:${sketch.id}';
  final scenes = [
    for (final s in scenesInScriptOrder(data.scenes))
      if (sketch.sceneId == null || s.id == sketch.sceneId) s,
  ];
  bool shows(Shot shot) => planSketchEntriesOf(shot).contains(entry);
  // Entran los que enseñan el boceto y, en un boceto de escena, los que aún
  // no tienen planta. Lo que ya tiene otra planta no se cambia sin pedirlo.
  final picked = {
    for (final s in scenes)
      for (final shot in data.shotsOfScene(s.id))
        if (shot.lightSetupId == null && (shows(shot) || scene != null))
          shot.id,
  };
  final name = TextEditingController(
    text: sketch.name.replaceFirst('Boceto · ', ''),
  );

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text(
          'Hacer planta oficial',
          style: AppTypography.titleMedium(palette),
        ),
        content: SizedBox(
          width: 460,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                'El boceto deja de serlo: pasa a ser una planta definitiva, '
                'con sus planos y en los documentos.',
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<_Place>(
                initialValue: place,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Dónde queda'),
                items: [
                  for (final p in places)
                    DropdownMenuItem(
                      value: p,
                      child: Text(p.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (p) => setState(() => place = p ?? place),
              ),
              const SizedBox(height: 12),
              Text(
                'Planos que se ruedan con esta planta',
                style: AppTypography.caption(palette),
              ),
              for (final s in scenes)
                if (data.shotsOfScene(s.id).isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Escena ${s.label} · ${s.locationCanonical}',
                      style: AppTypography.caption(
                        palette,
                      ).copyWith(color: palette.textTertiary),
                    ),
                  ),
                  for (final shot in data.shotsOfScene(s.id))
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: picked.contains(shot.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          picked.add(shot.id);
                        } else {
                          picked.remove(shot.id);
                        }
                      }),
                      title: Text(
                        ['Plano ${shot.number}', ?shot.framing].join(' · '),
                      ),
                      subtitle: switch (data.setup(shot.lightSetupId)) {
                        final other? => Text('Ahora en «${other.name}»'),
                        _ => null,
                      },
                    ),
                ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hacer oficial'),
          ),
        ],
      ),
    ),
  );
  final chosenName = name.text;
  name.dispose();
  if (ok != true) return null;
  // El boceto puede haber cambiado mientras el diálogo estaba abierto.
  final fresh = await db.getLightSetupById(sketch.id) ?? sketch;
  final promoted = await FloorPlanRepository(db).promoteSketch(
    fresh,
    setId: place.setId,
    siteId: place.siteId,
    name: chosenName,
    shotIds: picked,
  );
  if (context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          picked.isEmpty
              ? '«${promoted.name}» es ya planta oficial: arrastra a ella '
                    'los planos que se ruedan así.'
              : '«${promoted.name}» es ya planta oficial, con '
                    '${picked.length} ${picked.length == 1 ? 'plano' : 'planos'}.',
        ),
      ),
    );
  }
  return promoted;
}
