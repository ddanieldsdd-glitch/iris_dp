import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_editor.dart';
import 'floor_plan_scope.dart';
import 'plan_data.dart';
import 'plan_target.dart';
import 'plan_thumbnail.dart';

/// Pantalla única de trabajo: el editor de la planta abierta y, al lado, un
/// navegador para cambiar de set, esquema de luz, plano o localización sin
/// volver al mapa global.
class PlanWorkspaceScreen extends StatefulWidget {
  final int projectId;
  final PlanTarget initial;

  const PlanWorkspaceScreen({
    super.key,
    required this.projectId,
    required this.initial,
  });

  @override
  State<PlanWorkspaceScreen> createState() => _PlanWorkspaceScreenState();
}

class _PlanWorkspaceScreenState extends State<PlanWorkspaceScreen> {
  late PlanTarget _target = widget.initial;
  bool? _navigatorOpen;

  void _open(PlanTarget target) {
    if (target == _target) return;
    setState(() => _target = target);
  }

  Widget _editor() {
    final key = ValueKey('${_target.scope.name}:${_target.id}:${_target.leg}');
    return switch (_target.scope) {
      FloorPlanScope.site => CameraPlanEditor.site(
        key: key,
        projectId: widget.projectId,
        siteId: _target.id,
        siteName: _target.label,
        onNavigate: _open,
      ),
      FloorPlanScope.set => CameraPlanEditor.set(
        key: key,
        projectId: widget.projectId,
        setId: _target.id,
        setName: _target.label,
        onNavigate: _open,
      ),
      FloorPlanScope.lightSetup => CameraPlanEditor.lightSetup(
        key: key,
        projectId: widget.projectId,
        lightSetupId: _target.id,
        setupName: _target.label,
        onNavigate: _open,
      ),
      FloorPlanScope.shot => CameraPlanEditor.shot(
        key: key,
        projectId: widget.projectId,
        shotId: _target.id,
        shotLabel: _target.label,
        leg: _target.leg,
        onNavigate: _open,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Plegado de entrada: el sitio es para la paleta y el lienzo.
    final open = _navigatorOpen ?? false;

    return Material(
      color: palette.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            right: false,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: open ? AppLayout.sidebarWidth : 44,
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(right: BorderSide(color: palette.border)),
              ),
              clipBehavior: Clip.hardEdge,
              child: open
                  ? OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: AppLayout.sidebarWidth,
                      maxWidth: AppLayout.sidebarWidth,
                      child: PlanDataBuilder(
                        projectId: widget.projectId,
                        builder: (context, data) => _PlanNavigator(
                          data: data,
                          target: _target,
                          onOpen: _open,
                          onCollapse: () =>
                              setState(() => _navigatorOpen = false),
                        ),
                      ),
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: IconButton(
                        tooltip: 'Mostrar plantas',
                        icon: Icon(
                          Icons.chevron_right,
                          color: palette.textSecondary,
                        ),
                        onPressed: () => setState(() => _navigatorOpen = true),
                      ),
                    ),
            ),
          ),
          Expanded(child: _editor()),
        ],
      ),
    );
  }
}

/// Navegador de la pantalla de trabajo: las plantas de una localización.
class _PlanNavigator extends StatefulWidget {
  final PlanProjectData data;
  final PlanTarget target;
  final void Function(PlanTarget target) onOpen;
  final VoidCallback onCollapse;

  const _PlanNavigator({
    required this.data,
    required this.target,
    required this.onOpen,
    required this.onCollapse,
  });

  @override
  State<_PlanNavigator> createState() => _PlanNavigatorState();
}

/// Valor del selector para «plantas libres y sets sin localización».
const int _freeSite = -1;

class _PlanNavigatorState extends State<_PlanNavigator> {
  /// Localización que se enseña. `null` = la de la planta abierta.
  int? _pickedSite;

  PlanProjectData get _data => widget.data;

