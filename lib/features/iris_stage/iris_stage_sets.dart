import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../camera_plan/plan_data.dart';
import '../camera_plan/plan_target.dart';
import '../camera_plan/plan_workspace_screen.dart';

/// IRIS Stage como casa del 3D (ED.4): los sets del proyecto, por
/// localización; tocar uno abre su 3D a pantalla entera, con la tira de
/// planos, la lista de la escena y la biblioteca de Unreal.
class IrisStageSets extends StatelessWidget {
  final int projectId;

  const IrisStageSets({super.key, required this.projectId});

  /// Los sets por localización, en el orden de rodaje; al final, las
  /// plantas sin localización.
  static List<(String, List<LightSetup>)> groups(PlanProjectData data) {
    final out = <(String, List<LightSetup>)>[];
    for (final site in data.sites) {
      final sets = [for (final g in data.orderedSets(site.id)) ...g.sets];
      if (sets.isNotEmpty) out.add((site.name, sets));
    }
    final free = data.freeSetups.toList();
    if (free.isNotEmpty) out.add(('Sin localización', free));
    return out;
  }

  @override
  Widget build(BuildContext context) => PlanDataBuilder(
    projectId: projectId,
    builder: (context, data) {
      final palette = context.palette;
      final groups = IrisStageSets.groups(data);
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.view_in_ar, size: 20, color: palette.accent),
                const SizedBox(width: AppSpacing.xs),
                Text('El 3D de cada set', style: AppTypography.label(palette)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              groups.isEmpty
                  ? 'Aún no hay sets: créalos en la planta de una '
                        'localización.'
                  : 'Ábrelo y trabaja en el 3D: cambia de plano, coloca y '
                        'mueve piezas, y pon assets de Unreal, Fab o '
                        'Megascans.',
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary),
            ),
            for (final (site, sets) in groups) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                site.toUpperCase(),
                style: AppTypography.caption(
                  palette,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final set in sets)
                    ActionChip(
                      key: ValueKey('stage-set-${set.id}'),
                      avatar: Icon(
                        Icons.view_in_ar,
                        size: 16,
                        color: data.setupColor(set),
                      ),
                      label: Text(
                        '${set.name} · ${data.shotsOfSetup(set.id).length} '
                        'planos',
                      ),
                      onPressed: () => PlanWorkspaceScreen.openStage(
                        context,
                        projectId: projectId,
                        target: PlanTarget.lightSetup(set.id, set.name),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}
