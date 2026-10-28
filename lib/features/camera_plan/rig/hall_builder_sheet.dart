import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../camera_plan_element_model.dart';
import '../plan_opening.dart';
import '../plan_segment.dart';
import 'plan_hall.dart';
import 'plan_rig.dart';
import 'rig_painter.dart';

/// Constructor rápido de nave: medidas, cubierta, pilares y rejilla de
/// truss, con la planta que va a salir a la vista. Devuelve la receta.
///
/// Empieza por un rectángulo (o por las paredes seleccionadas); cada lado
/// se puede curvar, partir o cambiar de tipo (pared, ventanal, abierto,
/// bambalinas). Después, en la planta, mover una pared de la nave mueve su
/// perímetro.
class HallBuilderSheet extends StatefulWidget {
  final HallRecipe initial;

  /// `true` si se edita una nave que ya existe.
  final bool editing;

  /// `true` si el perímetro sale de paredes dibujadas: no es un rectángulo.
  final bool freeOutline;

  const HallBuilderSheet({
    super.key,
    required this.initial,
    this.editing = false,
    this.freeOutline = false,
  });

  static Future<HallRecipe?> show(
    BuildContext context, {
    HallRecipe? initial,
    bool editing = false,
    bool freeOutline = false,
  }) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final sheet = HallBuilderSheet(
      initial: initial ?? HallRecipe.rectangle(),
      editing: editing,
      freeOutline: freeOutline,
    );
    if (wide) {
      return showDialog<HallRecipe>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(width: 1080, height: 720, child: sheet),
        ),
      );
    }
    return Navigator.of(context).push<HallRecipe>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => sheet),
    );
  }

  @override
  State<HallBuilderSheet> createState() => _HallBuilderSheetState();
}

class _HallBuilderSheetState extends State<HallBuilderSheet> {
  late HallRecipe _r = widget.initial;
  late bool _rectangle = !widget.freeOutline && _isRectangle(widget.initial);

  static bool _isRectangle(HallRecipe r) {
    if (r.outline.length != 4) return false;
    final o = r.outline;
    return (o[0].dx - o[3].dx).abs() < 1e-6 &&
        (o[1].dx - o[2].dx).abs() < 1e-6 &&
        (o[0].dy - o[1].dy).abs() < 1e-6 &&
        (o[2].dy - o[3].dy).abs() < 1e-6;
  }

  double get _width => _r.outline[1].dx - _r.outline[0].dx;
  double get _depth => _r.outline[0].dy - _r.outline[3].dy;

  void _set(HallRecipe r) => setState(() => _r = r);

  void _setSize({double? width, double? depth}) {
    final w = width ?? _width, d = depth ?? _depth;
    _set(
      _r.copyWith(
        outline: [Offset(0, d), Offset(w, d), Offset(w, 0), Offset.zero],
        ridgeDeg: w >= d ? 0 : 90,
      ),
    );
  }

