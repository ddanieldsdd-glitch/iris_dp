part of 'camera_plan_editor.dart';

/// Qué focos del set usa este plano (PL.1): uno que no usa se queda en el
/// set, en fantasma, y desaparece de la luz, el 3D y el PDF del plano.
extension _LightUse on _CameraPlanEditorState {
  /// Se puede usar o dejar de usar solo en un plano.
  bool _canToggleUse(PlanElement el) =>
      _shot != null &&
      el.type == ElementType.light &&
      _CameraPlanEditorState._canShotOverride(el);

  /// Las posiciones del plano: las de quien más tiene.
  int get _positionCount {
    if (_shot == null) return 1;
    var most = 1;
    for (final el in _elements) {
      if (_canMark(el) && el.pathPoints.length + 1 > most) {
        most = el.pathPoints.length + 1;
      }
    }
    return most;
  }

  /// La posición que se ve, dentro de las que hay.
  int get _shownPosition => _viewPosition.clamp(0, _positionCount - 1).toInt();

  /// Puede tener posiciones: cámaras y actores siempre; un foco, solo en
  /// un plano (PL.3).
  bool _canMark(PlanElement el) =>
      PlanMarks.supports(el) ||
      (el.type == ElementType.light && _canToggleUse(el));

  /// Un foco con posiciones es un ajuste del plano: no mueve el del set.
  void _ownLightForMarks(PlanElement el) {
    if (el.type != ElementType.light || el.shotOverride) return;
    LightOverrides.ensureUids([el]);
    _setupOriginals[LightOverrides.uidOf(el)!] = LightOverrides.clone(el);
    el.shotOverride = true;
  }

  /// Usa o deja de usar [el] en este plano. Sin [save], lo guarda quien
  /// llama (varios a la vez).
  Future<void> _setLightUsed(
    PlanElement el,
    bool used, {
    bool save = true,
  }) async {
    if (!_canToggleUse(el) || used != LightOverrides.isUnused(el)) return;
    LightOverrides.ensureUids([el]);
    final uid = LightOverrides.uidOf(el)!;
    if (!used) {
      if (!el.shotOverride) {
        _setupOriginals[uid] = LightOverrides.clone(el);
        el.shotOverride = true;
      }
      _rebuild(() => LightOverrides.setUnused(el, true));
    } else {
      final original = _setupOriginals[uid];
      _rebuild(
        () => LightOverrides.setUnused(
          el,
          false,
          setOff: original?.props[LightBeam.offKey] == true,
        ),
      );
      // Si el plano no le cambiaba nada más, vuelve a ser el del set.
      if (original != null && LightOverrides.sameAs(el, original)) {
        _setupOriginals.remove(uid);
        final index = _elements.indexOf(el);
        original
          ..layer = el.layer
          ..id = --_tempId
          ..shotOverride = false;
        _rebuild(() {
          if (index >= 0) _elements[index] = original;
          if (identical(_selected, el)) _selected = original;
        });
      }
    }
    if (save) {
      await _saveLayer(el.layer);
      _commitHistory();
    }
  }

  /// Usa o deja de usar varios focos, guardando una vez.
  Future<void> _setLightsUsed(Map<PlanElement, bool> changes) async {
    final layers = <PlanLayer>{};
    for (final MapEntry(key: el, value: used) in changes.entries) {
      if (used == LightOverrides.isUnused(el)) layers.add(el.layer);
      await _setLightUsed(el, used, save: false);
    }
    if (layers.isEmpty) return;
    for (final layer in layers) {
      await _saveLayer(layer);
    }
    _commitHistory();
  }

  /// La tecla U: usa o deja de usar los focos elegidos.
  Future<void> _toggleSelectedUse() async {
    final lights = [
      for (final el in _selection)
        if (_canToggleUse(el)) el,
    ];
    if (lights.isEmpty) return;
    // Si alguno no se usa, se usan todos; si no, se dejan todos.
    final use = lights.any(LightOverrides.isUnused);
    await _setLightsUsed({for (final el in lights) el: use});
  }

  /// Los focos del set que este plano puede usar o no.
  List<PlanElement> get _shotLights => [
    for (final el in _elements)
      if (_canToggleUse(el)) el,
  ];

  /// «Focos 5/7» en la barra de capas; nulo fuera de un plano.
  String? get _lightUseLabel {
    if (_shot == null) return null;
    final lights = _shotLights;
    if (lights.isEmpty) return null;
    final used = lights.where((e) => !LightOverrides.isUnused(e)).length;
    return 'Focos $used/${lights.length}';
  }

