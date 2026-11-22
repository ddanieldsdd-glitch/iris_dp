part of 'camera_plan_editor.dart';

/// Leer la planta abierta (sus capas, su luz y lo que la rodea), anunciar
/// a los demás equipos qué se edita aquí y moverse entre planos (RD.4).
extension _EditorLoad on _CameraPlanEditorState {
  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final db = ref.read(databaseProvider);
    LightSetup? lightSetup;
    final annotationRow = await db.getProjectAnnotationDocument(
      projectId: widget.projectId,
      targetType: _annotationTargetType,
      targetId: _annotationTargetId,
    );

    Shot? shot;
    Scene? scene;
    LocationBasePlan? linkedSet;
    LocationSite? linkedSite;
    Color sceneColor = sceneDisplayColor(null);

    final sites = await (db.select(
      db.locationSites,
    )..where((s) => s.projectId.equals(widget.projectId))).get();
    final allSets = await (db.select(
      db.locationBasePlans,
    )..where((s) => s.projectId.equals(widget.projectId))).get();
    final allScenes = await (db.select(
      db.scenes,
    )..where((s) => s.projectId.equals(widget.projectId))).get();
    final colors = ProjectColorScheme.resolve(
      sites: sites,
      sets: allSets,
      scenes: allScenes,
    );

    if (_isShotMode && widget.shotId != null) {
      shot = await (db.select(
        db.shots,
      )..where((s) => s.id.equals(widget.shotId!))).getSingleOrNull();
      if (shot != null) {
        scene = await (db.select(
          db.scenes,
        )..where((s) => s.id.equals(shot!.sceneId))).getSingleOrNull();
        // El set es el del tramo (plano secuencia), el propio del plano
        // o, si no, el de su escena.
        final ownLeg = _legOf(shot);
        final shotSetId =
            ownLeg?.setId ?? shot.locationBasePlanId ?? scene?.locationId;
        if (shotSetId != null) {
          linkedSet = await db.getLocationById(shotSetId);
        }
        final shotSiteId =
            ownLeg?.siteId ?? linkedSet?.siteId ?? scene?.locationSiteId;
        if (shotSiteId != null) {
          linkedSite = await db.getSiteById(shotSiteId);
        }
        if (scene != null) sceneColor = colors.sceneColor(scene);
      }
    } else if (widget.scope == FloorPlanScope.set && widget.setId != null) {
      linkedSet = await db.getLocationById(widget.setId!);
      if (linkedSet?.siteId != null) {
        linkedSite = await db.getSiteById(linkedSet!.siteId!);
      }
      sceneColor = colors.setColor(linkedSet!);
    } else if (widget.scope == FloorPlanScope.lightSetup &&
        widget.lightSetupId != null) {
      lightSetup = await db.getLightSetupById(widget.lightSetupId!);
      if (lightSetup?.locationBasePlanId != null) {
        linkedSet = await db.getLocationById(lightSetup!.locationBasePlanId!);
      }
      final setupSiteId = lightSetup?.locationSiteId ?? linkedSet?.siteId;
      if (setupSiteId != null) {
        linkedSite = await db.getSiteById(setupSiteId);
      }
      sceneColor = linkedSet != null
          ? colors.setColor(linkedSet)
          : colors.siteColor(linkedSite?.id);
    } else if (widget.scope == FloorPlanScope.site && widget.siteId != null) {
      linkedSite = await db.getSiteById(widget.siteId!);
      sceneColor = colors.siteColor(widget.siteId);
    }

    final navTargets = await _loadNavTargets(db);
    final gear = await ProjectGear.load(db, widget.projectId);
    final cast = await PlanCast.load(db, widget.projectId);
    final roster = await PlanCast.roster(db, widget.projectId);

    // Esquema de luz que se enseña: el del plano, el elegido a mano o, si
    // no, el primero del set o de la localización.
    final projectSetups = await db.getLightSetupsForProject(widget.projectId);
    LightSetup? setupById(int? id) {
      for (final s in projectSetups) {
        if (s.id == id) return s;
      }
      return null;
    }

