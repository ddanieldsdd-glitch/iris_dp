part of 'camera_plan_editor.dart';

/// Guardar cada capa en su sitio: la del set, la del grupo, la del entorno
/// y los ajustes propios del plano (RD.4).
extension _EditorSave on _CameraPlanEditorState {
  Future<void> _saveNewUids() async {
    final layers = _uidsToSave;
    _uidsToSave = const {};
    _savingUids = true;
    try {
      for (final layer in layers) {
        await _saveLayer(layer);
      }
    } finally {
      _savingUids = false;
    }
  }

  /// Guarda una capa entera en su sitio.
  Future<void> _saveLayer(PlanLayer layer) async {
    if (!_hasLayer(layer)) return;
    // Los identificadores que se dan al abrir no son editar.
    if (!_savingUids) _touchLive();
    if (_envScoped &&
        (layer == PlanLayer.environment || layer == PlanLayer.set)) {
      await _saveEnvironmentOfSet();
      return;
    }
    final list = _layerElements(layer);
    LightOverrides.ensureUids(list);
    switch (layer) {
      case PlanLayer.environment:
        await _repo.saveElements(
          scope: FloorPlanScope.site,
          elements: _sharedVersions(list),
          siteId: _linkedSite!.id,
        );
        await _saveShotOverrides();
      case PlanLayer.set:
        await _repo.saveElements(
          scope: FloorPlanScope.set,
          elements: _sharedVersions(list),
          setId: _linkedSet!.id,
        );
        await _saveShotOverrides();
      case PlanLayer.groupLight:
        await _saveGroupLight(list);
      case PlanLayer.light:
        // Con el identificador estable, un plano ajusta un elemento del
        // esquema sin tocar el de los demás.
        await _repo.saveElements(
          scope: FloorPlanScope.lightSetup,
          elements: _sharedVersions(list),
          lightSetupId: _lightSetup!.id,
        );
        await _saveShotOverrides();
      case PlanLayer.shot:
        await _repo.saveElements(
          scope: FloorPlanScope.shot,
          elements: list,
          shotId: _shot!.id,
        );
    }
  }

  /// Cada elemento como es en su esquema (o en el grupo): lo ajustado solo
  /// en este plano conserva el suyo.
  List<PlanElement> _sharedVersions(List<PlanElement> list) => [
    for (final el in list)
      if (el.shotOverride &&
          _shot != null &&
          _setupOriginals[LightOverrides.uidOf(el)] != null)
        _setupOriginals[LightOverrides.uidOf(el)]!
      else
        el,
  ];

  /// Los ajustes propios del plano: de la luz del set, de la del grupo y de
  /// la del entorno.
  Future<void> _saveShotOverrides() async {
    final shot = _shot;
    if (shot == null) return;
    final own = <String, PlanElement>{
      for (final el in _elements)
        if (_CameraPlanEditorState._canShotOverride(el) &&
            el.shotOverride &&
            _setupOriginals[LightOverrides.uidOf(el)] != null)
          LightOverrides.uidOf(el)!: el,
    };
    await _repo.saveLightOverrides(shot.id, own);
    final db = ref.read(databaseProvider);
    final saved = await (db.select(
      db.shots,
    )..where((s) => s.id.equals(shot.id))).getSingleOrNull();
    // Si mientras tanto se pasó a otro plano, se queda el nuevo.
    if (_shot?.id == shot.id) _shot = saved;
  }

  /// Lo que ha cambiado en [list] respecto a [baseline]: lo cambiado o
  /// nuevo, por identificador, y lo quitado.
  static ({Map<String, PlanElement> changed, List<String> removed}) _diff(
    Map<String, String> baseline,
    List<PlanElement> list,
  ) {
    final now = _CameraPlanEditorState._baselineOf(list);
    return (
      changed: {
        for (final el in list)
          if (LightOverrides.uidOf(el) case final uid?
              when baseline[uid] != now[uid])
            uid: el,
      },
      removed: [
        for (final uid in baseline.keys)
          if (!now.containsKey(uid)) uid,
      ],
    );
  }

