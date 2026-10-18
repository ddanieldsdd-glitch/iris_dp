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
import 'plan_item_actions.dart';
import 'plan_shot_card.dart';
import 'plan_target.dart';
import 'plan_thumbnail.dart';
import 'plan_trash_ui.dart';

/// Mapa global de plantas: cada localización con su entorno, sus sets y los
/// esquemas de luz de cada set, en miniaturas. Tocar una abre la pantalla de
/// trabajo ya situada en ella.
class PlanGlobalMap extends ConsumerStatefulWidget {
  final int projectId;
  final PlanProjectData data;
  final void Function(PlanTarget target) onOpen;

  /// Solo esta localización: es su ficha. `null` = todo el proyecto.
  final int? siteId;

  /// Tocar la cabecera de una escena abre su tablero.
  final ValueChanged<Scene>? onScene;

  const PlanGlobalMap({
    super.key,
    required this.projectId,
    required this.data,
    required this.onOpen,
    this.siteId,
    this.onScene,
  });

  @override
  ConsumerState<PlanGlobalMap> createState() => _PlanGlobalMapState();
}

class _PlanGlobalMapState extends ConsumerState<PlanGlobalMap> {
  /// `null` = todas las localizaciones.
  late int? _siteId = widget.siteId;

  @override
  void didUpdateWidget(PlanGlobalMap old) {
    super.didUpdateWidget(old);
    if (old.siteId != widget.siteId) _siteId = widget.siteId;
  }

  PlanProjectData get _data => widget.data;

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
    final looseScenes = showExtras
        ? _data.scenesWithoutLocation
        : const <Scene>[];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (_data.sites.length > 1 && widget.siteId == null) ...[
          _Filters(
            sites: _data.sites,
            siteId: _siteId,
            onSite: (id) => setState(() => _siteId = id),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (_data.isEmpty && _data.scenes.isEmpty)
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
            children: [
              for (final (i, set) in orphanSets.indexed)
                _TreeBranch(
                  color: palette.textTertiary,
                  last: i == orphanSets.length - 1,
                  child: _setSection(set),
                ),
            ],
          ),
        if (looseScenes.isNotEmpty)
          _Block(
            color: palette.textTertiary,
            icon: Icons.help_outline,
            title: 'Sin localización',
            subtitle: 'Escenas que aún no tienen localización ni set.',
            children: [
              for (final scene in looseScenes)
                PlanSceneBlock(
                  onScene: widget.onScene,
                  scene: scene,
                  data: _data,
                  onOpen: widget.onOpen,
                ),
            ],
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
              _setupLegend(
                _data.freeSetups,
                paste: const PlanPasteTarget.free(),
                onAdd: () => _newSetup(),
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
    final siteSetups = _data.setupsOfSite(site.id);
    final withoutSet = _data.scenesOfSiteWithoutSet(site.id);
    final sceneCount =
        withoutSet.length +
        sets.fold<int>(0, (n, s) => n + _data.scenesOfSet(s.id).length);
    final branches = <Widget>[
      for (final set in sets) _setSection(set),
      if (withoutSet.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sin set',
                style: AppTypography.titleMedium(
                  palette,
                ).copyWith(color: palette.textSecondary),
              ),
              for (final scene in withoutSet)
                PlanSceneBlock(
                  onScene: widget.onScene,
                  scene: scene,
                  data: _data,
                  onOpen: widget.onOpen,
                ),
            ],
          ),
        ),
    ];