    if (shot != null) {
      final ownLeg = _legOf(shot);
      lightSetup = setupById(
        ownLeg != null ? ownLeg.lightSetupId : shot.lightSetupId,
      );
    } else if (_setupPicked) {
      lightSetup = setupById(_pickedSetupId);
    }
    // La localización y la zona enseñan su entorno, sin la luz de ningún
    // set: lo que se pone ahí lo heredan todos sus sets (EN).

    // Un solo lienzo: las cuatro capas, todas editables.
    final elements = <PlanElement>[];
    void addLayer(PlanLayer layer, List<PlanElement> list) {
      for (final el in list) {
        el.layer = layer;
        if (layer != PlanLayer.shot) el.id = --_tempId;
        elements.add(el);
      }
    }

    var siteElements = FloorPlanJson.decode(linkedSite?.floorPlanJson);
    var zoneElements = FloorPlanJson.decode(linkedSet?.floorPlanJson);
    final envScoped =
        lightSetup != null &&
        linkedSite != null &&
        (widget.scope == FloorPlanScope.lightSetup ||
            widget.scope == FloorPlanScope.shot);
    if (envScoped) {
      // Los cambios del set van por identificador: el entorno los necesita
      // fijos antes de aplicarlos (SG.3).
      if (LightOverrides.ensureUids(siteElements).isNotEmpty) {
        await _repo.saveElements(
          scope: FloorPlanScope.site,
          elements: siteElements,
          siteId: linkedSite.id,
        );
      }
      if (linkedSet != null &&
          LightOverrides.ensureUids(zoneElements).isNotEmpty) {
        await _repo.saveElements(
          scope: FloorPlanScope.set,
          elements: zoneElements,
          setId: linkedSet.id,
        );
      }
      final resolved = EnvOverrides.apply(
        environment: siteElements,
        set: zoneElements,
        json: lightSetup.envOverridesJson,
      );
      siteElements = resolved.environment;
      zoneElements = resolved.set;
      if (linkedSet == null) {
        // Sin zona, lo que añade el set va con el entorno.
        siteElements = [...siteElements, ...zoneElements];
        zoneElements = const [];
      }
    }
    final originals = <String, PlanElement>{};
    final overrides = LightOverrides.decode(shot?.lightOverridesJson);
    // Las luces del entorno, también con los ajustes propios del plano
    // (apagar una solo en este plano, EN).
    List<PlanElement> withShotOverrides(List<PlanElement> list) => [
      for (final el in list)
        if (el.type == ElementType.light &&
            overrides[LightOverrides.uidOf(el)] != null)
          () {
            final uid = LightOverrides.uidOf(el)!;
            originals[uid] = el;
            return overrides[uid]!
              ..props[LightOverrides.uidKey] = uid
              ..shotOverride = true;
          }()
        else
          el,
    ];
    addLayer(PlanLayer.environment, withShotOverrides(siteElements));
    addLayer(PlanLayer.set, withShotOverrides(zoneElements));
    // La luz del esquema. Si el plano tiene ajustes propios, se ve con
    // ellos y se recuerda cómo es en el esquema.
    final setupLights = FloorPlanJson.decode(lightSetup?.planJson);
    // La luz del grupo, como la ve este set, y con los ajustes del plano.
    final group = lightSetup?.groupId != null
        ? await db.getSetGroupById(lightSetup!.groupId!)
        : null;
    addLayer(PlanLayer.groupLight, [
      for (final el in GroupLight.visible(
        group?.planJson,
        lightSetup?.planJson,
      ))
        if (overrides[LightOverrides.uidOf(el)] case final own?)
          () {
            final uid = LightOverrides.uidOf(el)!;
            originals[uid] = el;
            return own
              ..props[LightOverrides.uidKey] = uid
              ..shotOverride = true;
          }()
        else
          el,
    ]);
    final siteSets = [
      for (final s in projectSetups)
        if (s.kind == LightSetupKind.plan &&
            linkedSite != null &&
            (s.locationSiteId ??
                    allSets
                        .where((z) => z.id == s.locationBasePlanId)
                        .firstOrNull
                        ?.siteId) ==
                linkedSite.id)
          s,
    ];
    final shownLights = [
      for (final el in setupLights)
        if (overrides[LightOverrides.uidOf(el)] case final own?)
          () {
            final uid = LightOverrides.uidOf(el)!;
            originals[uid] = el;
            return own
              ..props[LightOverrides.uidKey] = uid
              ..shotOverride = true;
          }()
        else
          el,
    ];
    addLayer(PlanLayer.light, shownLights);
    if (shot != null) {
      // En una secuencia, cada tramo ve solo lo que se colocó en él.
      final inSequence = ShotRoute.decode(shot.routeJson).isNotEmpty;
      addLayer(PlanLayer.shot, [
        for (final el in await _repo.loadElements(
          scope: FloorPlanScope.shot,
          shotId: shot.id,
        ))
          if (!inSequence || FloorPlanRepository.legOf(el) == (widget.leg ?? 0))
            el,
      ]);
    }

