import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/scene_format.dart';
import 'camera_plan_grouping.dart';
import 'plan_data.dart';

/// Qué se está viendo en la pantalla de plantas.
enum PlanPickKind { overview, site, scene }

class PlanPick {
  final PlanPickKind kind;
  final int? id;

  const PlanPick.overview() : kind = PlanPickKind.overview, id = null;
  const PlanPick.site(int this.id) : kind = PlanPickKind.site;
  const PlanPick.scene(int this.id) : kind = PlanPickKind.scene;

  @override
  bool operator ==(Object other) =>
      other is PlanPick && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// Índice de las plantas: localizaciones, sets y escenas, o las escenas en
/// orden de guion. Siempre a la vista; tocar algo lo enseña a la derecha.
class PlanIndex extends StatelessWidget {
  final PlanProjectData data;
  final bool byScript;
  final ValueChanged<bool> onByScript;
  final PlanPick pick;
  final ValueChanged<PlanPick> onPick;

  const PlanIndex({
    super.key,
    required this.data,
    required this.byScript,
    required this.onByScript,
    required this.pick,
    required this.onPick,
  });

  static const double width = 280;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget sceneRow(Scene scene, {double indent = 0, bool showWhere = false}) {
      final shots = data.shotsOfScene(scene.id);
      final unlit = shots
          .where(
            (s) => !data.isSequence(s) && data.setup(s.lightSetupId) == null,
          )
          .length;
      final sequences = shots.where(data.isSequence).length;
      final color = data.colors.sceneColor(scene);
      final picked = pick == PlanPick.scene(scene.id);
      final location = locationFromCanonical(scene.locationCanonical);
      final where = data.site(data.siteIdOfScene(scene))?.name;
      return InkWell(
        onTap: () => onPick(PlanPick.scene(scene.id)),
        child: Container(
          color: picked ? palette.accent.withValues(alpha: 0.16) : null,
          padding: EdgeInsets.fromLTRB(12 + indent, 6, 10, 6),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color),
                ),
                child: Text(
                  '${scene.label}',
                  style: AppTypography.caption(palette).copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scene.name.isNotEmpty ? scene.name : location,
                      style: AppTypography.bodyMedium(palette),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        if (showWhere && where != null) where,
                        '${shots.length} '
                            'plano${shots.length == 1 ? '' : 's'}',
                        if (unlit > 0) '$unlit sin luz',
                      ].join(' · '),
                      style: AppTypography.caption(palette).copyWith(
                        color: unlit > 0
                            ? palette.warning
                            : palette.textTertiary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (sequences > 0)
                Tooltip(
                  message: 'Tiene un plano secuencia',
                  child: Icon(
                    Icons.route_outlined,
                    size: 15,
                    color: palette.accent,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget heading(
      String text, {
      Color? color,
      int? count,
      VoidCallback? onTap,
      bool picked = false,
    }) => InkWell(
      onTap: onTap,
      child: Container(
        color: picked ? palette.accent.withValues(alpha: 0.16) : null,
        padding: const EdgeInsets.fromLTRB(0, 9, 10, 7),
        child: Row(
          children: [
            Container(width: 4, height: 18, color: color ?? palette.border),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text.toUpperCase(),
                style: AppTypography.caption(palette).copyWith(
                  color: palette.textPrimary,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count != null)
              Text(
                '$count',
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.textTertiary),
              ),
          ],
        ),
      ),
    );

    Widget setLabel(String name, int count) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 10, 2),
      child: Row(
        children: [
          Icon(Icons.layers_outlined, size: 13, color: palette.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: AppTypography.caption(palette).copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$count',
            style: AppTypography.caption(
              palette,
            ).copyWith(color: palette.textTertiary, fontSize: 10),
          ),
        ],
      ),
    );

    final rows = <Widget>[];
    if (byScript) {
      for (final scene in scenesInScriptOrder(data.scenes)) {
        rows.add(sceneRow(scene, showWhere: true));
      }
    } else {
      for (final site in data.sites) {
        final sets = data.setsOfSite(site.id);
        final loose = data.scenesOfSiteWithoutSet(site.id);
        final scenes = [
          for (final set in sets) ...data.scenesOfSet(set.id),
          ...loose,
        ];
        rows.add(
          heading(
            site.name,
            color: data.colors.siteColor(site.id),
            count: data.shotsOfScenes(scenes).length,
            picked: pick == PlanPick.site(site.id),
            onTap: () => onPick(PlanPick.site(site.id)),
          ),
        );
        for (final set in sets) {
          final ofSet = data.scenesOfSet(set.id);
          rows.add(
            setLabel(set.locationName, data.shotsOfScenes(ofSet).length),
          );
          for (final scene in ofSet) {
            rows.add(sceneRow(scene, indent: 20));
          }
        }
        if (loose.isNotEmpty) {
          rows.add(setLabel('Sin set', data.shotsOfScenes(loose).length));
          for (final scene in loose) {
            rows.add(sceneRow(scene, indent: 20));
          }
        }
      }
      for (final set in data.orphanSets) {
        final ofSet = data.scenesOfSet(set.id);
        if (ofSet.isEmpty) continue;
        rows.add(setLabel(set.locationName, data.shotsOfScenes(ofSet).length));
        for (final scene in ofSet) {
          rows.add(sceneRow(scene, indent: 20));
        }
      }
      final nowhere = data.scenesWithoutLocation;
      if (nowhere.isNotEmpty) {
        rows.add(heading('Sin localización', count: nowhere.length));
        for (final scene in nowhere) {
          rows.add(sceneRow(scene));
        }
      }
    }

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(right: BorderSide(color: palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: false, label: Text('Localizaciones')),
                    ButtonSegment(value: true, label: Text('Guion')),
                  ],
                  selected: {byScript},
                  onSelectionChanged: (v) => onByScript(v.first),
                ),
                const SizedBox(height: 8),
                Text(
                  '${data.sites.length} localizaciones · '
                  '${data.sets.length} sets · '
                  '${data.scenes.length} escenas · '
                  '${data.shots.length} planos',
                  style: AppTypography.caption(
                    palette,
                  ).copyWith(color: palette.textTertiary, fontSize: 10),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              children: [
                heading(
                  'Todo el proyecto',
                  picked: pick == const PlanPick.overview(),
                  onTap: () => onPick(const PlanPick.overview()),
                ),
                ...rows,
                if (data.scenes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Sin escenas todavía. Las plantas se pueden empezar '
                      'desde «Todo el proyecto».',
                      style: AppTypography.caption(palette),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