    return _Block(
      color: color,
      icon: Icons.location_city_outlined,
      title: site.name,
      subtitle:
          '${sets.length} set${sets.length == 1 ? '' : 's'} · '
          '$sceneCount escena${sceneCount == 1 ? '' : 's'}',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlanPasteButton(target: PlanPasteTarget(siteId: site.id)),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Set'),
            onPressed: () => _newSet(site),
          ),
          const SizedBox(width: AppSpacing.sm),
          _MiniPlan(
            label: 'Plano maestro',
            color: color,
            width: 132,
            height: 88,
            thumbnail: PlanThumbnail(
              elements: _data.environmentOf(site.id),
              zones: _data.zonesOfSite(site.id),
              routes: _data.routesThroughSite(site.id),
              emptyIcon: Icons.map_outlined,
            ),
            onTap: () => widget.onOpen(PlanTarget.site(site.id, site.name)),
          ),
          SiteMenuButton(site: site),
        ],
      ),
      children: [
        if (siteSetups.isNotEmpty)
          _setupLegend(
            siteSetups,
            label: 'Luz general',
            paste: PlanPasteTarget(siteId: site.id),
            onAdd: () => _newSetup(siteId: site.id),
          ),
        for (final (i, branch) in branches.indexed)
          _TreeBranch(
            color: color,
            last: i == branches.length - 1,
            child: branch,
          ),
      ],
    );
  }

  /// Un set: su plano, la leyenda de sus esquemas de luz y sus escenas.
  Widget _setSection(LocationBasePlan set) {
    final palette = context.palette;
    final color = _data.colors.setColor(set);
    final scenes = _data.scenesOfSet(set.id);
    final shotCount = _data.shotsOfScenes(scenes).length;
    final setupCount = _data.setupsOfSet(set.id).length;
    final actions = SetActions(
      context,
      ref.read(databaseProvider),
      set,
      sceneCount: scenes.length,
      setupCount: setupCount,
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PlanItemKeys(
                onCopy: actions.copy,
                onDuplicate: actions.duplicate,
                onPaste: actions.paste,
                onDelete: actions.delete,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      set.locationName,
                      style: AppTypography.titleMedium(
                        palette,
                      ).copyWith(color: color),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${scenes.length} esc. · '
                      '$shotCount plano${shotCount == 1 ? '' : 's'}',
                      style: AppTypography.caption(palette),
                    ),
                    SetMenuButton(
                      set: set,
                      sceneCount: scenes.length,
                      setupCount: setupCount,
                    ),
                  ],
                ),
              ),
              _MiniPlan(
                label: 'Set',
                color: color,
                thumbnail: PlanThumbnail(
                  elements: _data.ownOfSet(set),
                  inherited: _data.environmentOf(set.siteId),
                  focus: _data.zoneOf(set),
                  emptyIcon: Icons.layers_outlined,
                ),
                onTap: () =>
                    widget.onOpen(PlanTarget.set(set.id, set.locationName)),
              ),
              _setupLegend(
                _data.setupsOfSet(set.id),
                paste: PlanPasteTarget(setId: set.id),
                onAdd: () => _newSetup(setId: set.id),
              ),
            ],
          ),
          if (scenes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Sin escenas en este set.',
                style: AppTypography.bodyMedium(palette),
              ),
            ),
          for (final scene in scenes)
            PlanSceneBlock(
              scene: scene,
              data: _data,
              onOpen: widget.onOpen,
              onScene: widget.onScene,
            ),
        ],
      ),
    );
  }

  /// Leyenda «Luz»: una pastilla por esquema, con su color.
  Widget _setupLegend(
    List<LightSetup> setups, {
    String label = 'Luz',
    required PlanPasteTarget paste,
    required VoidCallback onAdd,
  }) {
    final palette = context.palette;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$label:', style: AppTypography.caption(palette)),
        for (final setup in setups)
          _SetupChip(
            setup: setup,
            color: _data.setupColor(setup),
            shotCount: _data.shotsOfSetup(setup.id).length,
            onTap: () =>
                widget.onOpen(PlanTarget.lightSetup(setup.id, setup.name)),
          ),
        IconButton(
          tooltip: 'Nuevo esquema de luz',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.add, size: 18, color: palette.accent),
          onPressed: onAdd,
        ),
        PlanPasteButton(target: paste),
      ],
    );
  }
}

/// Pastilla de un esquema de luz en la leyenda de su set.
class _SetupChip extends StatelessWidget {
  final LightSetup setup;
  final Color color;
  final int shotCount;
  final VoidCallback onTap;

  const _SetupChip({
    required this.setup,
    required this.color,
    required this.shotCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final origin = lightSetupOriginLabel(setup.origin);
    final actions = LightSetupActions(
      context,
      ProviderScope.containerOf(context).read(databaseProvider),
      setup,
      shotCount,
    );
    return PlanItemKeys(
      onCopy: actions.copy,
      onDuplicate: actions.duplicate,
      onPaste: actions.pasteBeside,
      onDelete: actions.delete,
      child: Material(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(setup.name, style: AppTypography.label(palette)),
                    Text(
                      [
                        lightSetupStatusLabel(setup.status),
                        if (origin.isNotEmpty) origin,
                        if (setup.category?.isNotEmpty == true) setup.category!,
                        '$shotCount plano${shotCount == 1 ? '' : 's'}',
                      ].join(' · '),
                      style: AppTypography.caption(palette),
                    ),
                  ],
                ),
                LightSetupMenuButton(setup: setup, shotCount: shotCount),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Miniatura pequeña de un plano maestro o de un set, con su rótulo.
class _MiniPlan extends StatelessWidget {
  final String label;
  final Color color;
  final Widget thumbnail;
  final VoidCallback onTap;
  final double width;
  final double height;

  const _MiniPlan({
    required this.label,
    required this.color,
    required this.thumbnail,
    required this.onTap,
    this.width = 96,
    this.height = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Abrir $label'.toLowerCase().replaceFirst('a', 'A'),
      child: Material(
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                thumbnail,
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final List<LocationSite> sites;
  final int? siteId;
  final ValueChanged<int?> onSite;

  const _Filters({
    required this.sites,
    required this.siteId,
    required this.onSite,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DropdownButton<int?>(
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
