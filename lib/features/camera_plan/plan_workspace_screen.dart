import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_editor.dart';
import 'floor_plan_scope.dart';
import 'plan_data.dart';
import 'plan_scene_board.dart' show PlanShotCameraBadges;
import 'plan_set_summary.dart';
import 'plan_strip_link.dart';
import 'shot_cover.dart';
import 'plan_target.dart';
import 'plan_thumbnail.dart';
import 'project_focus.dart';
import 'project_jump.dart';
import '../technical_script/technical_script_screen.dart';
import '../../shared/rich_text/script_markup.dart';

/// Pantalla única de trabajo: el editor de la planta abierta y, al lado, un
/// navegador para cambiar de set, esquema de luz, plano o localización sin
/// volver al mapa global.
class PlanWorkspaceScreen extends ConsumerStatefulWidget {
  final int projectId;
  final PlanTarget initial;

  /// Debajo está el guion técnico: «Ver en el guion» vuelve a él.
  final bool fromScript;

  const PlanWorkspaceScreen({
    super.key,
    required this.projectId,
    required this.initial,
    this.fromScript = false,
  });

  /// Abre [target] directamente en IRIS Stage, el 3D a pantalla entera
  /// (ED.4); al cerrarlo queda su planta.
  static Future<void> openStage(
    BuildContext context, {
    required int projectId,
    required PlanTarget target,
  }) {
    CameraPlanEditor.openStageOnNextLoad();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PlanWorkspaceScreen(projectId: projectId, initial: target),
      ),
    );
  }

  @override
  ConsumerState<PlanWorkspaceScreen> createState() =>
      _PlanWorkspaceScreenState();
}

class _PlanWorkspaceScreenState extends ConsumerState<PlanWorkspaceScreen> {
  late PlanTarget _target = widget.initial;
  bool? _navigatorOpen;

  /// Une la tira de planos con el editor del set (SV.3).
  final _stripLink = PlanStripLink();

  @override
  void initState() {
    super.initState();
    _recordFocus(_target);
  }

  @override
  void dispose() {
    _stripLink.dispose();
    super.dispose();
  }

  void _open(PlanTarget target) {
    if (target == _target) return;
    setState(() => _target = target);
    _recordFocus(target);
  }

  /// El guion técnico y las plantas se abren luego donde se dejó.
  Future<void> _recordFocus(PlanTarget target) async {
    final focus = ref.read(projectFocusProvider(widget.projectId).notifier);
    final db = ref.read(databaseProvider);
    if (target.scope == FloorPlanScope.shot) {
      final shot = await db.getShotById(target.id);
      if (shot != null) focus.focusShot(shot);
    } else if (target.scope == FloorPlanScope.lightSetup) {
      await Future<void>.microtask(() {});
      focus.focusSetup(target.id);
    }
  }

