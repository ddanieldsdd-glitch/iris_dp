import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'floor_plan_repository.dart';
import 'light_setup_actions.dart';
import 'plan_data.dart';
import 'plan_target.dart';
import 'plan_thumbnail.dart';

/// Mapa global de plantas: cada localización con su entorno, sus sets y los
/// esquemas de luz de cada set, en miniaturas. Tocar una abre la pantalla de
/// trabajo ya situada en ella.
class PlanGlobalMap extends ConsumerStatefulWidget {
  final int projectId;
  final PlanProjectData data;
  final void Function(PlanTarget target) onOpen;

  const PlanGlobalMap({
    super.key,
    required this.projectId,
    required this.data,
    required this.onOpen,
  });

  @override
  ConsumerState<PlanGlobalMap> createState() => _PlanGlobalMapState();
}

class _PlanGlobalMapState extends ConsumerState<PlanGlobalMap> {
  /// `null` = todos los estados.
  String? _status;

  /// `null` = todas las localizaciones.
  int? _siteId;

  PlanProjectData get _data => widget.data;

  bool _visible(LightSetup setup) => _status == null || setup.status == _status;

  Future<void> _newSetup({int? setId, int? siteId}) async {
    final setup = await FloorPlanRepository(ref.read(databaseProvider))
        .createLightSetup(
          projectId: widget.projectId,
          setId: setId,
          siteId: siteId,
        );
    if (!mounted) return;
    widget.onOpen(PlanTarget.lightSetup(setup.id, setup.name));
  }

