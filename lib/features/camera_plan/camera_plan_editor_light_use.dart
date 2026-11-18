part of 'camera_plan_editor.dart';

/// Qué focos del set usa este plano (PL.1): uno que no usa se queda en el
/// set, en fantasma, y desaparece de la luz, el 3D y el PDF del plano.
extension _LightUse on _CameraPlanEditorState {
  /// Se puede usar o dejar de usar solo en un plano.
  bool _canToggleUse(PlanElement el) =>
      _shot != null &&
      el.type == ElementType.light &&
      _CameraPlanEditorState._canShotOverride(el);

  /// Usa o deja de usar [el] en este plano.
  Future<void> _setLightUsed(PlanElement el, bool used) async {
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
        await _setShotOverride(el, false);
        return;
      }
    }
    await _saveLayer(el.layer);
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
    for (final el in lights) {
      await _setLightUsed(el, use);
    }
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
