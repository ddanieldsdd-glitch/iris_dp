part of 'camera_plan_editor.dart';

/// Tocar, arrastrar y seleccionar en el lienzo: buscar qué hay bajo el
/// dedo, mover, girar, recorridos y marcas (RD.4).
extension _EditorGestures on _CameraPlanEditorState {
  Offset _toCanvasCoords(Offset localPos) {
    return (localPos - _canvasOffset) / _scale;
  }

  PlanElement? _elementAt(Offset canvasPos) {
    final slack = 1 / math.min(1.0, _scale);
    for (final el in _drawnElements.reversed) {
      if (PlanSegment.isSegment(el) || PlanTruss.isTruss(el)) continue;
      if ((el.position - canvasPos).distance < 28 * slack) return el;
    }
    // Un truss se coge por cualquier punto de su tramo.
    for (final el in _drawnElements.reversed) {
      if (PlanTruss.isTruss(el) &&
          PlanTruss.distanceTo(el, canvasPos) < 12 * slack) {
        return el;
      }
    }
    // Una línea de sección (AM.6), por cualquier punto.
    for (final el in _drawnElements.reversed) {
      if (PlanSection.isSection(el) &&
          PlanSection.contains(el, canvasPos, slop: 10 * slack)) {
        return el;
      }
    }
    // Los tramos, después: lo que está encima de una pared se coge antes.
    for (final el in _drawnElements.reversed) {
      if (!PlanSegment.isSegment(el)) continue;
      final reach = PlanSegment.kind(el) == PlanSegment.kindStreet ? 30 : 10;
      if (PlanSegment.distanceTo(el, canvasPos) < reach * slack) return el;
    }
    // Forjados y volúmenes (AM.2), tocando dentro: lo último, porque lo
    // que está encima se coge antes.
    for (final el in _drawnElements.reversed) {
      if (ArchSolid.isSolid(el) &&
          ArchSolid.contains(el, canvasPos, _metersPerUnit)) {
        return el;
      }
      // Una escalera (AM.6), tocando un peldaño.
      if (ArchStair.isStair(el) &&
          ArchStair.contains(el, canvasPos, _metersPerUnit)) {
        return el;
      }
    }
    return null;
  }

  /// Asa del tramo seleccionado bajo el cursor: 0 inicio, 1 final, 2 curva.
  int? _segmentHandleAt(Offset canvasPos) {
    final el = _selected;
    final reach = 12 / _scale;
    // Un truss se estira por sus extremos.
    if (el != null && PlanTruss.isTruss(el) && _multi.isEmpty) {
      if ((PlanTruss.start(el) - canvasPos).distance < reach) return 0;
      if ((PlanTruss.end(el) - canvasPos).distance < reach) return 1;
      return null;
    }
    if (el == null || !PlanSegment.isSegment(el) || _multi.isNotEmpty) {
      return null;
    }
    if ((PlanSegment.start(el) - canvasPos).distance < reach) return 0;
    if ((PlanSegment.end(el) - canvasPos).distance < reach) return 1;
    if ((PlanSegment.midpoint(el) - canvasPos).distance < reach) return 2;
    return null;
  }

  /// La marca seleccionada del elemento, si la hay: se gira ella y no el
  /// elemento.
  int? _markOf(PlanElement el) {
    final index = _selectedPathIndex;
    return index != null &&
            _canMark(el) &&
            index >= 0 &&
            index < el.pathPoints.length
        ? index
        : null;
  }

  /// El toque cae donde se gira el seleccionado: en su asa o en la corona
  /// que lo rodea (si ahí no hay otro elemento que coger).
  bool _hitRotationHandle(Offset canvasPos) {
    final el = _selected;
    if (el == null || PlanSegment.isSegment(el) || _multi.length > 1) {
      return false;
    }
    if (CameraPlanPainter.isAttachedOpening(el, _visibleElements)) {
      return false;
    }
    final mark = _markOf(el);
    final centre = mark == null ? el.position : el.pathPoints[mark];
    final rotation = mark == null
        ? el.rotation
        : PlanMarks.rotationAt(el, mark);
    final handle = CameraPlanPainter.rotationHandleAt(centre, rotation, _scale);
    if ((canvasPos - handle).distance < 18 / _scale) return true;
    final distance = (canvasPos - centre).distance;
    final inner = 28 / math.min(1.0, _scale);
    final outer =
        CameraPlanPainter.rotationHandleDistance(_scale) + 10 / _scale;
    if (distance < inner || distance > outer) return false;
    final under = _elementAt(canvasPos);
    return under == null || (mark == null && identical(under, el));
  }