    // Todo elemento lleva identificador estable: con él se reconoce en el
    // 3D, en Unreal y en la lista de elementos. Lo que aún no lo tenía (una
    // planta de antes) se guarda una vez al terminar de cargar.
    final unsaved = {
      for (final el in LightOverrides.ensureUids(elements)) el.layer,
    };
    // El entorno como es en el set, sin los ajustes propios del plano.
    final envBaseline = _CameraPlanEditorState._baselineOf([
      for (final e in elements)
        if (e.layer == PlanLayer.environment || e.layer == PlanLayer.set)
          e.shotOverride ? originals[LightOverrides.uidOf(e)] ?? e : e,
    ]);
    final groupBaseline = _CameraPlanEditorState._baselineOf(
      elements.where((e) => e.layer == PlanLayer.groupLight),
    );

    // Zonas de los sets sobre el plano maestro.
    final zones = <PlanZone>[];
    Rect? setZone;
    for (final set in allSets) {
      if (linkedSite == null || set.siteId != linkedSite.id) continue;
      final rect = SetZone.decode(set.sitePlacementJson);
      if (rect == null) continue;
      final active = set.id == linkedSet?.id;
      if (active) setZone = rect;
      zones.add(
        PlanZone(
          rect: rect,
          color: colors.setColor(set),
          label: set.locationName,
          active: active,
        ),
      );
    }

    // Color del esquema: su orden entre los de su mismo set.
    var setupColor = kLightSetupColors.first;
    if (lightSetup != null) {
      final siblings = projectSetups
          .where(
            (s) =>
                s.locationBasePlanId == lightSetup!.locationBasePlanId &&
                s.locationSiteId == lightSetup.locationSiteId,
          )
          .toList();
      final index = siblings.indexWhere((s) => s.id == lightSetup!.id);
      setupColor =
          kLightSetupColors[(index < 0 ? 0 : index) % kLightSetupColors.length];
    }

