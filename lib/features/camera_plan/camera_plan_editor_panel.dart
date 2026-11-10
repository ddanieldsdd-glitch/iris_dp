// Panel de propiedades del elemento seleccionado.
part of 'camera_plan_editor.dart';

class _ElementPanel extends StatefulWidget {
  final AppPalette palette;
  final PlanElement element;

  /// Proyecto de la planta: dónde se guardan las miniaturas de Unreal.
  final int projectId;

  /// A qué afecta cambiar este elemento.
  final String scopeNotice;
  final List<PlanLayer> moveTargets;
  final ValueChanged<PlanLayer> onMove;

  /// Repinta mientras se arrastra un control, sin guardar todavía.
  final VoidCallback onPreview;
  final int? selectedPathIndex;

  /// Abre «Cámaras y lentes del proyecto».
  final VoidCallback? onManageGear;

  /// Personajes del proyecto y su color.
  final Map<String, ({String name, Color color})> cast;

  /// Cambia el color del personaje seleccionado en todo el proyecto.
  final ValueChanged<Color>? onRecolourCast;
  final VoidCallback? onAddPathPoint;
  final VoidCallback? onDeletePathPoint;
  final VoidCallback? onClearPath;
  /// Añade piezas nuevas desde el panel (farolas, fachadas de una calle).
  final ValueChanged<List<PlanElement>>? onAddElements;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  /// Cuántos elementos hay seleccionados a la vez.
  final int selectionCount;

  /// Longitud en metros, si es un tramo.
  final String? lengthLabel;
  final double metersPerUnit;

  /// Ajustes con los que se lee la luz y diafragma de trabajo.
  final ExposureSettings exposure;
  final double targetStop;

  /// Lectura de fotómetro, si lo seleccionado es un fotómetro o un actor.
  final MeterReading? reading;

  /// Equipo del proyecto, para elegir cámara y lente.
  final ProjectGear gear;

  /// Con un plano abierto, una luz del esquema se puede ajustar solo en él.
  final bool canOverride;
  final ValueChanged<bool>? onOverride;

  /// En la planta de luz, una cámara se vincula a planos: abre la lista.
  final VoidCallback? onLinkShots;

  /// A cuántos planos está vinculada la cámara.
  final int linkedShots;

  const _ElementPanel({
    required this.palette,
    required this.element,
    required this.projectId,
    required this.scopeNotice,
    required this.moveTargets,
    required this.onMove,
    required this.onPreview,
    this.selectedPathIndex,
    this.onManageGear,
    this.cast = const {},
    this.onRecolourCast,
    this.onAddPathPoint,
    this.onDeletePathPoint,
    this.onClearPath,
    this.onAddElements,
    required this.onUpdate,
    required this.onDelete,
    required this.onDuplicate,
    this.selectionCount = 1,
    this.lengthLabel,
    this.metersPerUnit = defaultMetersPerUnit,
    this.exposure = const ExposureSettings(),
    this.targetStop = CameraExposure.defaultStop,
    this.reading,
    this.gear = const ProjectGear(),
    this.canOverride = false,
    this.onOverride,
    this.onLinkShots,
    this.linkedShots = 0,
  });

  @override
  State<_ElementPanel> createState() => _ElementPanelState();
}

class _ElementPanelState extends State<_ElementPanel> {
  late TextEditingController _lensCtrl;
  late final TextEditingController _nameCtrl = TextEditingController(
    text: _nameOf(widget.element),
  );

  /// El personaje se llama por su [PlanElement.label]; lo demás, por su
  /// nombre libre.
  static String _nameOf(PlanElement el) => el.type == ElementType.actor
      ? el.label ?? ''
      : el.customName ?? '';

  /// Pone nombre al personaje (si ya existe en el proyecto, coge su color)
  /// o a cualquier otro elemento.
  void _commitName(String value) {
    final element = widget.element;
    final name = value.trim();
    if (element.type != ElementType.actor) {
      if (name == (element.customName ?? '')) return;
      element.customName = name;
      widget.onUpdate();
      return;
    }
    if (name.isEmpty || name == element.label) return;
    element.label = name;
    final known = widget.cast[PlanCast.key(name)];
    if (known != null) element.actorColor = known.color;
    widget.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _lensCtrl = TextEditingController(text: widget.element.lens ?? '');
  }

