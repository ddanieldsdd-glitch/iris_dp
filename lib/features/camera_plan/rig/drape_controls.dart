import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../camera_plan_element_model.dart';
import 'catenary.dart';
import 'plan_drape.dart';
import 'rig_painter.dart';

/// Propiedades de una pared de tela: material, amarres, flecha, largo y
/// frunce. Se mueve la flecha; el largo de cuerda y la tensión se leen. Un
/// alzado pequeño enseña la curva y la altura libre.
class DrapeControls extends StatelessWidget {
  final PlanElement element;
  final double metersPerUnit;

  /// Repinta sin guardar (mientras se arrastra un control).
  final VoidCallback onPreview;

  /// Guarda el cambio.
  final VoidCallback onUpdate;

  const DrapeControls({
    super.key,
    required this.element,
    required this.metersPerUnit,
    required this.onPreview,
    required this.onUpdate,
  });

  /// Tiro en un amarre a partir del que conviene avisar, en kg.
  static const double heavyPullKg = 150;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final el = element;
    final c = PlanDrape.catenary(el, metersPerUnit);
    final (a, b) = PlanDrape.anchors(el);
    final material = PlanDrape.material(el);
    final load = PlanDrape.loadPerMeterKg(el, c);
    final pull = c.anchorTension(load);
    final clearance = PlanDrape.clearanceM(el, c);

    Widget slider(
      String label,
      String value, {
      required double current,
      required double min,
      required double max,
      required double step,
      required ValueChanged<double> onChanged,
    }) => Column(
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
            onChanged((v / step).round() * step);
            onPreview();
          },
          onChangeEnd: (_) => onUpdate(),
        ),
      ],
    );

    void setAnchors(double first, double second) =>
        el.props[PlanDrape.anchorsKey] = [first, second];

    String m(double v) => '${v.toStringAsFixed(2)} m';
    String kg(double v) =>
        v.isFinite ? '${v.toStringAsFixed(0)} kg' : 'sin caída';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tela', style: AppTypography.caption(palette)),
        DropdownButton<String>(
          value: material.id,
          isExpanded: true,
          items: [
            for (final mat in kDrapeMaterials)
              DropdownMenuItem(
                value: mat.id,
                child: Text(
                  '${mat.name} · ${mat.gsm.round()} g/m²',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (id) {
            el.props[PlanDrape.materialKey] = id;
            el.props.remove(PlanDrape.colorKey);
            onUpdate();
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 120,
          child: CustomPaint(
            painter: _ElevationPainter(el, metersPerUnit),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        slider(
          'Amarre de inicio',
          m(a),
          current: a,
          min: 0.5,
          max: 12,
          step: 0.05,
          onChanged: (v) => setAnchors(v, b),
        ),
        slider(
          'Amarre final',
          m(b),
          current: b,
          min: 0.5,
          max: 12,
          step: 0.05,
          onChanged: (v) => setAnchors(a, v),
        ),
        slider(
          'Flecha en el centro',
          m(c.sag),
          current: c.sag,
          min: 0,
          max: math.max(0.1, math.min(3, c.span / 2)),
          step: 0.01,
          onChanged: (v) => PlanDrape.setSag(el, v),
        ),
        slider(
          'Largo de la tela',
          m(PlanDrape.lengthM(el)),
          current: PlanDrape.lengthM(el),
          min: 0.3,
          max: 12,
          step: 0.05,
          onChanged: (v) => el.props[PlanDrape.lengthKey] = v,
        ),
        slider(
          'Frunce',
          '${(PlanDrape.fullness(el) * 100).round()} %',
          current: PlanDrape.fullness(el),
          min: 0,
          max: 2,
          step: 0.25,
          onChanged: (v) => el.props[PlanDrape.fullnessKey] = v,
        ),
        _Readout(
          palette: palette,
          rows: [
            ('Luz', m(c.span)),
            ('Cuerda', m(c.rope)),
            ('Tela', '${PlanDrape.areaM2(el, c).toStringAsFixed(1)} m²'),
            ('Peso', '${PlanDrape.weightKg(el, c).toStringAsFixed(1)} kg'),
            ('Tensión horizontal', kg(c.horizontalTension(load))),
            ('Tiro en cada amarre', kg(pull)),
            (
              clearance > 0 ? 'Altura libre' : 'Arrastra',
              clearance > 0 ? m(clearance) : m(PlanDrape.poolM(el, c)),
            ),
          ],
          warnRow: pull > heavyPullKg ? 5 : null,
        ),
        if (pull > heavyPullKg)
          Text(
            'Con tan poca flecha la cuerda tira mucho: dale más caída o '
            'pon un amarre en medio.',
            style: AppTypography.caption(
              palette,
            ).copyWith(color: palette.warning),
          ),
        Text(
          material.transmission > 0.3
              ? 'Deja pasar parte de la luz.'
              : 'Tapa la luz como una pared.',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textTertiary),
        ),
      ],
    );
  }
}

class _Readout extends StatelessWidget {
  final AppPalette palette;
  final List<(String, String)> rows;
  final int? warnRow;

  const _Readout({required this.palette, required this.rows, this.warnRow});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Column(
      children: [
        for (final (i, (label, value)) in rows.indexed)
          Row(
            children: [
              Expanded(
                child: Text(label, style: AppTypography.caption(palette)),
              ),
              Text(
                value,
                style: AppTypography.mono(
                  palette,
                ).copyWith(color: i == warnRow ? palette.warning : null),
              ),
            ],
          ),
      ],
    ),
  );
}

