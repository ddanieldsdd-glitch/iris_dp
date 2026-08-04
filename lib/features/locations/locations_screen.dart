import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../core/utils/scene_color.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/scene_color_picker.dart';
import 'location_form_sheet.dart';
import 'location_site_form_sheet.dart';
import 'location_site_tabs.dart';
import '../../core/widgets/app_snackbar.dart';

class LocationsScreen extends ConsumerStatefulWidget {
  final int projectId;
  final int? initialSiteId;
  final int? initialSetId;

  const LocationsScreen({
    super.key,
    required this.projectId,
    this.initialSiteId,
    this.initialSetId,
  });

  @override
  ConsumerState<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends ConsumerState<LocationsScreen> {
  int? _selectedSiteId;
  int? _expandedSetId;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _selectedSiteId = widget.initialSiteId;
    _expandedSetId = widget.initialSetId;
  }

  Future<void> _syncFromScenes() async {
    setState(() => _syncing = true);
    try {
      final db = ref.read(databaseProvider);
      final created = await db.syncLocationsFromScenes(widget.projectId);
      if (!mounted) return;
      AppSnackBar.show(context, created > 0
                ? '$created localización(es) o set(s) creado(s) desde escenas.'
                : 'Todo sincronizado. Escenas re-vinculadas.');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _addSet({required int siteId}) async {
    final db = ref.read(databaseProvider);
    final nextSortOrder = await db.countSetsForSite(siteId);
    if (!mounted) return;
    await showLocationFormSheet(
      context,
      projectId: widget.projectId,
      siteId: siteId,
      nextSortOrder: nextSortOrder,
    );
  }

  Future<void> _editSet(LocationBasePlan set) async {
    if (set.siteId == null) return;
    await showLocationFormSheet(
      context,
      projectId: widget.projectId,
      siteId: set.siteId!,
      location: set,
    );
    if (mounted) setState(() {});
  }

  Future<void> _addSite(List<LocationSite> existing) async {
    final result = await showLocationSiteFormSheet(
      context,
      projectId: widget.projectId,
      nextSortOrder: existing.length,
    );
    if (!mounted || result == null || !result.saved) return;
    setState(() {
      _selectedSiteId = result.siteId;
      _expandedSetId = null;
    });
  }

  Future<void> _editSite(LocationSite site) async {
    await showLocationSiteFormSheet(
      context,
      projectId: widget.projectId,
      site: site,
    );
    if (mounted) setState(() {});
  }

  Future<void> _deleteSet(LocationBasePlan set) async {
    final db = ref.read(databaseProvider);
    if (set.siteId != null) {
      final setCount = await db.countSetsForSite(set.siteId!);
      if (setCount <= 1) {
        if (!mounted) return;
        AppSnackBar.show(context, 'Cada localización debe tener al menos un set. '
              'Crea otro set antes de eliminar este.');
        return;
      }
    }
    final count = await db.countScenesForLocation(set.id);
    if (!mounted) return;
    final palette = context.palette;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text('Eliminar set de rodaje',
            style: AppTypography.titleLarge(palette)),
        content: Text(
          count > 0
              ? '«${set.locationName}» tiene $count escena(s) vinculada(s). '
                  'Se desvincularán pero no se borrarán.'
              : '¿Eliminar «${set.locationName}»?',
          style: AppTypography.bodyLarge(palette),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar',
                style: AppTypography.bodyMedium(palette)
                    .copyWith(color: palette.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await db.deleteLocation(set.id);
    if (mounted && _expandedSetId == set.id) {
      setState(() => _expandedSetId = null);
    }
  }

  Future<void> _deleteSite(LocationSite site) async {
    final db = ref.read(databaseProvider);
    final setCount = await db.countSetsForSite(site.id);
    if (!mounted) return;
    final palette = context.palette;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title:
            Text('Eliminar localización', style: AppTypography.titleLarge(palette)),
        content: Text(
          setCount > 0
              ? '«${site.name}» tiene $setCount set(s). Los sets quedarán sueltos '
                  'pero no se borrarán.'
              : '¿Eliminar «${site.name}»?',
          style: AppTypography.bodyLarge(palette),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar',
                style: AppTypography.bodyMedium(palette)
                    .copyWith(color: palette.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await db.deleteSite(site.id);
    if (mounted && _selectedSiteId == site.id) {
      setState(() {
        _selectedSiteId = null;
        _expandedSetId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('Localizaciones', style: AppTypography.titleLarge(palette)),
        actions: [
          TextButton.icon(
            onPressed: _syncing ? null : _syncFromScenes,
            icon: _syncing
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.accent,
                    ),
                  )
                : Icon(Icons.sync, color: palette.accent, size: 18),
            label: Text(
              'Desde escenas',
              style: AppTypography.caption(palette).copyWith(color: palette.accent),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: StreamBuilder<List<LocationSite>>(
        stream: db.watchSitesForProject(widget.projectId),
        builder: (context, siteSnap) {
          return StreamBuilder<List<LocationBasePlan>>(
            stream: db.watchLocationsForProject(widget.projectId),
            builder: (context, setSnap) {
              return StreamBuilder<List<Scene>>(
                stream: db.watchScenesForProject(widget.projectId),
                builder: (context, sceneSnap) {
              final sites = siteSnap.data ?? [];
              final sets = setSnap.data ?? [];
              if (!siteSnap.hasData ||
                  !setSnap.hasData ||
                  !sceneSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final sceneCountBySite = <int, int>{};
              for (final scene in sceneSnap.data ?? []) {
                if (scene.locationSiteId != null) {
                  sceneCountBySite[scene.locationSiteId!] =
                      (sceneCountBySite[scene.locationSiteId!] ?? 0) + 1;
                }
              }

              if (sites.isEmpty) {
                return _EmptyLocationsState(
                  palette: palette,
                  syncing: _syncing,
                  onSync: _syncFromScenes,
                  onAddSite: () => _addSite(sites),
                );
              }

              final activeSiteId = _resolveActiveSiteId(sites);
              final colors = ProjectColorScheme.resolve(
                sites: sites,
                sets: sets,
                scenes: sceneSnap.data ?? [],
              );

              LocationSite? selectedSite;
              for (final s in sites) {
                if (s.id == activeSiteId) {
                  selectedSite = s;
                  break;
                }
              }

              Widget buildSidebar({bool compact = false}) => _LocationsSidebar(
                    sites: sites,
                    sets: sets,
                    colors: colors,
                    sceneCountBySite: sceneCountBySite,
                    selectedSiteId: activeSiteId,
                    onSelectSite: (id) => setState(() {
                      _selectedSiteId = id;
                      _expandedSetId = null;
                    }),
                    onAddSite: () => _addSite(sites),
                    compact: compact,
                  );

              Widget detail;
              if (selectedSite != null) {
                final site = selectedSite;
                detail = _SiteDetailPanel(
                  projectId: widget.projectId,
                  site: site,
                  colors: colors,
                  expandedSetId: _expandedSetId,
                  onExpandedSetChanged: (id) =>
                      setState(() => _expandedSetId = id),
                  onEdit: () => _editSite(site),
                  onDelete: () => _deleteSite(site),
                  onEditSet: (set) => _editSet(set),
                  onDeleteSet: (set) => _deleteSet(set),
                  onAddSet: () => _addSet(siteId: site.id),
                );
              } else {
                detail = Center(
                  child: Text(
                    'Selecciona una localización.',
                    style: AppTypography.bodyMedium(palette),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= AppLayout.wideBreakpoint;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: AppLayout.sidebarWidth, child: buildSidebar()),
                        VerticalDivider(width: 1, color: palette.divider),
                        Expanded(child: detail),
                      ],
                    );
                  }

                  if (selectedSite != null) {
                    return _SiteDetailPanel(
                      projectId: widget.projectId,
                      site: selectedSite,
                      colors: colors,
                      expandedSetId: _expandedSetId,
                      onExpandedSetChanged: (id) =>
                          setState(() => _expandedSetId = id),
                      onEdit: () => _editSite(selectedSite!),
                      onDelete: () => _deleteSite(selectedSite!),
                      onEditSet: (set) => _editSet(set),
                      onDeleteSet: (set) => _deleteSet(set),
                      onAddSet: () => _addSet(siteId: selectedSite!.id),
                      listHeader: buildSidebar(compact: true),
                    );
                  }

                  return buildSidebar();
                },
              );
                },
              );
            },
          );
        },
      ),
    );
  }

  int? _resolveActiveSiteId(List<LocationSite> sites) {
    if (sites.isEmpty) return null;
    if (_selectedSiteId != null &&
        sites.any((s) => s.id == _selectedSiteId)) {
      return _selectedSiteId;
    }
    return sites.first.id;
  }
}

class _EmptyLocationsState extends StatelessWidget {
  final AppPalette palette;
  final bool syncing;
  final VoidCallback onSync;
  final VoidCallback onAddSite;

  const _EmptyLocationsState({
    required this.palette,
    required this.syncing,
    required this.onSync,
    required this.onAddSite,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_city_outlined,
                  size: 56, color: palette.textTertiary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Sin localizaciones',
                style: AppTypography.titleMedium(palette),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Crea una localización (ej. BOSQUE) y añade sets dentro '
                '(RÍO, ENTRADA…), o importa desde el guion literario.',
                style: AppTypography.bodyMedium(palette),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Importar desde escenas',
                icon: Icons.sync,
                onTap: syncing ? null : onSync,
                loading: syncing,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Nueva localización',
                icon: Icons.location_city_outlined,
                variant: AppButtonVariant.secondary,
                onTap: onAddSite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationsSidebar extends StatelessWidget {
  final List<LocationSite> sites;
  final List<LocationBasePlan> sets;
  final ProjectColorScheme colors;
  final Map<int, int> sceneCountBySite;
  final int? selectedSiteId;
  final ValueChanged<int> onSelectSite;
  final VoidCallback onAddSite;
  final bool compact;

  const _LocationsSidebar({
    required this.sites,
    required this.sets,
    required this.colors,
    required this.sceneCountBySite,
    required this.selectedSiteId,
    required this.onSelectSite,
    required this.onAddSite,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final setsBySite = <int, int>{};
    for (final set in sets) {
      if (set.siteId != null) {
        setsBySite[set.siteId!] = (setsBySite[set.siteId!] ?? 0) + 1;
      }
    }

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Localizaciones',
                      style: AppTypography.label(palette)),
                ),
                TextButton.icon(
                  onPressed: onAddSite,
                  icon: Icon(Icons.add, color: palette.accent, size: 16),
                  label: Text('Nueva',
                      style: AppTypography.caption(palette)
                          .copyWith(color: palette.accent)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: sites.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final site = sites[i];
                return _SiteChip(
                  site: site,
                  siteColor: colors.siteColor(site.id),
                  setCount: setsBySite[site.id] ?? 0,
                  sceneCount: sceneCountBySite[site.id] ?? 0,
                  selected: site.id == selectedSiteId,
                  onTap: () => onSelectSite(site.id),
                );
              },
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${sites.length} localización(es)',
                  style: AppTypography.label(palette),
                ),
              ),
              TextButton.icon(
                onPressed: onAddSite,
                icon: Icon(Icons.add, color: palette.accent, size: 16),
                label: Text('Nueva',
                    style: AppTypography.caption(palette)
                        .copyWith(color: palette.accent)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: sites.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final site = sites[i];
              return _SiteListTile(
                site: site,
                siteColor: colors.siteColor(site.id),
                setCount: setsBySite[site.id] ?? 0,
                sceneCount: sceneCountBySite[site.id] ?? 0,
                selected: site.id == selectedSiteId,
                onTap: () => onSelectSite(site.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SiteChip extends StatelessWidget {
  final LocationSite site;
  final Color siteColor;
  final int setCount;
  final int sceneCount;
  final bool selected;
  final VoidCallback onTap;

  const _SiteChip({
    required this.site,
    required this.siteColor,
    required this.setCount,
    required this.sceneCount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: selected
          ? siteColor.withValues(alpha: 0.15)
          : palette.surfaceElevated,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? siteColor : palette.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: siteColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 4),
              Text(site.name,
                  style: AppTypography.label(palette),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              Text(
                '$sceneCount esc · $setCount sets',
                style: AppTypography.caption(palette),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiteListTile extends StatelessWidget {
  final LocationSite site;
  final Color siteColor;
  final int setCount;
  final int sceneCount;
  final bool selected;
  final VoidCallback onTap;

  const _SiteListTile({
    required this.site,
    required this.siteColor,
    required this.setCount,
    required this.sceneCount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      onTap: onTap,
      focused: selected,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: siteColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _LocationMetricBadge(
            value: sceneCount,
            label: 'esc',
            palette: palette,
            tint: siteColor,
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.location_city_outlined,
              color: siteColor, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(site.name, style: AppTypography.bodyLarge(palette)),
                if (site.description != null && site.description!.isNotEmpty)
                  Text(site.description!,
                      style: AppTypography.caption(palette),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          _LocationMetricBadge(
            value: setCount,
            label: 'sets',
            palette: palette,
            tint: siteColor,
            alignEnd: true,
          ),
        ],
      ),
    );
  }
}

class _LocationMetricBadge extends StatelessWidget {
  final int value;
  final String label;
  final AppPalette palette;
  final Color? tint;
  final bool alignEnd;

  const _LocationMetricBadge({
    required this.value,
    required this.label,
    required this.palette,
    this.tint,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = tint ?? palette.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.center,
        children: [
          Text('$value', style: AppTypography.mono(palette)),
          Text(label, style: AppTypography.caption(palette)),
        ],
      ),
    );
  }
}

class _SiteDetailPanel extends ConsumerStatefulWidget {
  final int projectId;
  final LocationSite site;
  final ProjectColorScheme colors;
  final int? expandedSetId;
  final ValueChanged<int?> onExpandedSetChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<LocationBasePlan> onEditSet;
  final ValueChanged<LocationBasePlan> onDeleteSet;
  final VoidCallback onAddSet;
  final Widget? listHeader;

  const _SiteDetailPanel({
    required this.projectId,
    required this.site,
    required this.colors,
    required this.expandedSetId,
    required this.onExpandedSetChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onEditSet,
    required this.onDeleteSet,
    required this.onAddSet,
    this.listHeader,
  });

  @override
  ConsumerState<_SiteDetailPanel> createState() => _SiteDetailPanelState();
}

class _SiteDetailPanelState extends ConsumerState<_SiteDetailPanel> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _editSiteColor() async {
    final palette = context.palette;
    final site = widget.site;
    final current = widget.colors.siteColor(site.id);
    var picked = hexFromColor(current);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: palette.surfaceElevated,
              title: Text(
                'Color de «${site.name}»',
                style: AppTypography.titleMedium(palette),
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'El color base se aplicará a todos los sets y escenas '
                      'de esta localización.',
                      style: AppTypography.bodyMedium(palette),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SceneColorPicker(
                      palette: palette,
                      selectedHex: picked,
                      onChanged: (hex) => setDialogState(() => picked = hex),
                      hint: 'Color base de la localización.',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text('Cancelar',
                      style: AppTypography.bodyMedium(palette)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(
                    'Aplicar',
                    style: AppTypography.bodyMedium(palette)
                        .copyWith(color: palette.accent),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final db = ref.read(databaseProvider);
    await db.applySiteColorFromBase(site.id, picked);
    if (!mounted) return;
    AppSnackBar.show(
      context,
      'Color de «${site.name}» actualizado en todos sus sets.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final site = widget.site;
    final siteColor = widget.colors.siteColor(site.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.listHeader != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: widget.listHeader!,
          ),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            widget.listHeader != null ? AppSpacing.lg : AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: siteColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: siteColor, width: 5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: _editSiteColor,
                            borderRadius: BorderRadius.circular(12),
                            child: Tooltip(
                              message: 'Cambiar color de la localización',
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: siteColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(site.name,
                                style: AppTypography.titleLarge(palette)
                                    .copyWith(color: siteColor)),
                          ),
                        ],
                      ),
                      if (site.description != null &&
                          site.description!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(site.description!,
                            style: AppTypography.bodyMedium(palette)),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar',
                  onPressed: widget.onEdit,
                  icon: Icon(Icons.edit_outlined,
                      color: palette.textSecondary, size: 20),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: widget.onDelete,
                  icon: Icon(Icons.delete_outline,
                      color: palette.error, size: 20),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SiteSetsSection(
                  projectId: widget.projectId,
                  site: site,
                  colors: widget.colors,
                  expandedSetId: widget.expandedSetId,
                  onExpandedSetChanged: widget.onExpandedSetChanged,
                  onEditSet: widget.onEditSet,
                  onDeleteSet: widget.onDeleteSet,
                  onAddSet: widget.onAddSet,
                ),
                const SizedBox(height: AppSpacing.xxl),
                SiteBaseSection(
                  projectId: widget.projectId,
                  site: site,
                  colors: widget.colors,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