  /// El panel rápido: casillas por foco, «igual que el plano anterior»,
  /// todos o ninguno (PL.2).
  Future<void> _openLightUse() async {
    final shot = _shot;
    if (shot == null) return;
    final db = ref.read(databaseProvider);
    // El plano anterior del mismo set: en la escena o, si no, en el set.
    final siblings =
        await (db.select(db.shots)
              ..where((s) => s.lightSetupId.equalsNullable(shot.lightSetupId))
              ..orderBy([
                (s) => OrderingTerm.asc(s.sceneId),
                (s) => OrderingTerm.asc(s.sortOrder),
                (s) => OrderingTerm.asc(s.number),
              ]))
            .get();
    final at = siblings.indexWhere((s) => s.id == shot.id);
    final previous = at > 0 ? siblings[at - 1] : null;
    if (!mounted) return;
    String where(PlanElement el) => switch (el.layer) {
      PlanLayer.light => '',
      PlanLayer.groupLight => 'Del grupo',
      PlanLayer.environment || PlanLayer.set => 'Del entorno',
      PlanLayer.shot => '',
    };
    final lights = _shotLights;
    LightOverrides.ensureUids(lights);
    await PlanLightUsePanel.show(
      context,
      title: 'Focos de este plano',
      lights: [
        for (final el in lights)
          (
            uid: LightOverrides.uidOf(el)!,
            name: el.fullLabel,
            where: where(el),
          ),
      ],
      unused: {
        for (final el in lights)
          if (LightOverrides.isUnused(el)) LightOverrides.uidOf(el)!,
      },
      previous: previous == null
          ? null
          : LightOverrides.unusedIn(previous.lightOverridesJson),
      previousLabel: previous == null
          ? null
          : previous.sceneId == shot.sceneId
          ? 'el plano ${previous.number}'
          : 'el plano anterior del set',
      onApply: (unused) => _setLightsUsed({
        for (final el in _shotLights)
          el: !unused.contains(LightOverrides.uidOf(el)),
      }),
    );
  }
}

/// Dónde aparece un foco nuevo del set (PL.1).
enum _LightScope { shot, scene, all }

/// La última respuesta, para no preguntar otra vez al añadir varios focos
/// seguidos.
final _lastLightScope = Expando<(_LightScope, DateTime)>();

extension _NewLightScope on _CameraPlanEditorState {
  /// Al añadir un foco al set desde un plano: ¿en qué planos aparece? En
  /// los demás queda como no usado.
  Future<void> _askWhereLightAppears(PlanElement el) async {
    final shot = _shot;
    final setup = _lightSetup;
    if (shot == null ||
        setup == null ||
        el.type != ElementType.light ||
        el.layer != PlanLayer.light) {
      return;
    }
    final db = ref.read(databaseProvider);
    final others = [
      for (final s in await (db.select(
        db.shots,
      )..where((s) => s.lightSetupId.equals(setup.id))).get())
        if (s.id != shot.id) s,
    ];
    if (others.isEmpty || !mounted) return;
    final inScene = others.where((s) => s.sceneId == shot.sceneId).length;

    var scope = switch (_lastLightScope[this]) {
      (final s, final at)
          when DateTime.now().difference(at) < const Duration(seconds: 3) =>
        s,
      _ => null,
    };
    scope ??= await showModalBottomSheet<_LightScope>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                '¿Dónde aparece este foco?',
                style: AppTypography.titleMedium(context.palette),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.crop_square),
              title: const Text('Solo en este plano'),
              subtitle: Text(
                'En los otros ${others.length} planos del set queda en '
                'fantasma, sin usar.',
              ),
              onTap: () => Navigator.pop(context, _LightScope.shot),
            ),
            if (inScene > 0)
              ListTile(
                leading: const Icon(Icons.view_carousel_outlined),
                title: const Text('En esta escena'),
                subtitle: Text('Este plano y $inScene más de la escena.'),
                onTap: () => Navigator.pop(context, _LightScope.scene),
              ),
            ListTile(
              leading: const Icon(Icons.select_all),
              title: const Text('En todos los planos del set'),
              subtitle: Text('${others.length + 1} planos.'),
              onTap: () => Navigator.pop(context, _LightScope.all),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    // Sin respuesta, lo normal: solo en este plano.
    scope ??= _LightScope.shot;
    _lastLightScope[this] = (scope, DateTime.now());
    if (scope == _LightScope.all) return;

    LightOverrides.ensureUids([el]);
    final uid = LightOverrides.uidOf(el)!;
    for (final other in others) {
      if (scope == _LightScope.scene && other.sceneId == shot.sceneId) {
        continue;
      }
      final own = LightOverrides.decode(other.lightOverridesJson);
      own[uid] = LightOverrides.clone(el)..shotOverride = false;
      LightOverrides.setUnused(own[uid]!, true);
      await _repo.saveLightOverrides(other.id, own);
    }
  }
}

/// «Posición 1 2 3»: qué marca del plano se ve.
class _PositionPicker extends StatelessWidget {
  final AppPalette palette;
  final int count;
  final int value;
  final ValueChanged<int> onChanged;

  const _PositionPicker({
    required this.palette,
    required this.count,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Posición', style: AppTypography.caption(palette)),
        const SizedBox(width: 4),
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: ChoiceChip(
              key: ValueKey('plan-position-$i'),
              visualDensity: VisualDensity.compact,
              showCheckmark: false,
              label: Text('${i + 1}'),
              selected: i == value,
              tooltip: i == 0
                  ? 'La luz como empieza el plano'
                  : 'La luz con todo en la posición ${i + 1}',
              onSelected: (_) => onChanged(i),
            ),
          ),
      ],
    );
  }
}
