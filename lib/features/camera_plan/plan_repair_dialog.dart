import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'plan_repair.dart';

/// «Ordenar la planta» (SG.6): enseña lo que encuentra, cada cosa con su
/// casilla, y lo arregla al aceptar. Lo que se quita va a la papelera.
Future<void> showPlanRepairDialog(
  BuildContext context,
  AppDatabase db,
  int projectId,
) async {
  final repair = PlanRepair(db);
  final report = await repair.analyze(projectId);
  if (!context.mounted) return;
  final done = await showDialog<bool>(
    context: context,
    builder: (_) => _PlanRepairDialog(repair: repair, report: report),
  );
  if (done == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Planta ordenada. Lo quitado está en la papelera de plantas.',
        ),
      ),
    );
  }
}

class _PlanRepairDialog extends StatefulWidget {
  final PlanRepair repair;
  final PlanRepairReport report;

  const _PlanRepairDialog({required this.repair, required this.report});

  @override
  State<_PlanRepairDialog> createState() => _PlanRepairDialogState();
}

class _PlanRepairDialogState extends State<_PlanRepairDialog> {
  late final _merges = {for (final m in widget.report.merges) m};
  late final _assigns = {for (final a in widget.report.assigns) a};
  late final _zones = {
    for (final z in widget.report.zones)
      if (z.alone) z,
  };
  late final _envLights = {for (final e in widget.report.envLights) e};
  bool _busy = false;

  Future<void> _apply() async {
    setState(() => _busy = true);
    for (final m in _merges) {
      await widget.repair.merge(m.target.id, [for (final s in m.sources) s.id]);
    }
    for (final a in _assigns) {
      await widget.repair.assign(a.setup.id, [for (final s in a.shots) s.id]);
    }
    for (final z in _zones) {
      await widget.repair.foldZone(z.zone.id);
    }
    for (final e in _envLights) {
      await widget.repair.moveLightsToEnvironment(e.setup.id);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final report = widget.report;
    Widget item({
      required bool value,
      required ValueChanged<bool> onChanged,
      required String title,
      required String detail,
    }) => CheckboxListTile(
      value: value,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: _busy ? null : (v) => setState(() => onChanged(v == true)),
      title: Text(title, style: AppTypography.bodyLarge(palette)),
      subtitle: Text(detail, style: AppTypography.caption(palette)),
    );

    return AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(
        'Ordenar la planta',
        style: AppTypography.titleMedium(palette),
      ),
      content: SizedBox(
        width: 480,
        child: report.isEmpty
            ? Text(
                'La planta está en orden: no hay esquemas de un solo plano '
                'que juntar, luces dibujadas sin usar ni zonas dibujadas.',
                style: AppTypography.bodyMedium(palette),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final m in report.merges)
                    item(
                      value: _merges.contains(m),
                      onChanged: (v) => v ? _merges.add(m) : _merges.remove(m),
                      title:
                          '${m.site.name}: ${m.sources.length + 1} esquemas '
                          '→ un set',
                      detail:
                          'Los ${m.shots} planos pasan a «${m.target.name}» '
                          'con su cámara cada uno; las luces de los demás se '
                          'juntan ahí. ${_names(m.sources)} van a la '
                          'papelera.',
                    ),
                  for (final a in report.assigns)
                    item(
                      value: _assigns.contains(a),
                      onChanged: (v) =>
                          v ? _assigns.add(a) : _assigns.remove(a),
                      title:
                          '${a.site.name}: «${a.setup.name}» tiene luz y '
                          'ningún plano',
                      detail:
                          'Asignarlo a los ${a.shots.length} planos sin luz '
                          'de la localización.',
                    ),
                  for (final z in report.zones)
                    item(
                      value: _zones.contains(z),
                      onChanged: (v) => v ? _zones.add(z) : _zones.remove(z),
                      title:
                          '${z.site.name}: pasar «${z.zone.locationName}» '
                          'a la localización',
                      detail:
                          '${z.elements} elemento${z.elements == 1 ? '' : 's'} '
                          'dibujado${z.elements == 1 ? '' : 's'} en la zona '
                          'pasan al entorno de la localización: lo ven todos '
                          'sus sets y se edita desde cualquiera.'
                          '${z.alone ? '' : ' Hay otras zonas dibujadas: '
                                    'revisa que no se pisen.'}',
                    ),
                  for (final e in report.envLights)
                    item(
                      value: _envLights.contains(e),
                      onChanged: (v) =>
                          v ? _envLights.add(e) : _envLights.remove(e),
                      title:
                          '${e.site.name}: pasar las luces de '
                          '«${e.setup.name}» al entorno',
                      detail:
                          '${e.lights} luz${e.lights == 1 ? '' : 'es'} '
                          'pasan al entorno de la localización: las ven todos '
                          'sus sets, y cada set o plano puede apagarlas. Las '
                          'cámaras y actores se quedan en «${e.setup.name}».',
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(report.isEmpty ? 'Cerrar' : 'Cancelar'),
        ),
        if (!report.isEmpty)
          FilledButton(
            onPressed:
                _busy ||
                    (_merges.isEmpty &&
                        _assigns.isEmpty &&
                        _zones.isEmpty &&
                        _envLights.isEmpty)
                ? null
                : _apply,
            child: Text(_busy ? 'Ordenando…' : 'Ordenar'),
          ),
      ],
    );
  }

  static String _names(List<LightSetup> setups) {
    final names = [for (final s in setups) '«${s.name}»'];
    return names.length <= 4
        ? names.join(', ')
        : '${names.take(4).join(', ')} y ${names.length - 4} más';
  }
}