  /// Guarda la luz del grupo (SG.3): para todo el grupo o, si se elige,
  /// solo para este set (una copia propia, o sin esa luz).
  Future<void> _saveGroupLight(List<PlanElement> list) async {
    final group = _group;
    final setup = _lightSetup;
    if (group == null || setup == null) return;
    final shared = _sharedVersions(list);
    final diff = _diff(_groupBaseline, shared);
    if (diff.changed.isEmpty && diff.removed.isEmpty) {
      await _saveShotOverrides();
      return;
    }
    var scope = _savingUids ? GroupLightScope.group : _groupLightScope;
    if (scope == null) {
      final answer = await askGroupLightScope(
        context,
        group: group,
        setup: setup,
        setCount: _siteSets.where((s) => s.groupId == group.id).length,
      );
      if (answer == null) {
        await _load();
        return;
      }
      scope = answer.scope;
      if (answer.remember) _groupLightScope = scope;
    }
    final db = ref.read(databaseProvider);
    if (scope == GroupLightScope.group) {
      // Sobre lo guardado: el grupo tiene luces que este set no ve.
      final stored = [
        ...FloorPlanJson.decode((await db.getSetGroupById(group.id))?.planJson),
      ];
      stored.removeWhere((e) => diff.removed.contains(LightOverrides.uidOf(e)));
      for (final entry in diff.changed.entries) {
        final at = stored.indexWhere(
          (e) => LightOverrides.uidOf(e) == entry.key,
        );
        if (at >= 0) {
          stored[at] = entry.value;
        } else {
          stored.add(entry.value);
        }
      }
      await _repo.saveGroupElements(group.id, stored);
      _group = await db.getSetGroupById(group.id);
    } else {
      // Este set se queda con su versión: pasa a su luz, con el mismo uid.
      _update(() {
        for (final el in diff.changed.values) {
          el
            ..layer = PlanLayer.light
            ..shotOverride = false;
          _setupOriginals.remove(LightOverrides.uidOf(el));
        }
      });
      if (diff.removed.isNotEmpty) {
        _hiddenGroupLights = {..._hiddenGroupLights, ...diff.removed}.toList();
        await _repo.saveHiddenGroupLights(setup.id, _hiddenGroupLights);
      }
      if (diff.changed.isNotEmpty) await _saveLayer(PlanLayer.light);
    }
    _groupBaseline = _CameraPlanEditorState._baselineOf(
      _sharedVersions(_layerElements(PlanLayer.groupLight)),
    );
    await _saveShotOverrides();
  }