/// Alzado de la tela: la cuerda recta de referencia, la catenaria, el bajo
/// y una persona de 1,75 m para la escala.
class _ElevationPainter extends CustomPainter {
  final PlanElement el;
  final double mpu;

  _ElevationPainter(this.el, this.mpu);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFBFBF9),
    );
    final Catenary c = PlanDrape.catenary(el, mpu);
    final (a, b) = PlanDrape.anchors(el);
    final top = math.max(a, b) + 0.4;
    final spanDraw = c.span + 2.2;
    final k = math.min((size.width - 16) / spanDraw, (size.height - 12) / top);
    final x0 = (size.width - c.span * k) / 2;
    final floor = size.height - 6;
    Offset p(double t, double z) => Offset(x0 + t * c.span * k, floor - z * k);

    final ink = Paint()
      ..color = RigPainter.ink
      ..strokeWidth = 1;
    canvas.drawLine(Offset(4, floor), Offset(size.width - 4, floor), ink);
    // Cuerda recta, como referencia.
    canvas.drawLine(
      p(0, a),
      p(1, b),
      Paint()
        ..color = RigPainter.ink.withValues(alpha: 0.3)
        ..strokeWidth = 1,
    );
    const n = 48;
    final cloth = Path()..moveTo(p(0, a).dx, p(0, a).dy);
    final edge = Path()..moveTo(p(0, a).dx, p(0, a).dy);
    for (var i = 1; i <= n; i++) {
      final q = p(i / n, PlanDrape.topAt(el, i / n, c));
      cloth.lineTo(q.dx, q.dy);
      edge.lineTo(q.dx, q.dy);
    }
    for (var i = n; i >= 0; i--) {
      final q = p(i / n, PlanDrape.bottomAt(el, i / n, c));
      cloth.lineTo(q.dx, q.dy);
    }
    cloth.close();
    canvas
      ..drawPath(
        cloth,
        Paint()..color = PlanDrape.color(el).withValues(alpha: 0.85),
      )
      ..drawPath(
        cloth,
        Paint()
          ..color = RigPainter.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      )
      ..drawPath(
        edge,
        Paint()
          ..color = RigPainter.rigColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    // Amarres.
    for (final (t, z) in [(0.0, a), (1.0, b)]) {
      canvas
        ..drawLine(p(t, 0), p(t, z), ink..strokeWidth = 3)
        ..drawCircle(p(t, z), 3, Paint()..color = Colors.white)
        ..drawCircle(
          p(t, z),
          3,
          Paint()
            ..color = RigPainter.ink
            ..style = PaintingStyle.stroke,
        );
    }
    // Persona, al lado del primer amarre.
    final feet = p(0, 0) - Offset(0.7 * k, 0);
    final person = Paint()
      ..color = RigPainter.ink
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas
      ..drawCircle(feet - Offset(0, 1.62 * k), 0.12 * k, person)
      ..drawLine(feet - Offset(0, 1.5 * k), feet - Offset(0, 0.85 * k), person)
      ..drawLine(
        feet - Offset(0, 0.85 * k),
        feet + Offset(-0.18 * k, 0),
        person,
      )
      ..drawLine(
        feet - Offset(0, 0.85 * k),
        feet + Offset(0.18 * k, 0),
        person,
      );
  }

  @override
  bool shouldRepaint(_ElevationPainter old) => true;
}