  void _updateRotation(PlanElement el, Offset canvasPos) {
    final mark = _markOf(el);
    final centre = mark == null ? el.position : el.pathPoints[mark];
    final angle = math.atan2(
      canvasPos.dy - centre.dy,
      canvasPos.dx - centre.dx,
    );
    var degrees = ((angle * 180 / math.pi) + 90) % 360;
    // Con Mayús, de 15 en 15 grados.
    if (HardwareKeyboard.instance.isShiftPressed) {
      degrees = (degrees / 15).round() * 15.0;
    }
    degrees = (degrees % 360 + 360) % 360;
    if (mark == null) {
      el.rotation = degrees;
    } else {
      PlanMarks.setRotation(el, mark, degrees);
    }
  }

  Future<void> _addPathPointAt(Offset canvasPos) async {
    final cam = _selected;
    if (cam == null || !_canMark(cam)) return;
    // Un foco con posiciones es siempre un ajuste del plano (PL.3).
    _ownLightForMarks(cam);
    _update(() {
      PlanMarks.add(cam, canvasPos);
      _selectedPathIndex = cam.pathPoints.length - 1;
    });
    await _persistElement(cam);
  }

  /// Nueva posición, un paso más allá de la última, hacia donde mira.
  Future<void> _addPathPointAhead() async {
    final cam = _selected;
    if (cam == null || !_canMark(cam)) return;
    final last = cam.pathPoints.length - 1;
    final rad =
        (last < 0 ? cam.rotation : PlanMarks.rotationAt(cam, last)) *
        math.pi /
        180;
    final forward = Offset(math.sin(rad), -math.cos(rad));
    final origin = cam.pathPoints.isEmpty ? cam.position : cam.pathPoints.last;
    // Una cámara avanza; un actor suele cruzar el cuadro; un foco suele
    // cambiar sin moverse (se arrastra si se mueve).
    final step = switch (cam.type) {
      ElementType.camera => forward * 80,
      ElementType.light => Offset(-forward.dy, forward.dx) * 30,
      _ => Offset(-forward.dy, forward.dx) * 80,
    };
    await _addPathPointAt(origin + step);
  }

  Future<void> _deleteSelectedPathPoint() async {
    final cam = _selected;
    final index = _selectedPathIndex;
    if (cam == null ||
        !_canMark(cam) ||
        index == null ||
        index < 0 ||
        index >= cam.pathPoints.length) {
      return;
    }
    _update(() {
      PlanMarks.removeAt(cam, index);
      _selectedPathIndex = null;
    });
    await _persistElement(cam);
  }

  Future<void> _clearCameraPath() async {
    final cam = _selected;
    if (cam == null || !_canMark(cam)) return;
    _update(() {
      PlanMarks.clear(cam);
      _selectedPathIndex = null;
    });
    await _persistElement(cam);
  }

  int? _pathPointIndexAt(PlanElement camera, Offset canvasPos) =>
      CameraPlanPainter.pathPointAt(camera, canvasPos, scale: _scale);

  /// Lo que admite marcas bajo [canvasPos]: una de sus marcas o el propio
  /// elemento.
  PlanElement? _markSourceAt(Offset canvasPos) {
    for (final el in _elements.reversed) {
      if (_canMark(el) && _pathPointIndexAt(el, canvasPos) != null) return el;
    }
    final hit = _elementAt(canvasPos);
    return hit != null && _canMark(hit) ? hit : null;
  }

