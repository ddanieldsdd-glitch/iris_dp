import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/settings/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_snackbar.dart';
import 'camera_plan_element_model.dart';
import 'plan_gear_list.dart';
import 'plan_power.dart';
import 'plan_prefs.dart';

/// Reparto eléctrico del esquema: circuitos, carga de cada uno y grupo.
class PlanPowerSheet extends StatefulWidget {
  final List<PlanElement> elements;
  final String title;

  /// Guarda lo que ha cambiado en la planta.
  final VoidCallback onChanged;

  const PlanPowerSheet({
    super.key,
    required this.elements,
    required this.title,
    required this.onChanged,
  });

  @override
  State<PlanPowerSheet> createState() => _PlanPowerSheetState();
}

class _PlanPowerSheetState extends State<PlanPowerSheet> {
  static const _breakers = <double>[10, 16, 32, 63, 125];

  double _volts = AppPrefs.instance.globalValue(PlanPrefs.powerVolts);
  double _breaker = AppPrefs.instance.globalValue(PlanPrefs.powerBreaker);

  PowerPlan get _plan =>
      PowerPlan.of(widget.elements, volts: _volts, breakerAmps: _breaker);

  void _setCircuit(PlanElement el, int? circuit) {
    if (circuit == null) {
      el.props.remove(PowerPlan.circuitKey);
    } else {
      el.props[PowerPlan.circuitKey] = circuit;
    }
    setState(() {});
    widget.onChanged();
  }

  void _distribute() {
    final loads = PowerPlan.loadsOf(widget.elements);
    final assigned = PowerPlan.distribute(loads, _plan.limitWatts);
    assigned.forEach((el, n) => el.props[PowerPlan.circuitKey] = n);
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final plan = _plan;
    final used = plan.circuits.isEmpty ? 0 : plan.circuits.last.number;
    final phases = plan.phases;
    final kva = plan.generatorKva;
    String kw(double w) => formatWatts(w);
    String amps(double w) =>
        '${plan.ampsOf(w).toStringAsFixed(1).replaceAll('.', ',')} A';

    Widget loadRow(PowerLoad load) => Row(
      children: [
        Expanded(
          child: Text(
            load.toString(),
            style: AppTypography.bodyMedium(palette),
          ),
        ),
        PopupMenuButton<int>(
          tooltip: 'Circuito',
          icon: const Icon(Icons.swap_vert, size: 18),
          onSelected: (n) => _setCircuit(load.element, n == 0 ? null : n),
          itemBuilder: (_) => [
            for (var n = 1; n <= used + 1; n++)
              PopupMenuItem(value: n, child: Text('Circuito $n')),
            const PopupMenuItem(value: 0, child: Text('Sin circuito')),
          ],
        ),
      ],
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Corriente', style: AppTypography.titleMedium(palette)),
            Text(
              '${widget.title} · cifras orientativas, para hablar con el '
              'eléctrico.',
              style: AppTypography.caption(palette),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                SegmentedButton<double>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 230, label: Text('230 V')),
                    ButtonSegment(value: 120, label: Text('120 V')),
                  ],
                  selected: {_volts},
                  onSelectionChanged: (v) {
                    AppPrefs.instance.setIn(
                      PlanPrefs.powerVolts,
                      const SettingsScope.global(),
                      v.first,
                    );
                    setState(() => _volts = v.first);
                  },
                ),
                DropdownButton<double>(
                  value: _breaker,
                  items: [
                    for (final a in _breakers)
                      DropdownMenuItem(
                        value: a,
                        child: Text('${a.round()} A por circuito'),
                      ),
                  ],
                  onChanged: (a) {
                    if (a == null) return;
                    AppPrefs.instance.setIn(
                      PlanPrefs.powerBreaker,
                      const SettingsScope.global(),
                      a,
                    );
                    setState(() => _breaker = a);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Total ${kw(plan.totalWatts)} · ${amps(plan.totalWatts)} · '
              'máx. ${kw(plan.limitWatts)} por circuito',
              style: AppTypography.bodyMedium(palette),
            ),
            if (kva != null)
              Text(
                'Grupo orientativo: ${kva == kva.roundToDouble() ? kva.round() : kva} kVA',
                style: AppTypography.caption(palette),
              )
            else if (plan.totalWatts > 0)
              Text(
                'Supera el grupo más grande de la lista: hace falta '
                'más de uno.',
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.warning),
              ),
            if (plan.circuits.length > 1)
              Text(
                'En trifásica: ${phases.map(kw).join(' / ')}',
                style: AppTypography.caption(palette),
              ),
            for (final load in plan.tooBig)
              Text(
                '${load.name} no cabe en un circuito de '
                '${_breaker.round()} A: necesita una salida mayor.',
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.error),
              ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('power-distribute'),
                    onPressed: plan.totalWatts > 0 ? _distribute : null,
                    child: const Text('Repartir solo'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: plan.totalWatts > 0
                        ? () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text: plan.toText(title: widget.title),
                              ),
                            );
                            if (context.mounted) {
                              AppSnackBar.show(context, 'Reparto copiado.');
                            }
                          }
                        : null,
                    child: const Text('Copiar'),
                  ),
                ),
              ],
            ),
            for (final c in plan.circuits) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Circuito ${c.number} · ${kw(c.watts)} · ${amps(c.watts)}'
                '${plan.isOver(c) ? ' · sobrecargado' : ''}',
                style: AppTypography.label(palette).copyWith(
                  color: plan.isOver(c) ? palette.error : palette.accent,
                ),
              ),
              LinearProgressIndicator(
                value: (c.watts / (plan.volts * plan.breakerAmps)).clamp(0, 1),
                color: plan.isOver(c) ? palette.error : palette.accent,
              ),
              for (final l in c.loads) loadRow(l),
            ],
            if (plan.unassigned.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Sin circuito', style: AppTypography.label(palette)),
              for (final l in plan.unassigned) loadRow(l),
            ],
          ],
        ),
      ),
    );
  }
}
