import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/project/project_shoot_context.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../locations/location_form_sheet.dart';
import '../../../locations/location_site_form_sheet.dart';

/// Separador visual entre Acto 1 (global) y Acto 2 (por localización).
class LightingActDivider extends StatelessWidget {
  final String label;

  const LightingActDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: palette.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label.toUpperCase(),
              style: AppTypography.mono(palette).copyWith(
                fontSize: 11,
                letterSpacing: 1.4,
                color: palette.accent,
              ),
            ),
          ),
          Expanded(child: Divider(color: palette.border)),
        ],
      ),
    );
  }
}

/// Selector site/set compartido con Localizaciones y ProjectShootContext.
class LightingLocationHub extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final int? selectedPlanId;
  final ValueChanged<LocationBasePlan> onSelectSet;
  final VoidCallback? onClearSet;

  const LightingLocationHub({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.selectedPlanId,
    required this.onSelectSet,
    this.onClearSet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<LocationSite>>(
      stream: db.watchSitesForProject(projectId),
      builder: (context, siteSnap) {
        final sites = siteSnap.data ?? [];
        return StreamBuilder<List<LocationBasePlan>>(
          stream: db.watchLocationsForProject(projectId),
          builder: (context, setSnap) {
            final sets = setSnap.data ?? [];
            if (sets.isEmpty) {
              return _GlassMini(
                palette: palette,
                child: Text(
                  'No hay sets definidos. Créalos en Localizaciones o importa el guion.',
                  style: AppTypography.bodyMedium(palette).copyWith(
                    color: palette.textTertiary,
                  ),
                ),
              );
            }

            LocationBasePlan? active;
            for (final s in sets) {
              if (s.id == selectedPlanId) {
                active = s;
                break;
              }
            }

            String? siteLabel;
            if (active?.siteId != null) {
              for (final site in sites) {
                if (site.id == active!.siteId) {
                  siteLabel = site.name;
                  break;
                }
              }
            }

            return StreamBuilder<List<VisualBibleLocationRef>>(
              stream: db.watchLocationRefsForBible(bibleId),
              builder: (context, refSnap) {
                VisualBibleLocationRef? locRef;
                if (active != null) {
                  for (final r in refSnap.data ?? []) {
                    if (r.locationBasePlanId == active!.id) {
                      locRef = r;
                      break;
                    }
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GlassMini(
                      palette: palette,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SET ACTIVO',
                            style: AppTypography.mono(palette).copyWith(
                              fontSize: 10,
                              letterSpacing: 1.2,
                              color: palette.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final set in sets)
                                ChoiceChip(
                                  label: Text(set.locationName),
                                  selected: set.id == selectedPlanId,
                                  onSelected: (_) {
                                    onSelectSet(set);
                                    ref
                                        .read(
                                          projectShootContextProvider(projectId)
                                              .notifier,
                                        )
                                        .setActive(
                                          siteId: set.siteId,
                                          setId: set.id,
                                        );
                                  },
                                ),
                              if (onClearSet != null)
                                ActionChip(
                                  label: const Text('Global'),
                                  onPressed: onClearSet,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () => showLocationSiteFormSheet(
                                  context,
                                  projectId: projectId,
                                ),
                                icon: Icon(Icons.add, size: 16, color: palette.accent),
                                label: Text(
                                  'Nueva localización',
                                  style: TextStyle(color: palette.accent, fontSize: 12),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  final siteId = active?.siteId ?? sites.firstOrNull?.id;
                                  if (siteId == null) return;
                                  showLocationFormSheet(
                                    context,
                                    projectId: projectId,
                                    siteId: siteId,
                                  );
                                },
                                icon: Icon(Icons.add, size: 16, color: palette.accent),
                                label: Text(
                                  'Nuevo set',
                                  style: TextStyle(color: palette.accent, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (active != null) ...[
                      const SizedBox(height: 12),
                      _GlassMini(
                        palette: palette,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              active!.locationName.toUpperCase(),
                              style: AppTypography.titleMedium(palette).copyWith(
                                fontSize: 16,
                              ),
                            ),
                            if (siteLabel != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                siteLabel!,
                                style: AppTypography.caption(palette).copyWith(
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                            if (locRef?.solarOrientation?.isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Orientación solar: ${locRef!.solarOrientation}',
                                style: AppTypography.bodyMedium(palette).copyWith(
                                  fontSize: 13,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                            if (locRef?.availableLightHours?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Horas de luz: ${locRef!.availableLightHours}',
                                style: AppTypography.bodyMedium(palette).copyWith(
                                  fontSize: 13,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                            if (locRef?.existingPracticals?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Prácticos: ${locRef!.existingPracticals}',
                                style: AppTypography.bodyMedium(palette).copyWith(
                                  fontSize: 13,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _GlassMini extends StatelessWidget {
  final AppPalette palette;
  final Widget child;

  const _GlassMini({required this.palette, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}
