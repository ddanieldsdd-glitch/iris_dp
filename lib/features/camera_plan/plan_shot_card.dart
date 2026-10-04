import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/scene_format.dart';
import '../../core/widgets/scene_meta_display.dart';
import 'camera_plan_scene_badge.dart';
import 'floor_plan_repository.dart';
import 'plan_data.dart';
import 'plan_target.dart';
import 'plan_thumbnail.dart';

/// Tarjeta de un plano: miniatura de lo que se ve en él y la etiqueta de su
/// esquema de luz. Tocar la tarjeta lo abre; tocar la etiqueta cambia el
/// esquema sin entrar.
class PlanShotCard extends ConsumerWidget {
  final Shot shot;
  final PlanProjectData data;
  final void Function(PlanTarget target) onOpen;

  const PlanShotCard({
    super.key,
    required this.shot,
    required this.data,
    required this.onOpen,
  });

  static const double width = 156;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final scene = data.scene(shot.sceneId);
    final setup = data.setup(shot.lightSetupId);
    final details = [
      if (shot.framing?.isNotEmpty == true) shot.framing!,
      if (shot.lens?.isNotEmpty == true) shot.lens!,
    ].join(' · ');

    return SizedBox(
      width: width,
      child: Material(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpen(PlanTarget.shot(shot.id, data.shotLabel(shot))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 100,
                width: double.infinity,
                child: PlanThumbnail(
                  elements: [
                    if (setup != null) ...data.ownOfSetup(setup),
                    ...data.ownOfShot(shot),
                  ],
                  inherited: data.baseOfShot(shot),
                  focus: data.zoneOf(data.set(scene?.locationId)),
                  emptyIcon: Icons.videocam_outlined,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Row(
                  children: [
                    Text(
                      'P${shot.number}',
                      style: AppTypography.label(palette),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          details,
                          style: AppTypography.caption(palette),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                child: _SetupTag(shot: shot, scene: scene, data: data),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta con el esquema de luz del plano; abre un menú para cambiarlo.
class _SetupTag extends ConsumerWidget {
  final Shot shot;
  final Scene? scene;
  final PlanProjectData data;

  const _SetupTag({
    required this.shot,
    required this.scene,
    required this.data,
  });

  static const int _none = -1;
  static const int _create = -2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final setup = data.setup(shot.lightSetupId);
    final color = setup != null ? data.setupColor(setup) : palette.textTertiary;
    final options = scene != null
        ? data.setupsForScene(scene!)
        : <LightSetup>[];

    return PopupMenuButton<int>(
      tooltip: 'Esquema de luz del plano',
      padding: EdgeInsets.zero,
      onSelected: (choice) async {
        final db = ref.read(databaseProvider);
        if (choice == _create) {
          final created = await FloorPlanRepository(db).createLightSetup(
            projectId: shot.projectId,
            setId: data.set(scene?.locationId)?.id,
            siteId: data.set(scene?.locationId) == null
                ? data.site(scene?.locationSiteId)?.id
                : null,
          );
          await db.assignLightSetupToShot(shot.id, created.id);
        } else {
          await db.assignLightSetupToShot(
            shot.id,
            choice == _none ? null : choice,
          );
        }
      },
      itemBuilder: (_) => [
        for (final option in options)
          PopupMenuItem(
            value: option.id,
            child: Row(
              children: [
                _Swatch(color: data.setupColor(option)),
                const SizedBox(width: 8),
                Text(option.name),
              ],
            ),
          ),
        const PopupMenuItem(value: _create, child: Text('Nuevo esquema')),
        if (setup != null)
          const PopupMenuItem(value: _none, child: Text('Sin luz')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: setup != null ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            _Swatch(color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                setup?.name ?? 'Sin luz',
                style: AppTypography.caption(palette).copyWith(
                  color: setup != null
                      ? palette.textPrimary
                      : palette.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 16, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;

  const _Swatch({required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

/// Una escena con sus planos: cabecera de guion y una tarjeta por plano.
class PlanSceneBlock extends StatelessWidget {
  final Scene scene;
  final PlanProjectData data;
  final void Function(PlanTarget target) onOpen;

  /// Enseña «Localización › Set» bajo la cabecera (vista por guion).
  final bool showLocation;

  const PlanSceneBlock({
    super.key,
    required this.scene,
    required this.data,
    required this.onOpen,
    this.showLocation = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = data.colors.sceneColor(scene);
    final location = locationFromCanonical(scene.locationCanonical);
    final shots = data.shotsOfScene(scene.id);
    final owner = data.set(scene.locationId);
    final site = data.site(scene.locationSiteId ?? owner?.siteId);
    final where = [
      site?.name ?? 'Sin localización',
      owner?.locationName ?? 'Sin set',
    ].join(' › ');

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SceneHeaderRow(
            sceneNumber: scene.number,
            sceneColor: color,
            title: scene.name.isNotEmpty
                ? scene.name
                : formatSceneTitle(
                    number: scene.number,
                    intExt: scene.intExt,
                    dayNight: scene.dayNight,
                    location: location,
                  ),
            subtitleWidget: SceneMetaDisplay(
              intExt: scene.intExt,
              dayNight: scene.dayNight,
              location: location,
              style: AppTypography.caption(palette),
            ),
            palette: palette,
          ),
          if (showLocation)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 2),
              child: Text(where, style: AppTypography.caption(palette)),
            ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: shots.isEmpty
                ? Text(
                    'Sin planos en esta escena.',
                    style: AppTypography.bodyMedium(palette),
                  )
                : Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final shot in shots)
                        PlanShotCard(shot: shot, data: data, onOpen: onOpen),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