  void _onPanStart(DragStartDetails d) {
    _canvasFocus.requestFocus();
    final canvasPos = _toCanvasCoords(d.localPosition);
    if (_zoneMode) {
      _update(() {
        _zoneStart = canvasPos;
        _zoneDraft = Rect.fromPoints(canvasPos, canvasPos);
      });
      return;
    }
    final zoneEdit = _zoneEditRect;
    if (zoneEdit != null) {
      final reach = 16 / _scale;
      final corners = _CameraPlanEditorState._corners(zoneEdit);
      _zoneGrip = null;
      for (var i = 0; i < corners.length; i++) {
        if ((corners[i] - canvasPos).distance < reach) _zoneGrip = i;
      }
      if (_zoneGrip == null && zoneEdit.contains(canvasPos)) _zoneGrip = -1;
      return;
    }
    final image = _selectedImage;
    if (image != null && !image.locked) {
      final grip = _imageGripAt(image, canvasPos);
      if (grip != null) {
        _imageGrip = grip;
        _imageGripStart = canvasPos;
        _imageGripRect = planImageRect(image);
        return;
      }
    }
    if (_tool.drawsSegment) {
      _update(() {
        _segmentStart ??= _snapSegmentPoint(canvasPos);
        _segmentHover = _segmentStart;
      });
      return;
    }
    if (_tool == PlanTool.measure) {
      _update(() => _measure = (from: canvasPos, to: canvasPos));
      return;
    }
    // ⌥ arrastrar: saca una posición nueva del elemento o de una de sus
    // marcas y la lleva donde se suelte (PL.6).
    if (HardwareKeyboard.instance.isAltPressed && _tool == PlanTool.select) {
      final from = _markSourceAt(canvasPos);
      if (from != null) {
        _ownLightForMarks(from);
        _isDraggingPathPoint = true;
        _isRotating = false;
        _dragDirty = true;
        _update(() {
          PlanMarks.add(from, canvasPos);
          _selected = from;
          _selectedPathIndex = from.pathPoints.length - 1;
        });
        return;
      }
    }
    for (final el in _elements.reversed) {
      if (!_canMark(el)) continue;
      final pathIdx = _pathPointIndexAt(el, canvasPos);
      if (pathIdx != null) {
        _isDraggingPathPoint = true;
        _isRotating = false;
        _update(() {
          _selected = el;
          _selectedPathIndex = pathIdx;
        });
        return;
      }
    }
    _segmentHandle = _segmentHandleAt(canvasPos);
    if (_segmentHandle != null) return;
    if (_selected != null && _hitRotationHandle(canvasPos)) {
      _update(() => _isRotating = true);
      _isDraggingPathPoint = false;
      return;
    }
    _isRotating = false;
    _isDraggingPathPoint = false;
    // Con Espacio, arrastrar mueve la vista aunque haya algo debajo.
    final panning = HardwareKeyboard.instance.isLogicalKeyPressed(
      LogicalKeyboardKey.space,
    );
    final tapped = panning ? null : _elementAt(canvasPos);
    // Con ratón, arrastrar en vacío traza un marco de selección. Con el
    // dedo sigue moviendo la vista: no hay otra forma de hacerlo.
    _marqueeStart =
        tapped == null &&
            !panning &&
            _tool == PlanTool.select &&
            d.kind != ui.PointerDeviceKind.touch
        ? canvasPos
        : null;
    _dragging = tapped;
    if (tapped != null && !_multi.contains(tapped)) _select(tapped);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final canvasPos = _toCanvasCoords(d.localPosition);
    if (_imageGrip != null) {
      _update(() => _imageDraft = _imageDragRect(canvasPos));
      return;
    }
    if (_zoneMode) {
      final start = _zoneStart;
      if (start == null) return;
      _update(() => _zoneDraft = Rect.fromPoints(start, canvasPos));
      return;
    }
    final zoneEdit = _zoneEditRect;
    if (zoneEdit != null) {
      final grip = _zoneGrip;
      if (grip == null) {
        _canvasOffset += d.delta;
        return;
      }
      final delta = d.delta / _scale;
      _update(() {
        if (grip == -1) {
          _zoneEditRect = zoneEdit.shift(delta);
        } else {
          // La esquina contraria se queda fija.
          final fixed = _CameraPlanEditorState._corners(
            zoneEdit,
          )[(grip + 2) % 4];
          final next = Rect.fromPoints(fixed, _snapToGrid(canvasPos));
          if (next.width > 40 && next.height > 40) {
            _zoneEditRect = next;
            // Tras cruzar la esquina fija, se sigue cogiendo la misma mano.
            _zoneGrip = _CameraPlanEditorState._corners(next).indexWhere(
              (c) =>
                  (c - fixed).distance > 1 &&
                  c.dx != fixed.dx &&
                  c.dy != fixed.dy,
            );
          }
        }
      });
      return;
    }
    if (_tool.drawsSegment) {
      _update(() => _segmentHover = _snapSegmentPoint(canvasPos));
      return;
    }
    if (_tool == PlanTool.measure) {
      final m = _measure;
      if (m != null) _update(() => _measure = (from: m.from, to: canvasPos));
      return;
    }

    final delta = d.delta / _scale;
    final selected = _selected;
    final handle = _segmentHandle;
    if (selected != null && handle != null) {
      _dragDirty = true;
      _updateDrag(() {
        final point = _snapSegmentPoint(canvasPos, except: selected);
        if (PlanTruss.isTruss(selected)) {
          handle == 0
              ? PlanTruss.setStart(selected, point)
              : PlanTruss.setEnd(selected, point);
          return;
        }
        switch (handle) {
          case 0:
            PlanSegment.setStart(
              selected,
              _snapSegmentPoint(canvasPos, except: selected),
            );
          case 1:
            PlanSegment.setEnd(
              selected,
              _snapSegmentPoint(canvasPos, except: selected),
            );
          default:
            PlanSegment.bendThrough(selected, canvasPos);
        }
      });
      return;
    }
    if (selected != null &&
        (_isDraggingPathPoint || _isRotating || _dragging != null)) {
      _dragDirty = true;
    }
    if (selected != null &&
        _isDraggingPathPoint &&
        _selectedPathIndex != null) {
      _updateDrag(() => selected.pathPoints[_selectedPathIndex!] += delta);
    } else if (selected != null && _isRotating) {
      _updateDrag(() => _updateRotation(selected, canvasPos));
    } else if (_dragging != null) {
      _updateDrag(() {
        for (final el in _multi.contains(_dragging) ? _multi : {_dragging!}) {
          el.position += delta;
          el.pathPoints = [for (final p in el.pathPoints) p + delta];
        }
      });
    } else if (_marqueeStart != null) {
      _updateDrag(() => _marquee = Rect.fromPoints(_marqueeStart!, canvasPos));
    } else {
      _canvasOffset += d.delta;
    }
  }

