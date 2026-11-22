import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../camera_plan_element_model.dart';
import 'arch_material.dart';
import 'arch_material_picker.dart';
import 'arch_roof.dart';
import 'arch_solid.dart';

/// La cubierta de un volumen (plan AM.3): forma, cuánto sube, hacia dónde
/// va la cumbrera y su material.
class ArchRoofControls extends StatelessWidget {
  final PlanElement element;
  final VoidCallback onPreview;
  final VoidCallback onUpdate;

  const ArchRoofControls({
    super.key,
    required this.element,
    required this.onPreview,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final el = element;
    final current =
        ArchSolid.roof(el) ?? const ArchRoof(kind: ArchRoofKind.flat);
    final size = ArchSolid.sizeM(el);
    // De partida, la cumbrera a lo largo del lado más largo.
    final longDeg = size.width >= size.height ? 0.0 : 90.0;

    void set(ArchRoof r, {bool save = true}) {
      ArchSolid.setRoof(el, r);
      save ? onUpdate() : onPreview();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Cubierta', style: AppTypography.caption(palette)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final kind in ArchRoofKind.values)
              ChoiceChip(
                key: ValueKey('solid-roof-${kind.name}'),
                label: Text(kind.label),
                selected: current.kind == kind,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => set(
                  ArchSolid.roof(el) == null
                      ? ArchRoof(kind: kind, ridgeDeg: longDeg)
                      : current.copyWith(kind: kind),
                ),
              ),
          ],
        ),
        if (current.kind != ArchRoofKind.flat) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  current.kind == ArchRoofKind.shed
                      ? 'El lado alto sube'
                      : 'La cumbrera sube',
                  style: AppTypography.caption(palette),
                ),
              ),
              Text(
                '${current.riseM.toStringAsFixed(2)} m',
                style: AppTypography.caption(palette),
              ),
            ],
          ),
          Slider(
            value: current.riseM.clamp(0.1, 10),
            min: 0.1,
            max: 10,
            onChanged: (v) =>
                set(current.copyWith(riseM: (v * 20).round() / 20), save: false),
            onChangeEnd: (_) => onUpdate(),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('solid-roof-turn'),
              icon: const Icon(Icons.rotate_90_degrees_ccw, size: 16),
              label: Text(
                current.kind == ArchRoofKind.shed
                    ? 'Girar la caída'
                    : 'Girar la cumbrera',
              ),
              onPressed: () => set(
                current.copyWith(
                  ridgeDeg: current.kind == ArchRoofKind.shed
                      ? (current.ridgeDeg + 90) % 360
                      : (current.ridgeDeg + 90) % 180,
                ),
              ),
            ),
          ),
          ArchMaterialField(
            label: 'Material de la cubierta',
            value: ArchMaterials.byId(current.mat) ?? ArchSolid.material(el),
            onChanged: (m) => set(current.copyWith(mat: m.id)),
          ),
        ],
      ],
    );
  }
}
