import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../camera_plan/floor_plan_repository.dart';
import '../camera_plan/plan_target.dart';
import '../camera_plan/plan_workspace_screen.dart';

/// Esquemas de luz y cámara de la localización (los suyos y los de sus
/// sets), y «Enlazar planta libre» para traer aquí una planta sin sitio.
class SitePlansSection extends ConsumerWidget {
  final int projectId;
  final LocationSite site;

  const SitePlansSection({
    super.key,
    required this.projectId,
    required this.site,
  });

  void _open(BuildContext context, LightSetup setup) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanWorkspaceScreen(
          projectId: projectId,
          initial: PlanTarget.lightSetup(setup.id, setup.name),
        ),
      ),
    );
  }

  Future<void> _linkFree(
    BuildContext context,
    AppDatabase db,
    List<LightSetup> free,
  ) async {
    final palette = context.palette;
    final picked = await showModalBottomSheet<LightSetup>(
      context: context,
      backgroundColor: palette.surface,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                'Enlazar a «${site.name}»',
                style: AppTypography.titleMedium(palette),
              ),
            ),
            for (final setup in free)
              ListTile(
                leading: Icon(Icons.draw_outlined, color: palette.accent),
                title: Text(setup.name),
                onTap: () => Navigator.pop(ctx, setup),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await db.updateLightSetup(picked.copyWith(locationSiteId: Value(site.id)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<LocationBasePlan>>(
      stream: db.watchSetsForSite(site.id),
      builder: (context, setSnap) {
        final sets = {for (final s in setSnap.data ?? const []) s.id: s};
        return StreamBuilder<List<LightSetup>>(
          stream: db.watchLightSetupsForProject(projectId),
          builder: (context, snap) {
            final plans = (snap.data ?? const <LightSetup>[])
                .where((s) => !LightSetupKind.isSketch(s))
                .toList();
            final mine = plans
                .where((s) =>
                    s.locationSiteId == site.id ||
                    sets.containsKey(s.locationBasePlanId))
                .toList();
            final free = plans
                .where((s) =>
                    s.locationSiteId == null && s.locationBasePlanId == null)
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Plantas de luz y cámara',
                        style: AppTypography.titleMedium(palette),
                      ),
                    ),
                    if (free.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _linkFree(context, db, free),
                        icon: Icon(Icons.link, color: palette.accent, size: 18),
                        label: Text(
                          'Enlazar planta libre',
                          style: AppTypography.caption(palette)
                              .copyWith(color: palette.accent),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (mine.isEmpty)
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      free.isEmpty
                          ? 'Sin esquemas todavía. Créalos en «Plantas».'
                          : 'Sin esquemas. Enlaza una planta libre o crea '
                              'uno en «Plantas».',
                      style: AppTypography.caption(palette),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final setup in mine)
                          ListTile(
                            leading: Icon(
                              Icons.lightbulb_outline,
                              color: palette.accent,
                            ),
                            title: Text(
                              setup.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              sets[setup.locationBasePlanId]?.locationName ??
                                  'Toda la localización',
                              style: AppTypography.caption(palette),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _open(context, setup),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