  /// Selecciona lo que cae dentro del marco. Con Mayús, se añade.
  void _selectInMarquee(Rect area) {
    final inside = [
      for (final el in _visibleElements)
        if (PlanSegment.isSegment(el)
            ? area.contains(PlanSegment.start(el)) &&
                  area.contains(PlanSegment.end(el))
            : area.contains(el.position))
          el,
    ];
    _update(() {
      final keep = HardwareKeyboard.instance.isShiftPressed
          ? _selection
          : const <PlanElement>[];
      final all = {...keep, ...inside}.toList();
      _selectedPathIndex = null;
      _multi
        ..clear()
        ..addAll(all.length > 1 ? all : const []);
      _selected = all.isEmpty ? null : all.last;
    });
  }

  /// Zoom hacia un punto de la pantalla: lo que hay bajo el cursor se
  /// queda donde está.
  void _zoomAt(Offset local, double factor) {
    final next = (_scale * factor).clamp(
      _CameraPlanEditorState._minScale,
      _CameraPlanEditorState._maxScale,
    );
    if (next == _scale) return;
    final anchor = (local - _canvasOffset) / _scale;
    _canvasView.zoomTo(next, local - anchor * next);
  }

  /// Encuadra todo lo que hay en la planta.
  void _fitAll() {
    Rect? bounds;
    for (final el in _visibleElements) {
      for (final p in [
        el.position,
        if (PlanSegment.isSegment(el)) PlanSegment.end(el),
      ]) {
        final at = Rect.fromCircle(center: p, radius: 40);
        bounds = bounds?.expandToInclude(at) ?? at;
      }
    }
    if (bounds != null) _fitTo(bounds);
  }

