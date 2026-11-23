import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../camera_plan_element_model.dart';
import 'plan_section.dart';

/// En el panel de una línea de sección (AM.6): su letra y hacia qué lado
/// se mira.
class SectionControls extends StatefulWidget {
  final PlanElement element;
  final double metersPerUnit;
  final VoidCallback onUpdate;

  const SectionControls({
    super.key,
    required this.element,
    required this.metersPerUnit,
    required this.onUpdate,
  });

  @override
  State<SectionControls> createState() => _SectionControlsState();
}

class _SectionControlsState extends State<SectionControls> {
  late final _name = TextEditingController(
    text: PlanSection.name(widget.element),
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final el = widget.element;
    final len = PlanSection.lengthM(el, widget.metersPerUnit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('section-name'),
          controller: _name,
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'Letra de la sección',
            hintText: 'A, B, C…',
          ),
          onSubmitted: (v) {
            if (v.trim().isEmpty) return;
            el.props[PlanSection.nameKey] = v.trim();
            widget.onUpdate();
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('section-flip'),
          icon: const Icon(Icons.swap_vert),
          label: const Text('Mirar al otro lado'),
          onPressed: () {
            PlanSection.flip(el);
            widget.onUpdate();
          },
        ),
        const SizedBox(height: 4),
        Text(
          'Corta ${len.toStringAsFixed(1).replaceAll('.', ',')} m de planta. '
          'Lo de delante de las flechas no se ve; lo que cruza la línea '
          'sale relleno. Se ve en «Alzado y perfil» y en la hoja de luz.',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textTertiary),
        ),
      ],
    );
  }
}