  /// La fila del plano abierto en el guion técnico. Si se vino de él, se
  /// vuelve; si no, lo sustituye para no apilar pantallas.
  void _showInScript() {
    final navigator = Navigator.of(context);
    if (widget.fromScript) {
      navigator.maybePop();
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TechnicalScriptScreen(
          projectId: widget.projectId,
          initialShotId: _target.id,
        ),
      ),
    );
  }

  /// El editor con la tira de planos encima (SG.5): en un plano, los de su
  /// escena; en un set, los suyos. Se pasa de uno a otro sin salir.
  Widget _editorWithStrip() {
    if (_target.scope != FloorPlanScope.shot &&
        _target.scope != FloorPlanScope.lightSetup) {
      return _editor();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlanDataBuilder(
          projectId: widget.projectId,
          builder: (context, data) => PlanShotStrip(
            data: data,
            target: _target,
            onOpen: _open,
            link: _stripLink,
            onShowInScript: _showInScript,
          ),
        ),
        Expanded(child: _editor()),
      ],
    );
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
        stripLink: _stripLink,
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

  /// iPhone (IP.4.1): sin columna lateral, el navegador sale en una hoja.
  void _showNavigatorSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      builder: (sheet) => FractionallySizedBox(
        heightFactor: 0.85,
        child: PlanDataBuilder(
          projectId: widget.projectId,
          builder: (context, data) => _PlanNavigator(
            data: data,
            target: _target,
            onOpen: (target) {
              Navigator.of(sheet).pop();
              _open(target);
            },
            onCollapse: () => Navigator.of(sheet).pop(),
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        Positioned.fill(child: _editorWithStrip()),
        // Encima de la barra de abajo del editor (Añadir · Guardar), a la
        // izquierda, donde no tapa sus botones.
        Positioned(
          left: 12,
          bottom: bottom + 56 + 12,
          child: FloatingActionButton.small(
            heroTag: null,
            tooltip: 'Plantas',
            onPressed: _showNavigatorSheet,
            child: const Icon(Icons.layers_outlined),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ProjectJumpShortcut(
    projectId: widget.projectId,
    onPick: _open,
    child: _buildScreen(context),
  );

  Widget _buildScreen(BuildContext context) {
    final palette = context.palette;
    if (AppLayout.isCompact(context)) {
      return Material(color: palette.background, child: _buildCompact(context));
    }
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
          Expanded(child: _editorWithStrip()),
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
    return [for (final part in _data.orderedSets(siteId)) ...part.sets];
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

  /// Localización › Grupo › Set › Planos (SG.2), en el orden de rodaje.
  List<Widget> _siteItems(int siteId) {
    final site = _data.site(siteId);
    if (site == null) return const [];
    final color = _data.colors.siteColor(site.id);
    final unlit = [
      for (final sc in _data.scenes)
        if (_data.siteIdOfScene(sc) == site.id)
          for (final shot in _data.shotsOfScene(sc.id))
            if (_data.setup(shot.lightSetupId) == null) shot,
    ];

    return [
      _planRow(
        target: PlanTarget.site(site.id, site.name),
        title: 'Plano maestro',
        subtitle: '${site.name} · el entorno de todos sus sets',
        color: color,
        thumbnail: PlanThumbnail(
          elements: _data.environmentOf(site.id),
          zones: _data.zonesOfSite(site.id),
          emptyIcon: Icons.map_outlined,
        ),
      ),
      for (final part in _data.orderedSets(site.id)) ...[
        if (part.group != null)
          _header(part.group!.name, context.palette.accent)
        else if (_data.groupsOfSite(site.id).isNotEmpty &&
            SetOrderMode.of(site.setOrderMode) == SetOrderMode.group)
          _header('Sin grupo', color),
        for (final setup in part.sets) ...[
          _setupRow(setup),
          for (final shot in _data.shotsOfSetup(setup.id))
            _shotRow(shot, indent: 1),
        ],
      ],
      if (unlit.isNotEmpty) ...[
        _header('Planos sin set', color),
        for (final shot in unlit) _shotRow(shot, indent: 1),
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
          ? 'Esc ${scene.label} · ${scene.name}'
          : 'Esc ${scene.label}',
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
        drawings: _data.drawingsOfSetup(setup),
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
      if (shot.framing?.isNotEmpty == true) scriptMarkupToPlain(shot.framing),
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

/// Los planos entre los que se puede saltar desde la planta abierta (SG.5):
/// en un plano, los de su escena; en un set, los que lo usan. Con ◀ ▶ se va
/// al anterior y al siguiente.
/// La tira de arriba del editor (SV.2): el set que se está viendo (su
/// planta, cuándo se rueda, su luz y sus cámaras) y sus planos como
/// tarjetas con imagen, número, tipo y cámara. En un set, tocar un plano
/// con una cámara seleccionada la vincula; arrastrarlo a la planta, también
/// (SV.3).
class PlanShotStrip extends StatelessWidget {
  final PlanProjectData data;
  final PlanTarget target;
  final void Function(PlanTarget target) onOpen;
  final PlanStripLink? link;

  /// Lleva a la fila del plano abierto en el guion técnico.
  final VoidCallback? onShowInScript;

  const PlanShotStrip({
    super.key,
    required this.data,
    required this.target,
    required this.onOpen,
    this.link,
    this.onShowInScript,
  });

  /// Los planos de la tira y el título que llevan delante.
  static (String, List<Shot>) shotsFor(
    PlanProjectData data,
    PlanTarget target,
  ) {
    if (target.scope == FloorPlanScope.lightSetup) {
      return ('Planos del set', data.shotsOfSetup(target.id));
    }
    final shot = data.shots.where((s) => s.id == target.id).firstOrNull;
    final scene = data.scene(shot?.sceneId);
    if (shot == null || scene == null) return ('', const []);
    return ('Esc ${scene.label}', data.shotsOfScenes([scene]));
  }

  /// El set de lo que se ve: el abierto, o el del plano abierto.
  LightSetup? get _setup {
    if (target.scope == FloorPlanScope.lightSetup) {
      return data.setup(target.id);
    }
    final shot = data.shots.where((s) => s.id == target.id).firstOrNull;
    return shot == null ? null : data.setup(shot.lightSetupId);
  }

  @override
  Widget build(BuildContext context) {
    final link = this.link;
    if (link == null) return _build(context, null);
    return ListenableBuilder(
      listenable: link,
      builder: (context, _) => _build(context, link),
    );
  }

  Widget _build(BuildContext context, PlanStripLink? link) {
    final palette = context.palette;
    final (title, shots) = shotsFor(data, target);
    final setup = _setup;
    if (shots.isEmpty && setup == null) return const SizedBox.shrink();
    final inSet = target.scope == FloorPlanScope.lightSetup;
    final current = target.scope == FloorPlanScope.shot
        ? shots.indexWhere((s) => s.id == target.id)
        : -1;
    void go(int i) =>
        onOpen(PlanTarget.shot(shots[i].id, data.shotLabel(shots[i])));
    final camera = inSet ? link?.camera : null;
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          if (setup != null)
            _SetHeader(
              data: data,
              setup: setup,
              open: inSet,
              onOpen: () => onOpen(PlanTarget.lightSetup(setup.id, setup.name)),
            ),
          IconButton(
            tooltip: 'Plano anterior',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left),
            onPressed: current > 0 ? () => go(current - 1) : null,
          ),
          Expanded(
            child: shots.isEmpty
                ? Text(
                    'Este set aún no tiene planos: llévalos desde el tablero '
                    'de la localización.',
                    style: AppTypography.caption(
                      palette,
                    ).copyWith(color: palette.textTertiary),
                  )
                : ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      if (camera != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              'Cámara $camera:\nvincula sus planos',
                              style: AppTypography.caption(
                                palette,
                              ).copyWith(color: palette.success, fontSize: 10),
                            ),
                          ),
                        )
                      else if (!inSet)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              title,
                              style: AppTypography.caption(palette),
                            ),
                          ),
                        ),
                      for (final (i, shot) in shots.indexed)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _StripShotCard(
                            key: ValueKey('strip-shot-${shot.id}'),
                            shot: shot,
                            data: data,
                            sceneTag: inSet,
                            selected: i == current,
                            linked:
                                camera != null &&
                                link!.linked.contains(shot.id),
                            dimmed:
                                camera != null &&
                                !link!.linked.contains(shot.id),
                            draggable: inSet && link != null,
                            onAddCamera:
                                inSet &&
                                    link != null &&
                                    link.canAddCamera &&
                                    data.camerasOfShot(shot).isEmpty
                                ? () => link.addCamera(shot.id)
                                : null,
                            onToggleLink: camera != null
                                ? () => link!.toggle(shot.id)
                                : null,
                            onTap: () => go(i),
                          ),
                        ),
                    ],
                  ),
          ),
          IconButton(
            tooltip: current < 0 ? 'Abrir el primer plano' : 'Plano siguiente',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right),
            onPressed: current < shots.length - 1
                ? () => go(current + 1)
                : null,
          ),
          if (onShowInScript != null && target.scope == FloorPlanScope.shot)
            IconButton(
              key: const ValueKey('strip-show-in-script'),
              tooltip: 'Ver en el guion',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.table_rows_outlined),
              onPressed: onShowInScript,
            ),
        ],
      ),
    );
  }
}