  Future<void> _onPanEnd(DragEndDetails d) async {
    if (_imageGrip != null) {
      final draft = _imageDraft;
      final image = _selectedImage;
      _imageGrip = null;
      _imageGripStart = null;
      _imageGripRect = null;
      if (draft != null && image != null) {
        await _imageStore.save(
          image.copyWith(
            x: draft.left,
            y: draft.top,
            w: draft.width,
            h: draft.height,
          ),
        );
        await _reloadImages();
      }
      if (mounted) _update(() => _imageDraft = null);
      return;
    }
    if (_zoneMode) {
      final draft = _zoneDraft;
      _update(() {
        _zoneMode = false;
        _zoneStart = null;
        _zoneDraft = null;
      });
      if (draft != null && draft.width > 40 && draft.height > 40) {
        await _saveZone(draft);
      }
      return;
    }
    if (_zoneEditRect != null) {
      _zoneGrip = null;
      return;
    }
    if (_tool.drawsSegment) {
      // Arrastrar dibuja un tramo; tocar punto a punto los encadena.
      final from = _segmentStart;
      final to = _segmentHover;
      _update(() {
        _segmentStart = null;
        _segmentHover = null;
      });
      if (from != null && to != null) await _addSegment(from, to);
      return;
    }
    if (_tool == PlanTool.measure) return;

    if (_marqueeStart != null) {
      final area = _marquee;
      _update(() {
        _marqueeStart = null;
        _marquee = null;
      });
      if (area != null && area.shortestSide > 4 / _scale) {
        _selectInMarquee(area);
      }
      return;
    }

    // Se guarda siempre que algo se haya movido, se suelte como se suelte.
    final moved = _dragDirty;
    final dragged = _dragging;
    final wasHandle = _segmentHandle != null;
    _dragDirty = false;
    _dragging = null;
    _segmentHandle = null;
    if (_isRotating) _update(() => _isRotating = false);
    _isDraggingPathPoint = false;
    // Al soltar, la pantalla entera se pone al día.
    if (moved) _update(() {});
    if (!moved || _selected == null) return;

    if (dragged != null && !wasHandle) {
      final group = _multi.contains(dragged) ? _multi.toList() : [dragged];
      // El imán coloca lo que se ha movido sobre la rejilla.
      final anchor = group.first;
      final shift = _snapToGrid(anchor.position) - anchor.position;
      _update(() {
        for (final el in group) {
          // Puertas y ventanas se enganchan a la pared sobre la que caen.
          if (PlanOpening.isOpening(el) &&
              PlanOpening.snapToWall(el, _visibleElements)) {
            continue;
          }
          // Y una luz de pared, a la suya (CA.3).
          if (LightWallMount.isOn(el)) {
            el.position += shift;
            LightWallMount.snap(el, _visibleElements, _metersPerUnit);
            continue;
          }
          el.position += shift;
          el.pathPoints = [for (final p in el.pathPoints) p + shift];
        }
      });
      // Una luz soltada junto a un truss se cuelga de él; lo colgado de
      // un truss movido lo sigue.
      final hung = _settleRig(group);
      if (hung.isNotEmpty) _update(() {});
      await _persistMany([...group, ...hung]);
      // Mover la nave (su asa) la rehace en su sitio.
      if (group.length == 1 && PlanHall.isHall(dragged)) {
        await _regenerateHall(dragged);
      }
    } else {
      final el = _selected!;
      // Lo colgado de un truss estirado lo sigue.
      final hung = _settleRig([el]);
      await _persistElement(el);
      if (hung.isNotEmpty) await _persistMany(hung);
      // Una pared de la nave estirada o curvada a mano mueve su perímetro.
      final hall = _hallOf(el);
      if (wasHandle &&
          hall != null &&
          PlanHall.syncFromWall(hall, el, _metersPerUnit)) {
        await _regenerateHall(hall);
      }
    }
  }

