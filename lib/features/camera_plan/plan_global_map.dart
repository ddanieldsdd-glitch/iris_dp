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
                    _setupColumn(setup, palette.accent, focus: null),
                  _AddCard(label: 'Planta libre', onTap: () => _newSetup()),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _siteBlock(LocationSite site) {
    final palette = context.palette;
    final color = _data.colors.siteColor(site.id);
    final sets = _data.setsOfSite(site.id);
    final siteSetups = _data.setupsOfSite(site.id).where(_visible).toList();
    final setupCount =
        _data.setupsOfSite(site.id).length +
        sets.fold<int>(0, (n, s) => n + _data.setupsOfSet(s.id).length);
    final environment = _data.environmentOf(site.id);
    final zones = _data.zonesOfSite(site.id);

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
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.md,
          children: [
            _PlanCard(
              width: 300,
              thumbHeight: 200,
              color: color,
              kind: 'Plano maestro',
              title: site.name,
              details: [
                environment.isEmpty
                    ? 'Sin dibujar'
                    : '${environment.length} elementos',
                '${zones.length} de ${sets.length} sets con zona',
              ].join(' · '),
              thumbnail: PlanThumbnail(
                elements: environment,
                zones: zones,
                emptyIcon: Icons.map_outlined,
              ),
              onTap: () => widget.onOpen(PlanTarget.site(site.id, site.name)),
            ),
            if (siteSetups.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Luz general de la localización',
                    style: AppTypography.caption(palette),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      for (final setup in siteSetups)
                        _setupColumn(setup, color, focus: null),
                    ],
                  ),
                ],
              ),
          ],
        ),
        for (final (i, set) in sets.indexed)
          _TreeBranch(
            color: color,
            last: i == sets.length - 1,
            child: _setRow(set),
          ),
      ],
    );
  }

  Widget _setRow(LocationBasePlan set) {
    final palette = context.palette;
    final color = _data.colors.setColor(set);
    final own = _data.ownOfSet(set);
    final zone = _data.zoneOf(set);
    final scenes = _data.scenesOfSet(set.id);
    final shots = _data.shotsOfScenes(scenes);
    final withoutSetup = shots.where((s) => s.lightSetupId == null).toList();

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
              Flexible(
                child: Text(
                  set.locationName,
                  style: AppTypography.titleMedium(
                    palette,
                  ).copyWith(color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${scenes.length} esc. · '
                '${shots.length} plano${shots.length == 1 ? '' : 's'}',
                style: AppTypography.caption(palette),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlanCard(
                color: color,
                kind: 'Set',
                title: set.locationName,
                details: zone == null
                    ? 'Sin zona marcada'
                    : own.isEmpty
                    ? 'Zona del plano maestro'
                    : '${own.length} elementos propios',
                thumbnail: PlanThumbnail(
                  elements: own,
                  inherited: _data.environmentOf(set.siteId),
                  focus: zone,
                  emptyIcon: Icons.layers_outlined,
                ),
                onTap: () =>
                    widget.onOpen(PlanTarget.set(set.id, set.locationName)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: _thumbHeight / 2 - 12),
                child: Icon(Icons.arrow_right_alt, color: palette.textTertiary),
              ),
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final setup
                        in _data.setupsOfSet(set.id).where(_visible))
                      _setupColumn(setup, color, focus: zone),
                    _AddCard(
                      label: 'Esquema de luz',
                      onTap: () => _newSetup(setId: set.id),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (withoutSetup.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _ShotChips(
              label: 'Sin esquema de luz',
              shots: withoutSetup,
              data: _data,
              onOpen: widget.onOpen,
            ),
          ],
        ],
      ),
    );
  }

  /// Un esquema de luz con los planos que lo usan debajo.
  Widget _setupColumn(LightSetup setup, Color color, {required Rect? focus}) {
    final shots = _data.shotsOfSetup(setup.id);
    final origin = lightSetupOriginLabel(setup.origin);
    return SizedBox(
      width: _cardWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlanCard(
            color: color,
            kind: lightSetupStatusLabel(setup.status),
            kindIcon: setup.status == 'boceto'
                ? Icons.draw_outlined
                : Icons.wb_incandescent_outlined,
            title: setup.name,
            details: [
              if (origin.isNotEmpty) origin,
              if (setup.category?.isNotEmpty == true) setup.category!,
              '${shots.length} plano${shots.length == 1 ? '' : 's'}',
            ].join(' · '),
            thumbnail: PlanThumbnail(
              elements: _data.ownOfSetup(setup),
              inherited: _data.inheritedOfSetup(setup),
              inheritedOpacity: 0.22,
              focus: focus,
              emptyIcon: Icons.wb_incandescent_outlined,
            ),
            trailing: LightSetupMenuButton(
              setup: setup,
              shotCount: shots.length,
            ),
            onTap: () =>
                widget.onOpen(PlanTarget.lightSetup(setup.id, setup.name)),
          ),
          if (shots.isNotEmpty) ...[
            const SizedBox(height: 6),
            _ShotChips(shots: shots, data: _data, onOpen: widget.onOpen),
          ],
        ],
      ),
    );
  }
}

/// Planos como pastillas: tocar uno lo abre con su set y su luz.
class _ShotChips extends StatelessWidget {
  final String? label;
  final List<Shot> shots;
  final PlanProjectData data;
  final void Function(PlanTarget target) onOpen;

  const _ShotChips({
    required this.shots,
    required this.data,
    required this.onOpen,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (label != null)
          Text('$label:', style: AppTypography.caption(palette)),
        for (final shot in shots)
          Tooltip(
            message: data.shotLabel(shot),
            child: Material(
              color: palette.surfaceOverlay,
              borderRadius: BorderRadius.circular(6),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () =>
                    onOpen(PlanTarget.shot(shot.id, data.shotLabel(shot))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_outlined,
                        size: 13,
                        color: palette.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${data.scene(shot.sceneId)?.number ?? '–'}'
                        '·${shot.number}',
                        style: AppTypography.caption(
                          palette,
                        ).copyWith(color: palette.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Rama del árbol: el tronco baja desde la localización y un trazo corto
/// entra hasta el set.
class _TreeBranch extends StatelessWidget {
  final Color color;
  final bool last;
  final Widget child;

  const _TreeBranch({
    required this.color,
    required this.last,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 32,
          child: CustomPaint(
            painter: _BranchPainter(color: color, last: last),
          ),
        ),
        Padding(padding: const EdgeInsets.only(left: 32), child: child),
      ],
    );
  }
}

class _BranchPainter extends CustomPainter {
  final Color color;
  final bool last;

  /// Altura a la que entra el trazo: la del nombre del set.
  static const double _elbow = AppSpacing.lg + 11;

  const _BranchPainter({required this.color, required this.last});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const x = 12.0;
    canvas.drawLine(
      const Offset(x, 0),
      Offset(x, last ? _elbow : size.height),
      paint,
    );
    canvas.drawLine(
      const Offset(x, _elbow),
      Offset(size.width - 6, _elbow),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BranchPainter old) =>
      old.color != color || old.last != last;
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

const double _cardWidth = 190;
const double _thumbHeight = 130;

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
  final double width;
  final double thumbHeight;

  const _PlanCard({
    this.width = _cardWidth,
    this.thumbHeight = _thumbHeight,
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
      width: width,
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
                height: thumbHeight,
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
      width: 120,
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