    final allShots = await (db.select(
      db.shots,
    )..where((s) => s.projectId.equals(widget.projectId))).get();
    // Las cámaras de los otros planos que comparten este esquema de luz.
    final otherCameras = <PlanElement>[];
    final otherCameraShot = <PlanElement, PlanTarget>{};
    final unlitShots = <int>{};
    final cameraLinks = <String, int>{};
    final followLabels = scene == null
        ? const <String, String>{}
        : await PlanFollow.sceneLabels(db, scene);
    final setupCameraUids = {
      for (final el in setupLights)
        if (el.type == ElementType.camera) ?LightOverrides.uidOf(el),
    };
    if (lightSetup != null) {
      for (final other in allShots) {
        if (other.id == shot?.id) continue;
        // Los planos del set que aún no tienen luz también enseñan su
        // cámara: tocarla ofrece usar este esquema.
        final otherScene = allScenes
            .where((s) => s.id == other.sceneId)
            .firstOrNull;
        final unlit =
            other.lightSetupId == null &&
            lightSetup.locationBasePlanId != null &&
            (other.locationBasePlanId ?? otherScene?.locationId) ==
                lightSetup.locationBasePlanId;
        if (other.lightSetupId != lightSetup.id && !unlit) continue;
        if (unlit) unlitShots.add(other.id);
        final sceneNumber = allScenes
            .where((s) => s.id == other.sceneId)
            .map((s) => s.label)
            .firstOrNull;
        final tag = sceneNumber == null
            ? 'P${other.number}'
            : '$sceneNumber·${other.number}';
        for (final row in await db.getCameraPlanElementsForShot(other.id)) {
          if (row.type != 'camera') continue;
          final linkedTo = CameraLinks.setupCameraOf(PlanElement.fromDb(row));
          if (linkedTo != null && setupCameraUids.contains(linkedTo)) {
            // Copia de una cámara de este esquema: ya se ve la cámara.
            cameraLinks[linkedTo] = (cameraLinks[linkedTo] ?? 0) + 1;
            continue;
          }
          final ghost = PlanElement.fromDb(row)
            ..id = --_tempId
            ..props['shotTag'] = unlit ? '$tag · sin luz' : tag
            // Una cámara que no está en este plano no le hace sombra.
            ..props[LightScene.noShadowKey] = true;
          otherCameras.add(ghost);
          otherCameraShot[ghost] = PlanTarget.shot(
            other.id,
            sceneNumber == null
                ? 'Plano ${other.number}'
                : 'Esc $sceneNumber · Plano ${other.number}',
          );
        }
      }
    }

    final setSceneIds = {
      for (final s in allScenes)
        if (linkedSet != null && s.locationId == linkedSet.id) s.id,
    };
    final setShotCount = allShots
        .where((s) => setSceneIds.contains(s.sceneId))
        .length;
    final setupShotCount = allShots
        .where((s) => lightSetup != null && s.lightSetupId == lightSetup.id)
        .length;

    ui.Image? bgImage;
    Rect? bgRect;
    var bgOpacity = 0.85;
    final scanService = LocationScanService(db);
    final scopeKind = switch (widget.scope) {
      FloorPlanScope.site => FloorPlanScopeKind.site,
      FloorPlanScope.set => FloorPlanScopeKind.set,
      FloorPlanScope.lightSetup ||
      FloorPlanScope.shot => FloorPlanScopeKind.shot,
    };
    final bgMeta = await scanService.resolveFloorPlanBackground(
      scope: scopeKind,
      siteId: widget.siteId ?? linkedSite?.id,
      setId: widget.setId ?? linkedSet?.id,
    );
    if (bgMeta != null && bgMeta.topDownImagePath != null) {
      final file = File(bgMeta.topDownImagePath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        bgImage = frame.image;
        bgRect = Rect.fromLTWH(
          0,
          0,
          bgMeta.topDownWidthPx,
          bgMeta.topDownHeightPx,
        );
        bgOpacity = bgMeta.topDownOpacity;
      }
    }