  /// Localización a la que pertenece la planta abierta.
  int _siteOfTarget() {
    final t = widget.target;
    int? siteId;
    switch (t.scope) {
      case FloorPlanScope.site:
        siteId = t.id;
      case FloorPlanScope.set:
        siteId = _data.set(t.id)?.siteId;
      case FloorPlanScope.lightSetup:
        for (final s in _data.setups) {
          if (s.id == t.id) siteId = _data.siteIdOfSetup(s);
        }
      case FloorPlanScope.shot:
        for (final s in _data.shots) {
          if (s.id != t.id) continue;
          final scene = _data.scene(s.sceneId);
          siteId =
              scene?.locationSiteId ?? _data.set(scene?.locationId)?.siteId;
        }
    }
    return _data.site(siteId)?.id ?? _freeSite;
  }

  @override
  void didUpdateWidget(_PlanNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al abrir otra planta, el navegador la sigue.
    if (oldWidget.target != widget.target) _pickedSite = null;
  }

  /// Esquemas de la localización visible, en el orden en que se listan.
  List<LightSetup> _setupsInOrder(int siteId) {
    if (siteId == _freeSite) {
      return [
        ..._data.freeSetups,
        for (final set in _data.orphanSets) ..._data.setupsOfSet(set.id),
      ];
    }
    return [
      ..._data.setupsOfSite(siteId),
      for (final set in _data.setsOfSite(siteId)) ..._data.setupsOfSet(set.id),
    ];
  }