  @override
  void didUpdateWidget(_ElementPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.element.id != widget.element.id) {
      _lensCtrl.text = widget.element.lens ?? '';
      _nameCtrl.text = _nameOf(widget.element);
    }
  }

  @override
  void dispose() {
    _lensCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Control de una propiedad del haz: repinta al arrastrar y guarda al
  /// soltar.
  Widget _beamSlider(
    String label,
    String value,
    String key,
    double current,
    double min,
    double max, {
    double step = 1,
  }) {
    final palette = widget.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.caption(palette))),
            Text(value, style: AppTypography.caption(palette)),
          ],
        ),
        Slider(
          value: current.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) {
            widget.element.props[key] = (v / step).round() * step;
            widget.onPreview();
          },
          onChangeEnd: (_) => widget.onUpdate(),
        ),
      ],
    );
  }

  /// Foco de un aparato que enfoca: del spot al flood de su ficha. Al
  /// abrir, el mismo flujo se reparte en más ángulo y el eje baja.
  Widget _focusControl(LightOptics optics, double spread) {
    final palette = widget.palette;
    final spot = optics.spotDeg!, flood = optics.floodDeg!;
    final current = spread.clamp(spot, flood).toDouble();
    String deg(double v) =>
        '${v == v.roundToDouble() ? v.round() : v.toStringAsFixed(1)}°';
    void set(double v) {
      widget.element.props[LightBeam.spreadKey] = v;
      widget.onUpdate();
    }

    final light = PlanLight.of(widget.element);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Foco', style: AppTypography.caption(palette)),
            ),
            Text(deg(current), style: AppTypography.caption(palette)),
          ],
        ),
        Slider(
          value: current,
          min: spot,
          max: flood,
          onChanged: (v) {
            widget.element.props[LightBeam.spreadKey] = v.roundToDouble();
            widget.onPreview();
          },
          onChangeEnd: (_) => widget.onUpdate(),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => set(spot),
              child: Text('Spot ${deg(spot)}'),
            ),
            const Spacer(),
            if (light != null)
              Text(
                '${formatLux(light.source.illuminance(3))} a 3 m',
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.textTertiary),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => set(flood),
              child: Text('Flood ${deg(flood)}'),
            ),
          ],
        ),
        if (optics.estimated)
          Text(
            'Rango típico de su formato: la ficha no trae el suyo.',
            style: AppTypography.caption(
              palette,
            ).copyWith(color: palette.textTertiary, fontSize: 10),
          ),
      ],
    );
  }

  void _commitLens(String v) {
    widget.element.lens = v;
    widget.onUpdate();
  }

  /// Bloques abiertos o plegados; se recuerda mientras dure la sesión.
  static final _openSections = <String, bool>{};

  /// Un bloque plegable del panel.
  Widget _section(
    AppPalette palette,
    String title,
    String key,
    List<Widget> children, {
    bool open = true,
  }) {
    final isOpen = _openSections[key] ?? open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _openSections[key] = !isOpen),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: AppTypography.caption(palette).copyWith(
                      color: palette.accent,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  isOpen ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: palette.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (isOpen) ...children,
        Divider(height: 12, color: palette.border),
      ],
    );
  }

  List<Widget> _rotationControls(AppPalette palette, PlanElement element) => [
    Text('Rotación', style: AppTypography.caption(palette)),
    Row(
      children: [
        Expanded(
          child: Slider(
            // Girar en el lienzo puede dejar la rotación
            // fuera de 0–360 (p. ej. -90).
            value: element.rotation % 360,
            min: 0,
            max: 360,
            divisions: 360,
            label: '${(element.rotation % 360).round()}°',
            onChanged: (v) {
              element.rotation = v;
              widget.onUpdate();
            },
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${(element.rotation % 360).round()}°',
            style: AppTypography.caption(palette),
          ),
        ),
        for (final step in const [-15.0, 15.0])
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: step < 0 ? 'Girar −15°' : 'Girar +15°',
            icon: Icon(
              step < 0 ? Icons.rotate_left : Icons.rotate_right,
              size: 18,
            ),
            onPressed: () {
              final turned = ((element.rotation + step) / 15).round() * 15.0;
              element.rotation = (turned % 360 + 360) % 360;
              widget.onUpdate();
            },
          ),
      ],
    ),
    Text(
      'Arrastra el asa o el anillo en el lienzo para girar; '
      'con Mayús, de 15 en 15°',
      style: AppTypography.caption(
        palette,
      ).copyWith(color: palette.textTertiary, fontSize: 10),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final element = widget.element;

    // Un Material, no un fondo de color: los controles con tinta (listas,
    // interruptores) pintan sobre él.
    return Material(
      color: palette.surface,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Propiedades', style: AppTypography.label(palette)),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      element.displayLabel,
                      style: AppTypography.titleMedium(palette),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.scopeNotice,
                        style: AppTypography.caption(palette),
                      ),
                    ),
                    if (widget.moveTargets.isNotEmpty)
                      PopupMenuButton<PlanLayer>(
                        tooltip: 'Mover a otra capa',
                        onSelected: widget.onMove,
                        itemBuilder: (_) => [
                          for (final layer in widget.moveTargets)
                            PopupMenuItem(
                              value: layer,
                              child: Text('Mover a ${layer.label}'),
                            ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Mover a otra capa…',
                            style: AppTypography.caption(
                              palette,
                            ).copyWith(color: palette.accent),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    if (element.type != ElementType.actor) ...[
                      TextField(
                        controller: _nameCtrl,
                        style: AppTypography.bodyLarge(palette),
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Nombre',
                          hintText: element.typeLabel,
                          helperText:
                              'Se ve en la planta, en el 3D y en Unreal.',
                        ),
                        onSubmitted: _commitName,
                        onTapOutside: (_) => _commitName(_nameCtrl.text),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    // Su asset de Unreal (F6.20 B2), para cualquier tipo.
                    UnrealAssetTile(
                      element: element,
                      link: UnrealLink.instance,
                      projectId: widget.projectId,
                      onChanged: () async => widget.onUpdate(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (element.type == ElementType.actor)
                      _section(palette, 'Personaje', 'cast', [
                        TextField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: AppTypography.bodyLarge(palette),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Nombre',
                            hintText: 'ADIL',
                          ),
                          onSubmitted: _commitName,
                          onTapOutside: (_) => _commitName(_nameCtrl.text),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final c in kActorColors)
                              GestureDetector(
                                onTap: () => widget.onRecolourCast?.call(c),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: element.actorColor == c
                                        ? Border.all(
                                            color: palette.textPrimary,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          PlanCast.isNamed(element.label)
                              ? '${element.label!.trim()} lleva este color en '
                                    'todas las plantas del proyecto.'
                              : 'Ponle nombre y su color le seguirá en todas '
                                    'las plantas.',
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(color: palette.textTertiary),
                        ),
                      ]),
                    if (element.type == ElementType.camera)
                      _section(palette, 'Cámara', 'camera-id', [
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final letter in const ['A', 'B', 'C', 'D'])
                              ChoiceChip(
                                visualDensity: VisualDensity.compact,
                                showCheckmark: false,
                                avatar: CircleAvatar(
                                  backgroundColor: cameraColorForLetter(letter),
                                  radius: 6,
                                ),
                                label: Text('Cám. $letter'),
                                selected: element.cameraLetter == letter,
                                onSelected: (_) {
                                  element.cameraLetter = letter;
                                  final body = widget.gear.cameraForLetter(
                                    letter,
                                  );
                                  if (body != null) {
                                    PlanEquipment.applyCamera(element, body);
                                  }
                                  widget.onUpdate();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cada letra tiene su color, el mismo en todas las '
                          'plantas, y coge el cuerpo que lleve esa letra en '
                          'el proyecto.',
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(color: palette.textTertiary),
                        ),
                      ]),
                    if (LightBeam.of(element) case final beam?) ...[
                      _section(palette, 'Aparato', 'fixture', [
                        PlanElementCompatPanel(
                          element: element,
                          onChanged: widget.onUpdate,
                          part: CompatPart.identity,
                        ),
                      ]),
                      _section(palette, 'Luz', 'light', [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Encendida',
                                style: AppTypography.caption(palette),
                              ),
                            ),
                            Switch(
                              value: !beam.off,
                              onChanged: (on) {
                                element.props[LightBeam.offKey] = !on;
                                widget.onUpdate();
                              },
                            ),
                          ],
                        ),
                        _beamSlider(
                          'Intensidad',
                          '${beam.intensity.round()} %',
                          LightBeam.intensityKey,
                          beam.intensity,
                          0,
                          100,
                        ),
                        if (PlanLight.canColor(element))
                          PlanLightColorControl(
                            element: element,
                            onPreview: widget.onPreview,
                            onUpdate: widget.onUpdate,
                          ),
                        if (beam.rgb == null)
                          _beamSlider(
                            'Temperatura de color',
                            '${beam.cct.round()} K',
                            LightBeam.cctKey,
                            beam.cct,
                            1800,
                            10000,
                            step: 100,
                          ),
                        // Lo que suele haber en la calle (CA.5).
                        if (beam.rgb == null && StreetLamp.isOn(element))
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final (name, k) in StreetLamp.kelvinPresets)
                                ChoiceChip(
                                  label: Text('$name · ${k.round()} K'),
                                  selected: (beam.cct - k).abs() < 50,
                                  onSelected: (_) {
                                    element.props[LightBeam.cctKey] = k;
                                    widget.onUpdate();
                                  },
                                ),
                            ],
                          ),
                        if (PlanLight.opticsOf(element) case final optics
                            when optics.focusable)
                          _focusControl(optics, beam.spread)
                        else
                          _beamSlider(
                            'Apertura del haz',
                            '${beam.spread.round()}°',
                            LightBeam.spreadKey,
                            beam.spread,
                            5,
                            360,
                          ),
                        PlanLightControls(
                          element: element,
                          exposure: widget.exposure,
                          onUpdate: widget.onUpdate,
                          parts: const {LightControlPart.power},
                        ),
                      ]),
                      _section(palette, 'Montaje', 'mount', [
                        PlanLightControls(
                          element: element,
                          exposure: widget.exposure,
                          onUpdate: widget.onUpdate,
                          parts: const {LightControlPart.mount},
                        ),
                        ..._rotationControls(palette, element),
                      ]),
                      _section(palette, 'Filtros y difusión', 'filters', [
                        PlanLightControls(
                          element: element,
                          exposure: widget.exposure,
                          onUpdate: widget.onUpdate,
                          parts: const {LightControlPart.filters},
                        ),
                      ]),
                      _section(palette, 'Dato del fabricante', 'data', [
                        PlanLightControls(
                          element: element,
                          exposure: widget.exposure,
                          onUpdate: widget.onUpdate,
                          parts: const {LightControlPart.data},
                        ),
                      ]),
                    ],
                    if (widget.canOverride)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              element.shotOverride
                                  ? 'Ajustada solo en este plano'
                                  : 'Ajustar solo en este plano',
                              style: AppTypography.caption(palette),
                            ),
                          ),
                          Switch(
                            value: element.shotOverride,
                            onChanged: widget.onOverride,
                          ),
                        ],
                      ),
                    if (element.type == ElementType.camera &&
                        widget.onLinkShots != null) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.link, size: 16),
                        label: Text(
                          widget.linkedShots == 0
                              ? 'Vincular a planos…'
                              : 'Vinculada a ${widget.linkedShots} '
                                    'plano${widget.linkedShots == 1 ? '' : 's'}',
                        ),
                        onPressed: widget.onLinkShots,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (element.type == ElementType.camera)
                      PlanProjectCameraPicker(
                        gear: widget.gear,
                        camera: element,
                        onManage: widget.onManageGear,
                        onCamera: (camera) {
                          PlanEquipment.applyCamera(element, camera);
                          widget.onUpdate();
                        },
                        onLens: (lens) {
                          PlanEquipment.applyLens(element, lens);
                          _lensCtrl.text = element.lens ?? '';
                          widget.onUpdate();
                        },
                        onFocal: (focal) {
                          PlanEquipment.setFocal(element, focal);
                          _lensCtrl.text = element.lens ?? '';
                          widget.onUpdate();
                        },
                      ),
                    if (widget.reading != null)
                      PlanMeterPanel(
                        reading: widget.reading!,
                        exposure: widget.exposure,
                      ),
                    if (element.type == ElementType.camera)
                      PlanCameraExposureControls(
                        camera: element,
                        fallback: widget.exposure,
                        fallbackStop: widget.targetStop,
                        onUpdate: widget.onUpdate,
                      ),
                    if (PlanPieceControls.appliesTo(element))
                      PlanPieceControls(
                        element: element,
                        metersPerUnit: widget.metersPerUnit,
                        onPreview: widget.onPreview,
                        onUpdate: widget.onUpdate,
                        onAddElements: widget.onAddElements,
                      ),
                    if (widget.lengthLabel != null)
                      Text(
                        'Longitud: ${widget.lengthLabel}',
                        style: AppTypography.bodyMedium(palette),
                      )
                    else ...[
                      if (LightBeam.of(element) == null)
                        ..._rotationControls(palette, element),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    if (element.type == ElementType.camera) ...[
                      Text('Lente', style: AppTypography.caption(palette)),
                      TextField(
                        controller: _lensCtrl,
                        style: AppTypography.bodyLarge(palette),
                        decoration: const InputDecoration(hintText: '50mm'),
                        onSubmitted: _commitLens,
                        onEditingComplete: () => _commitLens(_lensCtrl.text),
                      ),
                      // El movimiento con las palabras del guion técnico:
                      // lo que se elige aquí va también al plano (SG.4).
                      const SizedBox(height: AppSpacing.sm),
                      Text('Movimiento', style: AppTypography.caption(palette)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final m in {
                            ...CameraShotSync.movements,
                            if (element.stabilization?.trim().isNotEmpty ==
                                true)
                              element.stabilization!.trim().toUpperCase(),
                          })
                            ChoiceChip(
                              label: Text(m),
                              visualDensity: VisualDensity.compact,
                              selected:
                                  element.stabilization?.trim().toUpperCase() ==
                                  m,
                              onSelected: (_) {
                                element.stabilization = m;
                                widget.onUpdate();
                              },
                            ),
                        ],
                      ),
                    ],
                    if (PlanMarks.supports(element))
                      _section(palette, 'Posiciones', 'marks', [
                        Text(
                          element.pathPoints.isEmpty
                              ? 'Una sola posición'
                              : '${element.pathPoints.length + 1} posiciones',
                          style: AppTypography.caption(palette).copyWith(
                            color: palette.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        if (widget.selectedPathIndex != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Posición ${widget.selectedPathIndex! + 2} seleccionada: '
                              'arrástrala o gírala con su asa',
                              style: AppTypography.caption(
                                palette,
                              ).copyWith(color: palette.accent, fontSize: 10),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: widget.onAddPathPoint,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Posición'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: widget.selectedPathIndex != null
                                    ? widget.onDeletePathPoint
                                    : null,
                                icon: Icon(
                                  Icons.remove,
                                  size: 16,
                                  color: palette.error,
                                ),
                                label: Text(
                                  'Quitar',
                                  style: TextStyle(color: palette.error),
                                ),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (element.pathPoints.isNotEmpty)
                          TextButton(
                            onPressed: widget.onClearPath,
                            child: Text(
                              'Dejar una sola posición',
                              style: AppTypography.caption(
                                palette,
                              ).copyWith(color: palette.textSecondary),
                            ),
                          ),
                        Text(
                          'Doble toque en el lienzo para añadir una posición. Cada '
                          'una se arrastra y se gira por separado: en la de una '
                          'cámara se ve qué encuadra desde allí.',
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(color: palette.textTertiary, fontSize: 10),
                        ),
                      ]),
                    if (element.type == ElementType.camera ||
                        element.type == ElementType.light ||
                        element.type == ElementType.prop ||
                        element.type == ElementType.wall ||
                        element.type == ElementType.actor) ...[
                      _section(palette, 'Exportar a 3D', 'export', [
                        Text(
                          'Enlace con ARRI Luka y Cine Tracer. Se rellena '
                          'solo al elegir un modelo de Equipo.',
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(color: palette.textTertiary),
                        ),
                        const SizedBox(height: 6),
                        PlanElementCompatPanel(
                          element: element,
                          onChanged: widget.onUpdate,
                          part:
                              element.type == ElementType.light &&
                                  LightBeam.of(element) != null
                              ? CompatPart.export
                              : CompatPart.all,
                        ),
                      ], open: false),
                    ],
                  ],
                ),
              ),
            ),
            if (widget.selectionCount > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${widget.selectionCount} elementos seleccionados: duplicar '
                  'y eliminar se aplican a todos.',
                  style: AppTypography.caption(palette),
                ),
              ),
            GestureDetector(
              onTap: widget.onDuplicate,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.copy_outlined, color: palette.accent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Duplicar',
                      style: AppTypography.bodyMedium(
                        palette,
                      ).copyWith(color: palette.accent),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: widget.onDelete,
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: palette.error, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Eliminar',
                    style: AppTypography.bodyMedium(
                      palette,
                    ).copyWith(color: palette.error),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una planta que edita otro equipo: un aviso arriba y sin poder tocarla
/// aquí hasta que termine.
class _LiveLock extends StatelessWidget {
  final String? device;
  final Widget child;

  const _LiveLock({required this.device, required this.child});

  @override
  Widget build(BuildContext context) {
    final who = device;
    if (who == null) return child;
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: const Color(0xFF7F77DD).withValues(alpha: 0.18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18, color: Color(0xFF7F77DD)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lo está editando $who. Podrás editar en cuanto termine; '
                    'verás sus cambios al momento.',
                    style: AppTypography.bodyMedium(palette),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ExcludeFocus(child: AbsorbPointer(child: child)),
        ),
      ],
    );
  }
}