    if (!mounted || generation != _loadGeneration) return;
    _annotationController.replaceDocument(
      AnnotationDocument.decode(annotationRow?.documentJson),
    );
    final guide = await _loadGuide(db, linkedSite, allSets);
    final planImages = await _imageStore.forLayers(
      projectId: widget.projectId,
      siteId: linkedSite?.id ?? widget.siteId,
      setId: linkedSet?.id ?? widget.setId,
      lightSetupId: lightSetup?.id ?? widget.lightSetupId,
      shotId: shot?.id,
    );
    _imageCache.ensure(planImages);
    if (!mounted || generation != _loadGeneration) return;
    final fit = _fitOnLoad;
    _fitOnLoad = false;
    _update(() {
      _images = planImages;
      if (!planImages.any((i) => i.id == _selectedImageId)) {
        _selectedImageId = null;
      }
      if (guide != null) {
        _guideSets = guide.sets;
        _guideZoned = guide.zoned;
        _guideSetsWithShots = guide.withShots;
        _guideShotReady = guide.shotReady;
      }
      _elements
        ..clear()
        ..addAll(elements);
      _hiddenElements
        ..clear()
        // En un plano, la cámara del esquema de la que lleva copia no se
        // pinta dos veces.
        ..addAll(_CameraPlanEditorState._linkedSetupCameras(elements));
      _uidsToSave = unsaved;
      _selected = null;
      _selectedPathIndex = null;
      _multi.clear();
      _segmentStart = null;
      _segmentHover = null;
      _zoneEditRect = null;
      _undoStack.clear();
      _redoStack.clear();
      _metersPerUnit =
          FloorPlanJson.decodeDocument(
            linkedSite?.floorPlanJson,
          ).metersPerUnit ??
          FloorPlanJson.decodeDocument(
            linkedSet?.floorPlanJson,
          ).metersPerUnit ??
          FloorPlanJson.decodeDocument(lightSetup?.planJson).metersPerUnit ??
          defaultMetersPerUnit;
      _lightSetup = lightSetup;
      _zones = zones;
      if (setZone != null &&
          (_setZone == null || (fit && setZone != _setZone))) {
        _pendingFit = setZone;
      }
      _setZone = setZone;
      _setShotCount = setShotCount;
      _setupShotCount = setupShotCount;
      _setupColor = setupColor;
      _gear = gear;
      _cast = cast;
      _roster = roster;
      _ambient = FloorPlanRepository.ambientOf(lightSetup);
      _setupOriginals
        ..clear()
        ..addAll(originals);
      _group = group;
      _siteSets = siteSets;
      _envBaseline = envBaseline;
      _groupBaseline = groupBaseline;
      _hiddenGroupLights = FloorPlanJson.decodeDocument(
        lightSetup?.planJson,
      ).hiddenGroupLights;
      if (_scopesForSetup != lightSetup?.id) {
        _scopesForSetup = lightSetup?.id;
        _envScope = null;
        _groupLightScope = null;
      }
      _otherCameras = otherCameras;
      _otherCameraShot
        ..clear()
        ..addAll(otherCameraShot);
      _unlitShots = unlitShots;
      _cameraLinks = cameraLinks;
      _followLabels = followLabels;
      _shot = shot;
      _scene = scene;
      _linkedSet = linkedSet;
      _linkedSite = linkedSite;
      _environment = FloorPlanRepository.environmentOfSet(
        linkedSet?.floorPlanJson,
        linkedSite?.floorPlanJson,
      );
      _sceneColor = sceneColor;
      _navTargets = navTargets;
      _backgroundImage = bgImage;
      _backgroundRect = bgRect;
      _backgroundOpacity = bgOpacity;
      _loading = false;
    });
    _lastSaved = _snapshot();
    if (!_loadedOnce) {
      _loadedOnce = true;
      if (_CameraPlanEditorState._reopen3dScreen) {
        _CameraPlanEditorState._reopen3dScreen = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _open3dScreen();
        });
      }
    }
    _claimLive();
    // Si otro equipo la está editando, no se toca: se guardará al soltarla.
    if (_uidsToSave.isNotEmpty &&
        _peerBlocking(ref.read(liveEditingProvider)) == null) {
      unawaited(_saveNewUids());
    }
  }

  // ── Edición compartida ────────────────────────────────────────────────────

  /// Qué planta es esta para los demás equipos. Abrirla no la toma: se toma
  /// al cambiar algo ([_touchLive]) y se suelta tras 2 minutos sin tocarla
  /// (fase 0 de colaboración). Así quien solo mira no bloquea a nadie.
  void _claimLive() {
    if (!mounted) return;
    final live = ref.read(liveEditingProvider);
    _live = live;
    String? keyOf(FloorPlanScope scope) => switch (scope) {
      FloorPlanScope.site =>
        _linkedSite?.uid == null ? null : LiveKey.site(_linkedSite!.uid!),
      FloorPlanScope.set =>
        _linkedSet?.uid == null ? null : LiveKey.set(_linkedSet!.uid!),
      FloorPlanScope.lightSetup =>
        _lightSetup?.uid == null ? null : LiveKey.lightSetup(_lightSetup!.uid!),
      FloorPlanScope.shot =>
        _shot?.uid == null ? null : LiveKey.shot(_shot!.uid!),
    };
    _layerKeys = [for (final scope in FloorPlanScope.values) ?keyOf(scope)];
    final key = keyOf(widget.scope);
    if (key == null || key == _liveKey) return;
    // Al pasar a otro plano (FL.6), el anterior se suelta ya.
    final previous = _liveKey;
    if (previous != null) live.leave(previous);
    _liveKey = key;
  }

  /// Otro equipo que edita esta planta (o una capa que se ve en ella) desde
  /// antes: mientras tanto aquí no se toca.
  String? _peerBlocking(LiveEditing live) {
    final own = live.holderOf(_liveKey);
    if (own != null) return own.label;
    for (final key in _layerKeys) {
      if (key == _liveKey) continue;
      final mine = live.myShotUid == _liveKey ? live.mySince : null;
      final holder = live.holderBefore(key, mine);
      if (holder != null) return holder.label;
    }
    return null;
  }

  Future<void> _saveAnnotations(AnnotationDocument document) => ref
      .read(databaseProvider)
      .saveProjectAnnotationDocument(
        projectId: widget.projectId,
        targetType: _annotationTargetType,
        targetId: _annotationTargetId,
        documentJson: document.encode(),
        documentSchemaVersion: document.schemaVersion,
      );

  Future<List<CameraPlanNavTarget>> _loadNavTargets(AppDatabase db) async {
    final scenes =
        await (db.select(db.scenes)
              ..where((s) => s.projectId.equals(widget.projectId))
              ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
            .get();
    final sets = await db.getLocationsMapForProject(widget.projectId);
    final sites = await (db.select(
      db.locationSites,
    )..where((s) => s.projectId.equals(widget.projectId))).get();
    final allSets = sets.values.toList();
    final colors = ProjectColorScheme.resolve(
      sites: sites,
      sets: allSets,
      scenes: scenes,
    );
    final sitesById = {for (final s in sites) s.id: s};
    final targets = <CameraPlanNavTarget>[];
    final shotsByScene = <int, List<Shot>>{};
    for (final shot in await db.getShotsForProject(widget.projectId)) {
      (shotsByScene[shot.sceneId] ??= []).add(shot);
    }
    for (final shots in shotsByScene.values) {
      shots.sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.number.compareTo(b.number);
      });
    }

    for (final scene in scenes) {
      final color = colors.sceneColor(scene);
      final site = scene.locationSiteId != null
          ? sitesById[scene.locationSiteId]
          : null;
      final siteName =
          site?.name ??
          (scene.locationPureName.trim().isNotEmpty
              ? scene.locationPureName.trim()
              : 'Sin localización');
      for (final shot in shotsByScene[scene.id] ?? const <Shot>[]) {
        targets.add(
          CameraPlanNavTarget(
            shotId: shot.id,
            sceneId: scene.id,
            sceneNumber: scene.label,
            shotNumber: shot.number,
            sceneName: scene.name,
            sceneColor: color,
            siteName: siteName,
          ),
        );
      }
    }
    return targets;
  }

  /// Tramo de secuencia que se está viendo, si el plano lo es.
  ShotLeg? _legOf(Shot shot) {
    final route = ShotRoute.decode(shot.routeJson);
    final index = widget.leg;
    return index != null && index >= 0 && index < route.length
        ? route[index]
        : null;
  }
}
