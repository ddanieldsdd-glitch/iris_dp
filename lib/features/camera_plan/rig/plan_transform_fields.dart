import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../camera_plan_element_model.dart';
import 'plan_transform.dart';

/// «Transformar», como el panel de detalles de Unreal: posición, giro y
/// alturas con números y pasos finos. Cada cambio se guarda al momento.
class PlanTransformFields extends StatelessWidget {
  final PlanElement element;
  final List<PlanElement> elements;
  final double metersPerUnit;

  /// Guarda el elemento y repinta.
  final VoidCallback onUpdate;

  const PlanTransformFields({
    super.key,
    required this.element,
    required this.elements,
    required this.metersPerUnit,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final el = element;
    final at = PlanTransform.xyM(el, metersPerUnit);
    void apply(void Function() change) {
      change();
      onUpdate();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transformar',
            style: AppTypography.caption(
              palette,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          _NumberRow(
            key: ValueKey('x$el${at.x}'),
            label: 'X',
            unit: 'm',
            value: at.x,
            step: 0.1,
            onSet: (v) => apply(
              () => PlanTransform.setXY(el, v, at.y, elements, metersPerUnit),
            ),
          ),
          _NumberRow(
            key: ValueKey('y$el${at.y}'),
            label: 'Y',
            unit: 'm',
            value: at.y,
            step: 0.1,
            onSet: (v) => apply(
              () => PlanTransform.setXY(el, at.x, v, elements, metersPerUnit),
            ),
          ),
          if (PlanTransform.canRotate(el))
            _NumberRow(
              key: ValueKey('r$el${el.rotation}'),
              label: 'Giro',
              unit: '°',
              value: PlanTransform.rotationDeg(el),
              step: 15,
              decimals: 1,
              onSet: (v) => apply(() => PlanTransform.setRotation(el, v)),
            ),
          if (PlanTransform.hasHeight(el))
            _NumberRow(
              key: ValueKey('h$el${PlanTransform.heightM(el)}'),
              label: 'Altura',
              unit: 'm',
              value: PlanTransform.heightM(el),
              step: 0.1,
              min: 0,
              onSet: (v) => apply(() => PlanTransform.setHeight(el, v)),
            ),
          _NumberRow(
            key: ValueKey('z$el${PlanTransform.levelM(el)}'),
            label: 'Cota',
            unit: 'm',
            value: PlanTransform.levelM(el),
            step: 0.1,
            onSet: (v) => apply(() => PlanTransform.setLevel(el, v)),
          ),
          Text(
            'En el 3D: arrastra para moverlo, el aro azul lo gira y la '
            'flecha verde lo sube o lo baja.',
            style: AppTypography.caption(
              palette,
            ).copyWith(color: palette.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Una fila «X  [−] 3,25 m [+]». Admite coma o punto.
class _NumberRow extends StatefulWidget {
  final String label;
  final String unit;
  final double value;
  final double step;
  final int decimals;
  final double? min;
  final ValueChanged<double> onSet;

  const _NumberRow({
    super.key,
    required this.label,
    required this.unit,
    required this.value,
    required this.step,
    required this.onSet,
    this.decimals = 2,
    this.min,
  });

  @override
  State<_NumberRow> createState() => _NumberRowState();
}

class _NumberRowState extends State<_NumberRow> {
  late final TextEditingController _text = TextEditingController(
    text: _format(widget.value),
  );

  String _format(double v) =>
      v.toStringAsFixed(widget.decimals).replaceAll('.', ',');

  void _set(double v) {
    final min = widget.min;
    widget.onSet(min == null || v >= min ? v : min);
  }

  void _commit() {
    final v = double.tryParse(_text.text.trim().replaceAll(',', '.'));
    if (v == null || (v - widget.value).abs() < 1e-9) {
      _text.text = _format(widget.value);
      return;
    }
    _set(v);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget nudge(IconData icon, double by, String tip) => IconButton(
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      iconSize: 16,
      icon: Icon(icon),
      onPressed: () => _set(widget.value + by),
    );
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(widget.label, style: AppTypography.caption(palette)),
        ),
        nudge(Icons.remove, -widget.step, 'Menos'),
        Expanded(
          child: Focus(
            onFocusChange: (has) {
              if (!has) _commit();
            },
            child: TextField(
              controller: _text,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                suffixText: widget.unit,
              ),
              onSubmitted: (_) => _commit(),
            ),
          ),
        ),
        nudge(Icons.add, widget.step, 'Más'),
      ],
    );
  }
}