  void _setEdge(int i, HallEdge edge) {
    final edges = [
      for (var k = 0; k < _r.outline.length; k++) k == i ? edge : _r.edge(k),
    ];
    _set(_r.copyWith(edges: edges));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final preview = _Preview(recipe: _r);
    final form = _form(palette);
    final actions = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _summary(),
              style: AppTypography.caption(palette),
              maxLines: 2,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_r),
            child: Text(widget.editing ? 'Rehacer la nave' : 'Crear la nave'),
          ),
        ],
      ),
    );
    final body = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: preview),
              VerticalDivider(width: 1, color: palette.divider),
              SizedBox(width: 380, child: form),
            ],
          )
        : Column(
            children: [
              SizedBox(height: 260, child: preview),
              Divider(height: 1, color: palette.divider),
              Expanded(child: form),
            ],
          );
    return Material(
      color: palette.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.editing ? 'Editar la nave' : 'Nave nueva',
                    style: AppTypography.titleMedium(palette),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.divider),
          Expanded(child: body),
          Divider(height: 1, color: palette.divider),
          actions,
        ],
      ),
    );
  }

  String _summary() {
    final built = PlanHall.build(
      PlanHall.create(Offset.zero, _r),
      defaultMetersPerUnit,
    );
    int count(bool Function(PlanElement) test) => built.where(test).length;
    var trussM = 0.0;
    for (final t in built.where(PlanTruss.isTruss)) {
      trussM += PlanTruss.length(t) * defaultMetersPerUnit;
    }
    final motors = count((e) => RigTypeCodec.of(e) == RigType.motor);
    final towers = count((e) => RigTypeCodec.of(e) == RigType.groundSupport);
    return [
      '${count(PlanPillar.isPillar)} pilares',
      if (count(PlanOpening.isWindow) > 0)
        '${count(PlanOpening.isWindow)} módulos de vidrio',
      if (trussM > 0) '${trussM.toStringAsFixed(1)} m de truss',
      if (motors > 0) '$motors motores',
      if (towers > 0) '$towers ground support',
    ].join(' · ');
  }

  Widget _form(AppPalette palette) {
    String m(double v) => '${v.toStringAsFixed(v < 10 ? 2 : 1)} m';
    final r = _r;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (!widget.editing && !widget.freeOutline) ...[
          _Header('Empezar de', palette),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (name, hint, recipe) in HallTemplates.all)
                Tooltip(
                  message: hint,
                  child: ActionChip(
                    label: Text(name),
                    onPressed: () => setState(() {
                      _r = recipe;
                      _rectangle = _isRectangle(recipe);
                    }),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _Header('Forma', palette),
        if (_rectangle) ...[
          _SliderRow(
            label: 'Ancho (frente)',
            value: _width,
            min: 4,
            max: 60,
            step: 0.5,
            text: m(_width),
            onChanged: (v) => _setSize(width: v),
          ),
          _SliderRow(
            label: 'Fondo',
            value: _depth,
            min: 4,
            max: 40,
            step: 0.5,
            text: m(_depth),
            onChanged: (v) => _setSize(depth: v),
          ),
        ] else
          Text(
            'Perímetro libre de ${r.outline.length} esquinas. Muévelo luego '
            'en la planta: cada pared de la nave arrastra su lado.',
            style: AppTypography.caption(palette),
          ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < r.outline.length; i++) _edgeTile(i, palette),
        const SizedBox(height: AppSpacing.md),
        _Header('Altura y cubierta', palette),
        _SliderRow(
          label: 'Altura al alero',
          value: r.eaveM,
          min: 2.5,
          max: 12,
          step: 0.1,
          text: m(r.eaveM),
          onChanged: (v) => _set(r.copyWith(eaveM: v)),
        ),
        SegmentedButton<HallRoof>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            for (final roof in HallRoof.values)
              ButtonSegment(value: roof, label: Text(roof.label)),
          ],
          selected: {r.roof},
          onSelectionChanged: (v) => _set(
            r.copyWith(
              roof: v.first,
              pillarShape: v.first == HallRoof.tensile
                  ? PlanPillar.round
                  : PlanPillar.square,
              pillarSizeM: v.first == HallRoof.tensile ? 0.12 : 0.2,
            ),
          ),
        ),
        if (r.roof != HallRoof.flat) ...[
          _SliderRow(
            label: 'Cumbrera sobre el alero',
            value: r.riseM,
            min: 0.3,
            max: 6,
            step: 0.1,
            text: m(r.riseM),
            onChanged: (v) => _set(r.copyWith(riseM: v)),
          ),
          Row(
            children: [
              Expanded(
                child: Text('Cumbrera', style: AppTypography.caption(palette)),
              ),
              SegmentedButton<double>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: 0, label: Text('A lo ancho')),
                  ButtonSegment(value: 90, label: Text('A lo hondo')),
                ],
                selected: {r.ridgeDeg.abs() % 180 < 45 ? 0 : 90},
                onSelectionChanged: (v) => _set(r.copyWith(ridgeDeg: v.first)),
              ),
            ],
          ),
        ],
        if (r.roof == HallRoof.tensile)
          _SliderRow(
            label: 'Caída de la lona entre cerchas',
            value: r.sagM,
            min: 0,
            max: 1,
            step: 0.05,
            text: m(r.sagM),
            onChanged: (v) => _set(r.copyWith(sagM: v)),
          ),
        _SliderRow(
          label: 'Cota del suelo (entreplanta, tarima)',
          value: r.levelM,
          min: 0,
          max: 10,
          step: 0.1,
          text: m(r.levelM),
          onChanged: (v) => _set(r.copyWith(levelM: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        _Header('Pilares', palette),
        _SliderRow(
          label: 'Separación en el perímetro',
          value: r.pillarSpacingM,
          min: 2,
          max: 15,
          step: 0.5,
          text: m(r.pillarSpacingM),
          onChanged: (v) => _set(r.copyWith(pillarSpacingM: v)),
        ),
        Row(
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: PlanPillar.round, label: Text('Redondos')),
                ButtonSegment(
                  value: PlanPillar.square,
                  label: Text('Cuadrados'),
                ),
              ],
              selected: {r.pillarShape},
              onSelectionChanged: (v) => _set(r.copyWith(pillarShape: v.first)),
            ),
            const Spacer(),
            Text(
              '${(r.pillarSizeM * 100).round()} cm',
              style: AppTypography.caption(palette),
            ),
          ],
        ),
        _SliderRow(
          label: 'Grosor',
          value: r.pillarSizeM,
          min: 0.08,
          max: 1,
          step: 0.01,
          text: '${(r.pillarSizeM * 100).round()} cm',
          onChanged: (v) => _set(r.copyWith(pillarSizeM: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Pilares dentro de la nave'),
          subtitle: const Text('Tapan la luz como una columna de verdad.'),
          value: r.interiorPillarsM > 0,
          onChanged: (v) => _set(r.copyWith(interiorPillarsM: v ? 6 : 0)),
        ),
        if (r.interiorPillarsM > 0)
          _SliderRow(
            label: 'Cuadrícula de pilares dentro',
            value: r.interiorPillarsM,
            min: 3,
            max: 15,
            step: 0.5,
            text: m(r.interiorPillarsM),
            onChanged: (v) => _set(r.copyWith(interiorPillarsM: v)),
          ),
        const SizedBox(height: AppSpacing.md),
        _Header('Rejilla de truss', palette),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Rejilla automática'),
          subtitle: Text(
            r.roof == HallRoof.tensile
                ? 'La lona no carga: va sobre ground support.'
                : 'Los motores cuelgan de las cerchas, en la línea de pilares.',
          ),
          value: r.grid,
          onChanged: (v) => _set(r.copyWith(grid: v)),
        ),
        if (r.grid) ...[
          _SliderRow(
            label: 'Separación entre líneas',
            value: r.gridSpacingM,
            min: 1.5,
            max: 8,
            step: 0.25,
            text: m(r.gridSpacingM),
            onChanged: (v) => _set(r.copyWith(gridSpacingM: v)),
          ),
          _SliderRow(
            label: 'Cuerda inferior',
            value: math.min(r.gridLowM, r.eaveM),
            min: 2,
            max: math.max(2.1, r.eaveM),
            step: 0.1,
            text: m(r.gridLowM),
            onChanged: (v) => _set(r.copyWith(gridLowM: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Rejilla cruzada'),
            subtitle: const Text(
              'Travesaños también por dentro, no solo en '
              'los extremos.',
            ),
            value: r.gridCross,
            onChanged: (v) => _set(r.copyWith(gridCross: v)),
          ),
          _SliderRow(
            label: 'Distancia a las paredes',
            value: r.gridMarginM,
            min: 0.3,
            max: 4,
            step: 0.1,
            text: m(r.gridMarginM),
            onChanged: (v) => _set(r.copyWith(gridMarginM: v)),
          ),
          Row(
            children: [
              SegmentedButton<TrussProfile>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(
                    value: TrussProfile.square,
                    label: Text('Cuadrado'),
                  ),
                  ButtonSegment(
                    value: TrussProfile.triangle,
                    label: Text('Triangular'),
                  ),
                ],
                selected: {r.gridProfile},
                onSelectionChanged: (v) =>
                    _set(r.copyWith(gridProfile: v.first)),
              ),
              const SizedBox(width: AppSpacing.sm),
              SegmentedButton<int>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: 30, label: Text('30')),
                  ButtonSegment(value: 40, label: Text('40')),
                ],
                selected: {r.gridSizeCm},
                onSelectionChanged: (v) =>
                    _set(r.copyWith(gridSizeCm: v.first)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Un lado: su tipo, su curva y, según el tipo, alféizar o largo de tela.
  Widget _edgeTile(int i, AppPalette palette) {
    final edge = _r.edge(i);
    final a = _r.outline[i], b = _r.outline[(i + 1) % _r.outline.length];
    final chord = (b - a).distance;
    final name = _rectangle
        ? const ['Frente', 'Lateral derecho', 'Fondo', 'Lateral izquierdo'][i]
        : 'Lado ${i + 1}';
    String m(double v) => '${v.toStringAsFixed(2)} m';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$name · ${chord.toStringAsFixed(1)} m',
                  style: AppTypography.bodyMedium(palette),
                ),
              ),
              DropdownButton<HallEdgeKind>(
                value: edge.kind,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [
                  for (final k in HallEdgeKind.values)
                    DropdownMenuItem(value: k, child: Text(k.label)),
                ],
                onChanged: (k) => _setEdge(i, edge.copyWith(kind: k)),
              ),
              PopupMenuButton<String>(
                tooltip: 'Más',
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) => setState(() {
                  _rectangle = false;
                  _r = v == 'split' ? _r.splitEdge(i) : _r.removeVertex(i);
                }),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'split',
                    child: Text('Partir en dos (una esquina más)'),
                  ),
                  if (_r.outline.length > 3)
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Quitar la esquina de inicio'),
                    ),
                ],
              ),
            ],
          ),
          _SliderRow(
            label: 'Curva',
            value: edge.bulgeM,
            min: -chord / 2,
            max: chord / 2,
            step: 0.1,
            text: edge.bulgeM == 0 ? 'recto' : m(edge.bulgeM.abs()),
            onChanged: (v) {
              // Un rectángulo con un lado curvo sigue siendo editable con
              // ancho y fondo: la curva va aparte.
              _setEdge(i, edge.copyWith(bulgeM: v.abs() < 0.1 ? 0 : v));
            },
          ),
          if (edge.kind == HallEdgeKind.glass) ...[
            _SliderRow(
              label: 'Alféizar',
              value: edge.sillM,
              min: 0,
              max: math.max(0.1, _r.eaveM - 0.5),
              step: 0.05,
              text: m(edge.sillM),
              onChanged: (v) => _setEdge(i, edge.copyWith(sillM: v)),
            ),
            _SliderRow(
              label: 'Módulo de vidrio',
              value: edge.moduleM,
              min: 0.6,
              max: 4,
              step: 0.1,
              text: m(edge.moduleM),
              onChanged: (v) => _setEdge(i, edge.copyWith(moduleM: v)),
            ),
          ],
          if (edge.kind == HallEdgeKind.drape)
            _SliderRow(
              label: 'Largo de la bambalina',
              value: edge.drapeLengthM,
              min: 0.3,
              max: math.max(0.4, _r.eaveM),
              step: 0.05,
              text: m(edge.drapeLengthM),
              onChanged: (v) => _setEdge(i, edge.copyWith(drapeLengthM: v)),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  final AppPalette palette;

  const _Header(this.text, this.palette);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(text.toUpperCase(), style: AppTypography.label(palette)),
  );
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String text;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.text,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final divisions = math.max(1, ((max - min) / step).round());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.caption(palette))),
            Text(text, style: AppTypography.mono(palette)),
          ],
        ),
        SizedBox(
          height: 32,
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (v) => onChanged((v / step).round() * step),
          ),
        ),
      ],
    );
  }
}