/// El set en la tira: su planta pequeña, nombre y qué set es de un vistazo.
class _SetHeader extends StatelessWidget {
  final PlanProjectData data;
  final LightSetup setup;

  /// Es el set abierto (si no, se toca para abrirlo).
  final bool open;
  final VoidCallback onOpen;

  const _SetHeader({
    required this.data,
    required this.setup,
    required this.open,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = data.setupColor(setup);
    final summary = SetSummary.of(data, setup);
    final group = data.group(setup.groupId);
    final warnings = [
      if (summary.shotsWithoutCamera > 0)
        '${summary.shotsWithoutCamera} sin cámara',
    ];
    return Tooltip(
      message: open ? summary.lightText : 'Abrir el set (todas sus cámaras)',
      child: InkWell(
        key: const ValueKey('strip-set-header'),
        onTap: open ? null : onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 270,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: open ? 0.12 : 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: open ? 0.7 : 0.35),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 84,
                  height: 62,
                  child: PlanThumbnail(
                    elements: [
                      ...data.groupLightOf(setup),
                      ...data.ownOfSetup(setup),
                    ],
                    inherited: data.inheritedOfSetup(setup),
                    drawings: data.drawingsOfSetup(setup),
                    emptyIcon: Icons.wb_incandescent_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            setup.name,
                            style: AppTypography.label(palette),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      [
                        if (summary.when != null) summary.when!,
                        if (group != null) group.name,
                      ].join(' · '),
                      style: AppTypography.caption(
                        palette,
                      ).copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      summary.lightText,
                      style: AppTypography.caption(
                        palette,
                      ).copyWith(fontSize: 10, color: palette.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        summary.cameraText,
                        '${summary.shots} plano${summary.shots == 1 ? '' : 's'}',
                        ...warnings,
                      ].join(' · '),
                      style: AppTypography.caption(palette).copyWith(
                        fontSize: 10,
                        color: warnings.isEmpty
                            ? palette.textTertiary
                            : palette.warning,
                      ),
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
}

/// Un plano en la tira: imagen, número, tipo y cámara.
class _StripShotCard extends StatelessWidget {
  final Shot shot;
  final PlanProjectData data;
  final bool sceneTag;
  final bool selected;
  final bool linked;
  final bool dimmed;
  final bool draggable;
  final VoidCallback onTap;
  final VoidCallback? onAddCamera;

  /// Con una cámara del set seleccionada: la pone o la quita de este plano.
  final VoidCallback? onToggleLink;

  const _StripShotCard({
    super.key,
    required this.shot,
    required this.data,
    required this.sceneTag,
    required this.selected,
    required this.linked,
    required this.dimmed,
    required this.draggable,
    required this.onTap,
    this.onAddCamera,
    this.onToggleLink,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tag = sceneTag
        ? '${data.scene(shot.sceneId)?.label ?? '–'}·P${shot.number}'
        : 'P${shot.number}';
    final type = [
      if (shot.framing?.isNotEmpty == true) scriptMarkupToPlain(shot.framing),
      if (shot.lens?.isNotEmpty == true) shot.lens!,
      if (shot.movement?.isNotEmpty == true) shot.movement!,
    ].join(' · ');
    final border = linked
        ? palette.success
        : selected
        ? palette.accent
        : palette.border;
    final card = Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: Material(
        color: palette.surfaceElevated,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border, width: linked || selected ? 2 : 0.6),
        ),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 200,
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  height: double.infinity,
                  child:
                      shotCoverThumbnail(shot, cacheWidth: 200) ??
                      ColoredBox(
                        color: palette.background,
                        child: Icon(
                          Icons.videocam_outlined,
                          color: palette.textTertiary,
                        ),
                      ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(tag, style: AppTypography.label(palette)),
                      if (type.isNotEmpty)
                        Text(
                          type,
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(fontSize: 10),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Row(
                        children: [
                          Flexible(
                            child: PlanShotCameraBadges(
                              cameras: data.camerasOfShot(shot),
                            ),
                          ),
                          if (onToggleLink != null)
                            InkWell(
                              key: ValueKey('strip-link-${shot.id}'),
                              onTap: onToggleLink,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  linked ? 'Desvincular' : 'Vincular',
                                  style: TextStyle(
                                    color: linked
                                        ? palette.success
                                        : palette.accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          if (onAddCamera != null)
                            InkWell(
                              key: ValueKey('strip-add-camera-${shot.id}'),
                              onTap: onAddCamera,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  '+ cámara',
                                  style: TextStyle(
                                    color: palette.accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
    if (!draggable) return card;
    return Draggable<PlanStripShot>(
      data: PlanStripShot(shot.id),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: palette.accent,
        borderRadius: BorderRadius.circular(8),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            '$tag → planta',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}
