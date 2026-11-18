import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Un foco del set en el panel: su identificador, cómo se llama y dónde
/// está («Set», «Grupo», «Entorno»).
typedef PlanLightUseItem = ({String uid, String name, String where});

/// Elegir rápido qué focos del set usa un plano (PL.2): casillas por foco
/// y tres atajos. Cada cambio se aplica al momento con [onApply], que
/// recibe los que no se usan.
class PlanLightUsePanel extends StatefulWidget {
  final String title;
  final List<PlanLightUseItem> lights;
  final Set<String> unused;

  /// Los que no usa el plano anterior del set, si lo hay.
  final Set<String>? previous;
  final String? previousLabel;
  final Future<void> Function(Set<String> unused) onApply;

  const PlanLightUsePanel({
    super.key,
    required this.title,
    required this.lights,
    required this.unused,
    required this.onApply,
    this.previous,
    this.previousLabel,
  });

  /// Abre el panel como hoja.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<PlanLightUseItem> lights,
    required Set<String> unused,
    required Future<void> Function(Set<String> unused) onApply,
    Set<String>? previous,
    String? previousLabel,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => PlanLightUsePanel(
      title: title,
      lights: lights,
      unused: unused,
      onApply: onApply,
      previous: previous,
      previousLabel: previousLabel,
    ),
  );

  @override
  State<PlanLightUsePanel> createState() => _PlanLightUsePanelState();
}

class _PlanLightUsePanelState extends State<PlanLightUsePanel> {
  late Set<String> _unused = {...widget.unused};
  var _busy = false;

  Set<String> get _all => {for (final l in widget.lights) l.uid};

  Future<void> _set(Set<String> unused) async {
    if (_busy) return;
    setState(() {
      _unused = unused.intersection(_all);
      _busy = true;
    });
    try {
      await widget.onApply(_unused);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final used = widget.lights.length - _unused.length;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                widget.title,
                style: AppTypography.titleMedium(palette),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                2,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                'Usa $used de ${widget.lights.length}. Los que no usa se '
                'quedan en el set, en fantasma. En la planta, la tecla U.',
                style: AppTypography.caption(palette),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  if (widget.previous != null)
                    ActionChip(
                      key: const ValueKey('light-use-previous'),
                      avatar: const Icon(Icons.history, size: 16),
                      label: Text(
                        widget.previousLabel == null
                            ? 'Igual que el plano anterior'
                            : 'Igual que ${widget.previousLabel}',
                      ),
                      onPressed: () => _set(widget.previous!),
                    ),
                  ActionChip(
                    key: const ValueKey('light-use-all'),
                    avatar: const Icon(Icons.done_all, size: 16),
                    label: const Text('Todos los del set'),
                    onPressed: () => _set(const {}),
                  ),
                  ActionChip(
                    key: const ValueKey('light-use-none'),
                    avatar: const Icon(Icons.remove_done, size: 16),
                    label: const Text('Ninguno'),
                    onPressed: () => _set(_all),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final light in widget.lights)
                    CheckboxListTile(
                      key: ValueKey('light-use-${light.uid}'),
                      dense: true,
                      value: !_unused.contains(light.uid),
                      title: Text(light.name),
                      subtitle: light.where.isEmpty ? null : Text(light.where),
                      onChanged: (on) => _set(
                        on == true
                            ? ({..._unused}..remove(light.uid))
                            : {..._unused, light.uid},
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
