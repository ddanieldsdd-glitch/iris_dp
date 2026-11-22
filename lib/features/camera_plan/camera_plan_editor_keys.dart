part of 'camera_plan_editor.dart';

/// Teclado y menú contextual: copiar, cortar, pegar, mover, girar y los
/// atajos del editor (RD.4).
extension _EditorKeys on _CameraPlanEditorState {
  // ── Copiar, cortar, pegar, mover y girar con el teclado ───────────────────

  void _copySelection() {
    final picked = _selection;
    if (picked.isEmpty) return;
    _CameraPlanEditorState._clipboard = FloorPlanJson.encode(picked);
    // Marca en el portapapeles del sistema: si al pegar sigue ahí, se pega
    // esto; si no, lo último copiado fue de fuera (una imagen, quizá).
    Clipboard.setData(
      const ClipboardData(text: _CameraPlanEditorState._clipboardMark),
    ).catchError((_) {});
    _showSnack(
      picked.length == 1 ? 'Copiado.' : '${picked.length} elementos copiados.',
    );
  }

  Future<void> _cutSelection() async {
    if (_selection.isEmpty) return;
    _copySelection();
    await _deleteSelected();
  }

  /// Pega lo copiado donde está el cursor (o en el centro de la vista).
  Future<void> _paste() async {
    // Lo copiado aquí manda mientras su marca siga en el portapapeles; si
    // no, lo último copiado vino de fuera: una imagen va a la planta.
    if (!await _clipboardIsOurs() && await _pasteImage(quiet: true)) return;
    final stored = _CameraPlanEditorState._clipboard;
    if (stored == null) return;
    final copies = FloorPlanJson.decode(stored);
    if (copies.isEmpty) return;
    var centre = Offset.zero;
    for (final el in copies) {
      centre += el.position;
    }
    centre = centre / copies.length.toDouble();
    final shift = _snapToGrid(_cursor ?? _viewCenter) - centre;
    // Identificadores propios: no son los elementos copiados.
    LightOverrides.renewUids(copies);
    for (final el in copies) {
      el
        ..id = 0
        ..position += shift
        ..pathPoints = [for (final p in el.pathPoints) p + shift];
      await _addElement(el, keepPosition: true, select: false);
    }
    if (!mounted) return;
    _update(() {
      _selectedPathIndex = null;
      _multi
        ..clear()
        ..addAll(copies.length > 1 ? copies : const []);
      _selected = copies.last;
    });
  }

  void _selectAll() {
    final all = _visibleElements.toList();
    if (all.isEmpty) return;
    _update(() {
      _selectedPathIndex = null;
      _multi
        ..clear()
        ..addAll(all.length > 1 ? all : const []);
      _selected = all.last;
    });
  }

  /// Mueve la selección un centímetro (o diez, con Mayús).
  Future<void> _nudge(Offset direction, {bool big = false}) async {
    final picked = _selection;
    if (picked.isEmpty) return;
    final delta = direction * ((big ? 0.10 : 0.01) / _metersPerUnit);
    _update(() {
      for (final el in picked) {
        el.position += delta;
        el.pathPoints = [for (final p in el.pathPoints) p + delta];
      }
    });
    await _persistMany(picked);
  }

  Future<void> _rotateSelection(double degrees) async {
    final picked = [
      for (final el in _selection)
        if (!PlanSegment.isSegment(el) &&
            !CameraPlanPainter.isAttachedOpening(el, _visibleElements))
          el,
    ];
    if (picked.isEmpty) return;
    _update(() {
      for (final el in picked) {
        el.rotation = ((el.rotation + degrees) % 360 + 360) % 360;
      }
    });
    await _persistMany(picked);
  }