  /// Guarda un cambio de entorno hecho desde un set (SG.3): pregunta a
  /// quién afecta (este set, otros, el grupo o la localización) y lo
  /// guarda donde toca.
  Future<void> _saveEnvironmentOfSet() async {
    final setup = _lightSetup!;
    final site = _linkedSite!;
    // Lo ajustado solo en este plano no cambia el entorno del set.
    final list = _sharedVersions([
      ..._layerElements(PlanLayer.environment),
      ..._layerElements(PlanLayer.set),
    ]);
    LightOverrides.ensureUids(list);
    await _saveShotOverrides();
    final diff = _diff(_envBaseline, list);
    if (diff.changed.isEmpty && diff.removed.isEmpty) return;
    final others = [
      for (final s in _siteSets)
        if (s.id != setup.id) s,
    ];
    var answer = _envScope;
    if (answer == null && others.isEmpty) {
      // Un solo set: el entorno es el suyo.
      answer = (scope: EnvScope.site, sets: const <int>[], remember: true);
    }
    if (answer == null) {
      final group = _group;
      final asked = await askEnvScope(
        context,
        setup: setup,
        siteName: site.name,
        otherSets: others,
        group: group,
        groupSets: [
          for (final s in _siteSets)
            if (group != null && s.groupId == group.id) s,
        ],
      );
      if (asked == null) {
        await _load();
        return;
      }
      answer = asked;
      if (asked.remember) _envScope = asked;
    }
    final db = ref.read(databaseProvider);
    final siteBase = [
      ...FloorPlanJson.decode((await db.getSiteById(site.id))?.floorPlanJson),
    ];
    final zone = _linkedSet;
    final zoneBase = zone == null
        ? <PlanElement>[]
        : [
            ...FloorPlanJson.decode(
              (await db.getLocationById(zone.id))?.floorPlanJson,
            ),
          ];
    final baseUids = {
      for (final el in [...siteBase, ...zoneBase]) LightOverrides.uidOf(el),
    };
    if (answer.scope == EnvScope.site) {
      // El entorno definitivo cambia; este set deja de cambiarlo.
      siteBase.removeWhere(
        (e) => diff.removed.contains(LightOverrides.uidOf(e)),
      );
      zoneBase.removeWhere(
        (e) => diff.removed.contains(LightOverrides.uidOf(e)),
      );
      for (final entry in diff.changed.entries) {
        final copy = LightOverrides.clone(entry.value);
        int at(List<PlanElement> l) =>
            l.indexWhere((e) => LightOverrides.uidOf(e) == entry.key);
        if (at(siteBase) >= 0) {
          siteBase[at(siteBase)] = copy;
        } else if (at(zoneBase) >= 0) {
          zoneBase[at(zoneBase)] = copy;
        } else if (zone != null && entry.value.layer == PlanLayer.set) {
          zoneBase.add(copy);
        } else {
          siteBase.add(copy);
        }
      }
      await _repo.saveElements(
        scope: FloorPlanScope.site,
        elements: siteBase,
        siteId: site.id,
      );
      if (zone != null) {
        await _repo.saveElements(
          scope: FloorPlanScope.set,
          elements: zoneBase,
          setId: zone.id,
        );
      }
      final own = EnvOverrides.decode(
        (await db.getLightSetupById(setup.id))?.envOverridesJson,
      );
      final touched = [...diff.changed.keys, ...diff.removed];
      if (touched.any(own.containsKey)) {
        own.removeWhere((uid, _) => touched.contains(uid));
        await db.setLightSetupEnvOverrides(setup.id, EnvOverrides.encode(own));
      }
    } else {
      for (final id in {setup.id, ...answer.sets}) {
        final target = await db.getLightSetupById(id);
        if (target == null) continue;
        final own = EnvOverrides.decode(target.envOverridesJson);
        for (final entry in diff.changed.entries) {
          own[entry.key] = LightOverrides.clone(entry.value);
        }
        for (final uid in diff.removed) {
          if (baseUids.contains(uid)) {
            own[uid] = null;
          } else {
            own.remove(uid);
          }
        }
        await db.setLightSetupEnvOverrides(id, EnvOverrides.encode(own));
      }
    }
    _envBaseline = _CameraPlanEditorState._baselineOf(list);
    _lightSetup = await db.getLightSetupById(setup.id);
  }

  /// Hace que una luz del esquema se ajuste solo en este plano, o la
  /// devuelve a como está en el esquema.
  Future<void> _setShotOverride(PlanElement el, bool own) async {
    if (_shot == null || !_CameraPlanEditorState._canShotOverride(el)) return;
    LightOverrides.ensureUids([el]);
    final uid = LightOverrides.uidOf(el)!;
    if (own) {
      _setupOriginals[uid] = LightOverrides.clone(el);
      _update(() => el.shotOverride = true);
    } else {
      final original = _setupOriginals.remove(uid);
      if (original != null) {
        final index = _elements.indexOf(el);
        original
          ..layer = el.layer
          ..id = --_tempId
          ..shotOverride = false;
        _update(() {
          if (index >= 0) _elements[index] = original;
          _selected = original;
          _multi.clear();
        });
      } else {
        _update(() => el.shotOverride = false);
      }
    }
    await _saveLayer(el.layer);
    _commitHistory();
  }
}