  void _stepSetup(int siteId, int delta) {
    final setups = _setupsInOrder(siteId);
    if (setups.isEmpty) return;
    final current = widget.target.scope == FloorPlanScope.lightSetup
        ? setups.indexWhere((s) => s.id == widget.target.id)
        : -1;
    final next = current < 0
        ? (delta > 0 ? 0 : setups.length - 1)
        : (current + delta) % setups.length;
    final setup = setups[next < 0 ? next + setups.length : next];
    widget.onOpen(PlanTarget.lightSetup(setup.id, setup.name));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final siteId = _pickedSite ?? _siteOfTarget();
    final hasFree = _data.freeSetups.isNotEmpty || _data.orphanSets.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            4,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  value: siteId,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  style: AppTypography.titleMedium(palette),
                  items: [
                    for (final site in _data.sites)
                      DropdownMenuItem(
                        value: site.id,
                        child: Text(site.name, overflow: TextOverflow.ellipsis),
                      ),
                    if (hasFree || siteId == _freeSite)
                      const DropdownMenuItem(
                        value: _freeSite,
                        child: Text('Plantas libres'),
                      ),
                  ],
                  onChanged: (id) => setState(() => _pickedSite = id),
                ),
              ),
              IconButton(
                tooltip: 'Ocultar plantas',
                icon: Icon(Icons.chevron_left, color: palette.textSecondary),
                onPressed: widget.onCollapse,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Esquemas de luz',
                  style: AppTypography.caption(palette),
                ),
              ),
              IconButton(
                tooltip: 'Esquema anterior',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.chevron_left, color: palette.textSecondary),
                onPressed: () => _stepSetup(siteId, -1),
              ),
              IconButton(
                tooltip: 'Esquema siguiente',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.chevron_right, color: palette.textSecondary),
                onPressed: () => _stepSetup(siteId, 1),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: palette.divider),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: siteId == _freeSite ? _freeItems() : _siteItems(siteId),
          ),
        ),
      ],
    );
  }

  List<Widget> _siteItems(int siteId) {
    final site = _data.site(siteId);
    if (site == null) return const [];
    final color = _data.colors.siteColor(site.id);
    final withoutSet = _data.scenesOfSiteWithoutSet(site.id);

    return [
      _planRow(
        target: PlanTarget.site(site.id, site.name),
        title: 'Plano maestro',
        subtitle: site.name,
        color: color,
        thumbnail: PlanThumbnail(
          elements: _data.environmentOf(site.id),
          zones: _data.zonesOfSite(site.id),
          emptyIcon: Icons.map_outlined,
        ),
      ),
      for (final setup in _data.setupsOfSite(site.id)) _setupRow(setup),
      for (final set in _data.setsOfSite(site.id)) ..._setItems(set),
      if (withoutSet.isNotEmpty) ...[
        _header('Sin set', color),
        for (final scene in withoutSet) ..._sceneItems(scene),
      ],
    ];
  }

  List<Widget> _freeItems() => [
    for (final setup in _data.freeSetups) _setupRow(setup),
    for (final set in _data.orphanSets) ..._setItems(set),
  ];

  List<Widget> _setItems(LocationBasePlan set) {
    final color = _data.colors.setColor(set);
    return [
      _header(set.locationName, color),
      _planRow(
        target: PlanTarget.set(set.id, set.locationName),
        title: 'Plano del set',
        subtitle: set.locationName,
        color: color,
        thumbnail: PlanThumbnail(
          elements: _data.ownOfSet(set),
          inherited: _data.environmentOf(set.siteId),
          focus: _data.zoneOf(set),
          emptyIcon: Icons.layers_outlined,
        ),
      ),
      for (final setup in _data.setupsOfSet(set.id)) _setupRow(setup),
      for (final scene in _data.scenesOfSet(set.id)) ..._sceneItems(scene),
    ];
  }

  /// Una escena y sus planos, cada uno con el color de su esquema de luz.
  List<Widget> _sceneItems(Scene scene) => [
    _subHeader(
      scene.name.isNotEmpty
          ? 'Esc ${scene.number} · ${scene.name}'
          : 'Esc ${scene.number}',
    ),
    for (final shot in _data.shotsOfScene(scene.id)) _shotRow(shot, indent: 1),
  ];

  Widget _setupRow(LightSetup setup) {
    final shots = _data.shotsOfSetup(setup.id).length;
    return _planRow(
      target: PlanTarget.lightSetup(setup.id, setup.name),
      title: setup.name,
      subtitle:
          '${lightSetupStatusLabel(setup.status)} · '
          '$shots plano${shots == 1 ? '' : 's'}',
      color: _data.setupColor(setup),
      swatch: true,
      thumbnail: PlanThumbnail(
        elements: _data.ownOfSetup(setup),
        inherited: _data.inheritedOfSetup(setup),
        inheritedOpacity: 0.22,
        focus: _data.zoneOf(_data.set(setup.locationBasePlanId)),
        emptyIcon: Icons.wb_incandescent_outlined,
      ),
    );
  }

  Widget _header(String text, Color color) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        4,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.label(palette).copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subHeader(String text) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, 0, 2),
      child: Text(text, style: AppTypography.caption(palette)),
    );
  }

  Widget _planRow({
    required PlanTarget target,
    required String title,
    required String subtitle,
    required Color color,
    required Widget thumbnail,
    bool swatch = false,
  }) {
    final palette = context.palette;
    final selected = target == widget.target;
    return Material(
      color: selected ? color.withValues(alpha: 0.16) : Colors.transparent,
      child: InkWell(
        onTap: () => widget.onOpen(target),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(width: 56, height: 40, child: thumbnail),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (swatch) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
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
                      subtitle,
                      style: AppTypography.caption(palette),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shotRow(Shot shot, {required int indent}) {
    final palette = context.palette;
    final target = PlanTarget.shot(shot.id, _data.shotLabel(shot));
    final selected = target == widget.target;
    final setup = _data.setup(shot.lightSetupId);
    final details = [
      if (shot.framing?.isNotEmpty == true) shot.framing!,
      if (shot.lens?.isNotEmpty == true) shot.lens!,
    ].join(' · ');
    return Material(
      color: selected
          ? palette.accent.withValues(alpha: 0.16)
          : Colors.transparent,
      child: InkWell(
        onTap: () => widget.onOpen(target),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md + indent * 16.0,
            5,
            AppSpacing.md,
            5,
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: setup != null
                      ? _data.setupColor(setup)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  border: setup == null
                      ? Border.all(color: palette.textTertiary)
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  details.isEmpty
                      ? 'Plano ${shot.number}'
                      : 'Plano ${shot.number} · $details',
                  style: AppTypography.bodyMedium(palette),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                setup?.name ?? 'sin luz',
                style: AppTypography.caption(palette),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