  /// Menú del botón derecho.
  Future<void> _showContextMenu(Offset global, Offset canvasPos) async {
    final under = _elementAt(canvasPos);
    if (under != null && !_selection.contains(under)) _select(under);
    final has = _selection.isNotEmpty;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        global.dx,
        global.dy,
        global.dx,
        global.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'copy',
          enabled: has,
          child: Text('Copiar   ${modKey}C'),
        ),
        PopupMenuItem(
          value: 'cut',
          enabled: has,
          child: Text('Cortar   ${modKey}X'),
        ),
        PopupMenuItem(
          value: 'paste',
          enabled: _CameraPlanEditorState._clipboard != null,
          child: Text('Pegar aquí   ${modKey}V'),
        ),
        PopupMenuItem(
          value: 'duplicate',
          enabled: has,
          child: Text('Duplicar   ${modKey}D'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'all',
          child: Text('Seleccionar todo   ${modKey}A'),
        ),
        PopupMenuItem(
          value: 'delete',
          enabled: has,
          child: const Text('Eliminar   ⌫'),
        ),
      ],
    );
    if (!mounted) return;
    _cursor = canvasPos;
    switch (action) {
      case 'copy':
        _copySelection();
      case 'cut':
        await _cutSelection();
      case 'paste':
        await _paste();
      case 'duplicate':
        await _duplicateSelection();
      case 'all':
        _selectAll();
      case 'delete':
        await _deleteSelected();
    }
  }

  void _showShortcuts() {
    final rows = [
      (
        'Mover la vista',
        'Dos dedos en el trackpad · Espacio + arrastrar · botón central',
      ),
      (
        'Zoom',
        'Pellizco · rueda del ratón · $modKey + dos dedos · $modKey= y $modKey−',
      ),
      ('Encajar todo', '${modKey}0'),
      ('Seleccionar varios', 'Arrastrar en vacío · Mayús + clic · ${modKey}A'),
      ('Deshacer / rehacer', '${modKey}Z / ⇧${modKey}Z'),
      (
        'Copiar / cortar / pegar',
        '${modKey}C / ${modKey}X / ${modKey}V (pega bajo el cursor)',
      ),
      ('Duplicar', '${modKey}D'),
      ('Eliminar', '⌫'),
      ('Mover 1 cm / 10 cm', 'Flechas / ⇧ + flechas'),
      ('Girar 15°', 'R / ⇧R (al arrastrar el asa, ⇧ va de 15 en 15)'),
      ('Herramientas', 'V mover · W pared · M medir · Esc soltar'),
      ('Plano anterior / siguiente', '$modKey← / $modKey→'),
    ];
    final palette = context.palette;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text('Atajos', style: AppTypography.titleMedium(palette)),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (what, how) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 190,
                        child: Text(
                          what,
                          style: AppTypography.bodyMedium(palette),
                        ),
                      ),
                      Expanded(
                        child: Text(how, style: AppTypography.caption(palette)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Atajos del lienzo. Solo valen con el foco en él, para no pisar lo que
  /// se escribe en los paneles.
  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
        _redo,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
        _redo,
    const SingleActivator(LogicalKeyboardKey.keyD, meta: true):
        _duplicateSelection,
    const SingleActivator(LogicalKeyboardKey.keyD, control: true):
        _duplicateSelection,
    const SingleActivator(LogicalKeyboardKey.delete): _deleteSelected,
    const SingleActivator(LogicalKeyboardKey.backspace): _deleteSelected,
    const SingleActivator(LogicalKeyboardKey.escape): _cancel,
    const SingleActivator(LogicalKeyboardKey.keyV): () =>
        _setTool(PlanTool.select),
    const SingleActivator(LogicalKeyboardKey.keyW): () =>
        _setTool(PlanTool.wall),
    const SingleActivator(LogicalKeyboardKey.keyM): () =>
        _setTool(PlanTool.measure),
    // Usar o dejar de usar en este plano los focos elegidos (PL.1).
    const SingleActivator(LogicalKeyboardKey.keyU): _toggleSelectedUse,
    // 1 a 9: qué posición del plano se ve y, si el elegido la tiene, su
    // marca (PL.6).
    for (final (i, key) in const [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ].indexed)
      SingleActivator(key): () => _showPosition(i),
    for (final (meta, control) in const [(true, false), (false, true)]) ...{
      SingleActivator(
        LogicalKeyboardKey.arrowLeft,
        meta: meta,
        control: control,
      ): () =>
          _stepShot(-1),
      SingleActivator(
        LogicalKeyboardKey.arrowRight,
        meta: meta,
        control: control,
      ): () =>
          _stepShot(1),
      SingleActivator(LogicalKeyboardKey.keyC, meta: meta, control: control):
          _copySelection,
      SingleActivator(LogicalKeyboardKey.keyX, meta: meta, control: control):
          _cutSelection,
      SingleActivator(LogicalKeyboardKey.keyV, meta: meta, control: control):
          _paste,
      SingleActivator(LogicalKeyboardKey.keyA, meta: meta, control: control):
          _selectAll,
      SingleActivator(LogicalKeyboardKey.digit0, meta: meta, control: control):
          _fitAll,
      SingleActivator(
        LogicalKeyboardKey.equal,
        meta: meta,
        control: control,
      ): () =>
          _zoomAt(_canvasSize.center(Offset.zero), 1.25),
      SingleActivator(
        LogicalKeyboardKey.minus,
        meta: meta,
        control: control,
      ): () =>
          _zoomAt(_canvasSize.center(Offset.zero), 0.8),
    },
    for (final big in const [false, true]) ...{
      SingleActivator(LogicalKeyboardKey.arrowLeft, shift: big): () =>
          _nudge(const Offset(-1, 0), big: big),
      SingleActivator(LogicalKeyboardKey.arrowRight, shift: big): () =>
          _nudge(const Offset(1, 0), big: big),
      SingleActivator(LogicalKeyboardKey.arrowUp, shift: big): () =>
          _nudge(const Offset(0, -1), big: big),
      SingleActivator(LogicalKeyboardKey.arrowDown, shift: big): () =>
          _nudge(const Offset(0, 1), big: big),
    },
    const SingleActivator(LogicalKeyboardKey.keyR): () => _rotateSelection(15),
    const SingleActivator(LogicalKeyboardKey.keyR, shift: true): () =>
        _rotateSelection(-15),
  };

  /// Esc: suelta lo que se esté haciendo.
  void _cancel() {
    if (_calibrating != null || _selectedImageId != null) {
      _update(() {
        _calibrating = null;
        _calibrationPoints.clear();
        _selectedImageId = null;
      });
    } else if (_zoneEditRect != null) {
      _update(() => _zoneEditRect = null);
    } else if (_segmentStart != null || _measure != null) {
      _update(() {
        _segmentStart = null;
        _segmentHover = null;
        _measure = null;
      });
    } else if (_tool != PlanTool.select) {
      _setTool(PlanTool.select);
    } else {
      _select(null);
    }
  }

  void _zoomBy(double delta) =>
      _zoomAt(_canvasSize.center(Offset.zero), 1 + delta * 2);
}