/// La planta que va a salir, encajada en el recuadro.
class _Preview extends StatelessWidget {
  final HallRecipe recipe;

  const _Preview({required this.recipe});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFFBFBF9),
    child: CustomPaint(
      painter: _PreviewPainter(recipe),
      child: const SizedBox.expand(),
    ),
  );
}

class _PreviewPainter extends CustomPainter {
  final HallRecipe recipe;

  _PreviewPainter(this.recipe);

  static const mpu = defaultMetersPerUnit;

  @override
  void paint(Canvas canvas, Size size) {
    final hall = PlanHall.create(Offset.zero, recipe);
    final built = PlanHall.build(hall, mpu);
    final poly = recipe.polygon();
    var lo = const Offset(double.infinity, double.infinity);
    var hi = const Offset(-double.infinity, -double.infinity);
    for (final p in poly) {
      lo = Offset(math.min(lo.dx, p.dx), math.min(lo.dy, p.dy));
      hi = Offset(math.max(hi.dx, p.dx), math.max(hi.dy, p.dy));
    }
    final spanM = hi - lo;
    const pad = 40.0;
    final scale = math.min(
      (size.width - pad * 2) / math.max(spanM.dx / mpu, 1),
      (size.height - pad * 2) / math.max(spanM.dy / mpu, 1),
    );
    canvas
      ..save()
      ..translate(
        (size.width - spanM.dx / mpu * scale) / 2,
        (size.height - spanM.dy / mpu * scale) / 2,
      )
      ..scale(scale)
      ..translate(-lo.dx / mpu, -lo.dy / mpu);

    // Los tramos que aún no se dibujan aparte: paredes y vidrio.
    final wall = Paint()
      ..color = RigPainter.ink
      ..strokeWidth = 0.15 / mpu
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final glass = Paint()
      ..color = const Color(0xFF7FB6D6)
      ..strokeWidth = 0.1 / mpu;
    for (final el in built) {
      if (PlanSegment.isSegment(el) &&
          PlanSegment.kind(el) == PlanSegment.kindWall) {
        canvas.drawPath(PlanSegment.path(el), wall);
      }
    }
    for (final el in built) {
      if (PlanOpening.isWindow(el)) {
        final (a, b) = PlanOpening.span(el);
        canvas
          ..drawLine(a, b, glass)
          ..drawLine(
            a,
            b,
            Paint()
              ..color = Colors.white
              ..strokeWidth = 0.03 / mpu,
          );
      }
    }
    RigPainter.drawHall(canvas, hall, mpu);
    for (final el in built) {
      if (PlanTruss.isTruss(el)) RigPainter.paint(canvas, el, mpu);
    }
    for (final el in built) {
      if (!PlanTruss.isTruss(el)) RigPainter.paint(canvas, el, mpu);
    }
    canvas.restore();

    // Medidas del recuadro.
    final tp = TextPainter(
      text: TextSpan(
        text:
            '${spanM.dx.toStringAsFixed(1)} × ${spanM.dy.toStringAsFixed(1)} m'
            '  ·  alero ${recipe.eaveM.toStringAsFixed(2)} m'
            '${recipe.roof == HallRoof.flat ? '' : '  ·  cumbrera ${(recipe.eaveM + recipe.riseM).toStringAsFixed(2)} m'}',
        style: const TextStyle(
          color: RigPainter.ink,
          fontSize: 12,
          fontFamily: 'JetBrains Mono',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(12, size.height - tp.height - 10));
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.recipe != recipe;
}

/// Lo que el editor necesita para meter una nave en la planta.
extension HallElements on HallRecipe {
  /// La receta en la planta: el elemento receta con su origen y todo lo que
  /// genera.
  List<PlanElement> place(Offset origin, double metersPerUnit) {
    final hall = PlanHall.create(origin, this);
    return [hall, ...PlanHall.build(hall, metersPerUnit)];
  }
}