  void _onTapCanvas(TapDownDetails d) {
    _canvasFocus.requestFocus();
    if (_zoneMode || _zoneEditRect != null) return;
    final canvasPos = _toCanvasCoords(d.localPosition);
    if (_calibrating != null) {
      _addCalibrationPoint(canvasPos);
      return;
    }
    // Una imagen encima (y suelta) se coge antes que lo que tapa.
    final onTop = _imageAt(canvasPos, onTopOnly: true);
    if (onTop != null) {
      _selectImage(onTop);
      return;
    }
    if (_tool.drawsSegment) {
      final point = _snapSegmentPoint(canvasPos);
      final from = _segmentStart;
      if (from == null) {
        _update(() {
          _segmentStart = point;
          _segmentHover = point;
        });
      } else {
        // Encadena: el final de este tramo es el inicio del siguiente.
        _update(() {
          _segmentStart = point;
          _segmentHover = point;
        });
        _addSegment(from, point);
      }
      return;
    }
    if (_tool == PlanTool.measure) {
      _update(() => _measure = null);
      return;
    }
    for (final el in _elements.reversed) {
      if (!_canMark(el)) continue;
      final pathIdx = _pathPointIndexAt(el, canvasPos);
      if (pathIdx != null) {
        _update(() {
          _selected = el;
          _selectedPathIndex = pathIdx;
        });
        return;
      }
    }
    if (_segmentHandleAt(canvasPos) != null) return;
    // Pulsar el asa de giro no es tocar en vacío: no deselecciona.
    if (_hitRotationHandle(canvasPos)) return;
    final hit = _elementAt(canvasPos);
    if (hit == null && _showOtherCameras) {
      // Tocar la cámara de otro plano abre ese plano.
      for (final ghost in _otherCameras) {
        if ((ghost.position - canvasPos).distance < 28) {
          final target = _otherCameraShot[ghost];
          if (target != null) {
            if (_unlitShots.contains(target.id)) {
              unawaited(_offerSetupTo(target));
            } else {
              _openTarget(target);
            }
            return;
          }
        }
      }
    }
    if (hit == null) {
      // En vacío: una imagen de debajo (o bloqueada) se elige.
      final below = _imageAt(canvasPos, onTopOnly: false);
      if (below != null) {
        _selectImage(below);
        return;
      }
    }
    if (_selectedImageId != null) _update(() => _selectedImageId = null);
    _select(hit, add: HardwareKeyboard.instance.isShiftPressed);
    // Tocar el suelo de un recinto cerrado abre sus propiedades.
    final room = hit == null ? _lightScene.roomAt(canvasPos) : null;
    _update(() => _selectedRoom = room == null ? null : canvasPos);
  }

  /// La planta vista por la luz. Se guarda mientras no cambie nada que la
  /// afecte: el fotómetro y los recintos la piden en cada montaje.
  LightScene get _lightScene => _lightMap.scene(
    _visibleElements,
    metersPerUnit: _metersPerUnit,
    ambient: _lightSetup == null ? null : _effectiveAmbient,
  );

  void _onDoubleTapCanvas(TapDownDetails d) {
    if (_tool.drawsSegment) {
      // Doble toque: termina la cadena de tramos.
      _update(() {
        _segmentStart = null;
        _segmentHover = null;
      });
      return;
    }
    final picked = _selected;
    if (picked == null || !_canMark(picked)) return;
    final canvasPos = _toCanvasCoords(d.localPosition);
    if (_elementAt(canvasPos) != null) return;
    if (CameraPlanPainter.pathPointAt(_selected!, canvasPos, scale: _scale) !=
        null) {
      return;
    }
    _addPathPointAt(canvasPos);
  }
}
