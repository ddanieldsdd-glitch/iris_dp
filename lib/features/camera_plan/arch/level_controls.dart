import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../camera_plan_element_model.dart';
import 'plan_levels.dart';

/// En el panel de un forjado (AM.6): si es el suelo de un nivel y cómo se
/// llama.
class LevelSlabControls extends StatefulWidget {
  final PlanElement element;
  final VoidCallback onUpdate;

  const LevelSlabControls({
    super.key,
    required this.element,
    required this.onUpdate,
  });

  @override
  State<LevelSlabControls> createState() => _LevelSlabControlsState();
}

class _LevelSlabControlsState extends State<LevelSlabControls> {
  late final _name = TextEditingController(
    text: widget.element.props[PlanLevels.nameKey] as String? ?? '',
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
    final isLevel = PlanLevels.isLevelSlab(el);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const ValueKey('slab-is-level'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Es el suelo de un nivel',
            style: AppTypography.bodyMedium(palette),
          ),
          subtitle: Text(
            'Lo que pongas en ese nivel queda a su cota y se ve aparte.',
            style: AppTypography.caption(palette),
          ),
          value: isLevel,
          onChanged: (v) {
            if (v) {
              final name = _name.text.trim().isEmpty
                  ? 'Planta'
                  : _name.text.trim();
              el.props[PlanLevels.nameKey] = name;
              _name.text = name;
            } else {
              el.props.remove(PlanLevels.nameKey);
            }
            widget.onUpdate();
          },
        ),
        if (isLevel)
          TextField(
            key: const ValueKey('slab-level-name'),
            controller: _name,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Nombre del nivel',
              hintText: 'Planta 1, entreplanta…',
            ),
            onSubmitted: (v) {
              if (v.trim().isEmpty) return;
              el.props[PlanLevels.nameKey] = v.trim();
              widget.onUpdate();
            },
          ),
      ],
    );
  }
}