  Future<void> _newSet(LocationSite site) async {
    final name = await askPlanName(
      context,
      title: 'Nuevo set en ${site.name}',
      hint: 'Cocina, río, pasillo…',
    );
    if (name == null) return;
    await ref
        .read(databaseProvider)
        .insertLocation(
          LocationBasePlansCompanion.insert(
            projectId: widget.projectId,
            siteId: Value(site.id),
            locationName: name,
            sortOrder: Value(_data.setsOfSite(site.id).length),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sites = _data.sites
        .where((s) => _siteId == null || s.id == _siteId)
        .toList();
    final showExtras = _siteId == null;
    final orphanSets = showExtras ? _data.orphanSets : <LocationBasePlan>[];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _Filters(
          sites: _data.sites,
          siteId: _siteId,
          status: _status,
          onSite: (id) => setState(() => _siteId = id),
          onStatus: (s) => setState(() => _status = s),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_data.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            child: Text(
              'Aún no hay plantas. Crea una localización con «+», o empieza '
              'por una planta libre aquí abajo.',
              style: AppTypography.bodyMedium(palette),
            ),
          ),
        for (final site in sites) _siteBlock(site),
        if (orphanSets.isNotEmpty)
          _Block(
            color: palette.textTertiary,
            icon: Icons.layers_outlined,
            title: 'Sets sin localización',
            children: [for (final set in orphanSets) _setRow(set)],
          ),
        if (showExtras)
          _Block(
            color: palette.accent,
            icon: Icons.draw_outlined,
            title: 'Plantas libres',
            subtitle:
                'Esquemas de luz sin localización ni escenas, '
                'para bocetar antes de tener guion.',
            children: [
              _CardRow(
                children: [
                  for (final setup in _data.freeSetups.where(_visible))
                    _setupCard(setup, palette.accent),
                  _AddCard(label: 'Planta libre', onTap: () => _newSetup()),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _siteBlock(LocationSite site) {
    final color = _data.colors.siteColor(site.id);
    final sets = _data.setsOfSite(site.id);
    final setupCount =
        _data.setupsOfSite(site.id).length +
        sets.fold<int>(0, (n, s) => n + _data.setupsOfSet(s.id).length);
    final environment = _data.environmentOf(site.id);

    return _Block(
      color: color,
      icon: Icons.location_city_outlined,
      title: site.name,
      subtitle:
          '${sets.length} set${sets.length == 1 ? '' : 's'} · '
          '$setupCount esquema${setupCount == 1 ? '' : 's'} de luz',
      action: TextButton.icon(
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Set'),
        onPressed: () => _newSet(site),
      ),
      children: [
        _CardRow(
          children: [
            _PlanCard(
              color: color,
              kind: 'Entorno',
              title: site.name,
              details: environment.isEmpty
                  ? 'Sin dibujar'
                  : '${environment.length} elementos',
              thumbnail: PlanThumbnail(
                elements: environment,
                emptyIcon: Icons.map_outlined,
              ),
              onTap: () => widget.onOpen(PlanTarget.site(site.id, site.name)),
            ),
            for (final setup in _data.setupsOfSite(site.id).where(_visible))
              _setupCard(setup, color),
            _AddCard(
              label: 'Esquema de luz',
              onTap: () => _newSetup(siteId: site.id),
            ),
          ],
        ),
        for (final set in sets) _setRow(set),
      ],
    );
  }

  Widget _setRow(LocationBasePlan set) {
    final palette = context.palette;
    final color = _data.colors.setColor(set);
    final own = _data.ownOfSet(set);
    final scenes = _data.scenesOfSet(set.id);
    final shotCount = _data.shotsOfScenes(scenes).length;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                set.locationName,
                style: AppTypography.titleMedium(
                  palette,
                ).copyWith(color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${scenes.length} esc. · '
                '$shotCount plano${shotCount == 1 ? '' : 's'}',
                style: AppTypography.caption(palette),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _CardRow(
            children: [
              _PlanCard(
                color: color,
                kind: 'Set',
                title: set.locationName,
                details: own.isEmpty
                    ? 'Sin añadidos propios'
                    : '${own.length} elementos propios',
                thumbnail: PlanThumbnail(
                  elements: own,
                  inherited: _data.environmentOf(set.siteId),
                  emptyIcon: Icons.layers_outlined,
                ),
                onTap: () =>
                    widget.onOpen(PlanTarget.set(set.id, set.locationName)),
              ),
              for (final setup in _data.setupsOfSet(set.id).where(_visible))
                _setupCard(setup, color),
              _AddCard(
                label: 'Esquema de luz',
                onTap: () => _newSetup(setId: set.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _setupCard(LightSetup setup, Color color) {
    final shotCount = _data.shotsOfSetup(setup.id).length;
    final origin = lightSetupOriginLabel(setup.origin);
    return _PlanCard(
      color: color,
      kind: lightSetupStatusLabel(setup.status),
      kindIcon: setup.status == 'boceto'
          ? Icons.draw_outlined
          : Icons.wb_incandescent_outlined,
      title: setup.name,
      details: [
        if (origin.isNotEmpty) origin,
        if (setup.category?.isNotEmpty == true) setup.category!,
        '$shotCount plano${shotCount == 1 ? '' : 's'}',
      ].join(' · '),
      thumbnail: PlanThumbnail(
        elements: _data.ownOfSetup(setup),
        inherited: _data.inheritedOfSetup(setup),
        emptyIcon: Icons.wb_incandescent_outlined,
      ),
      trailing: LightSetupMenuButton(setup: setup, shotCount: shotCount),
      onTap: () => widget.onOpen(PlanTarget.lightSetup(setup.id, setup.name)),
    );
  }
}

class _Filters extends StatelessWidget {
  final List<LocationSite> sites;
  final int? siteId;
  final String? status;
  final ValueChanged<int?> onSite;
  final ValueChanged<String?> onStatus;

  const _Filters({
    required this.sites,
    required this.siteId,
    required this.status,
    required this.onSite,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('Todos'),
          selected: status == null,
          onSelected: (_) => onStatus(null),
        ),
        for (final s in kLightSetupStatuses)
          ChoiceChip(
            label: Text(lightSetupStatusLabel(s)),
            selected: status == s,
            onSelected: (_) => onStatus(status == s ? null : s),
          ),
        if (sites.length > 1) ...[
          const SizedBox(width: AppSpacing.md),
          DropdownButton<int?>(
            value: siteId,
            underline: const SizedBox.shrink(),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Todas las localizaciones'),
              ),
              for (final site in sites)
                DropdownMenuItem<int?>(value: site.id, child: Text(site.name)),
            ],
            onChanged: onSite,
          ),
        ],
      ],
    );
  }
}

/// Bloque de una localización (o de plantas libres) en el mapa.
class _Block extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;

  const _Block({
    required this.color,
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.titleLarge(palette)),
                    if (subtitle != null)
                      Text(subtitle!, style: AppTypography.caption(palette)),
                  ],
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  final List<Widget> children;

  const _CardRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: children,
    );
  }
}

const double _cardWidth = 216;
const double _thumbHeight = 150;

/// Tarjeta con la miniatura de una planta.
class _PlanCard extends StatelessWidget {
  final Color color;
  final String kind;
  final IconData? kindIcon;
  final String title;
  final String details;
  final Widget thumbnail;
  final Widget? trailing;
  final VoidCallback onTap;

  const _PlanCard({
    required this.color,
    required this.kind,
    required this.title,
    required this.details,
    required this.thumbnail,
    required this.onTap,
    this.kindIcon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: _cardWidth,
      child: Material(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: _thumbHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    thumbnail,
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (kindIcon != null) ...[
                              Icon(kindIcon, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              kind,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTypography.label(palette),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              details,
                              style: AppTypography.caption(palette),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    trailing ?? const SizedBox(width: AppSpacing.md),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddCard({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: 132,
      height: _thumbHeight,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: palette.accent),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.caption(palette),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
