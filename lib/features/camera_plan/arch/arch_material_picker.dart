import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'arch_material.dart';

/// Muestra de un material: su textura CC0 o, si no tiene, su color.
class ArchMaterialSwatch extends StatelessWidget {
  final ArchMaterial material;
  final double size;

  const ArchMaterialSwatch({
    super.key,
    required this.material,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final rgb = material.albedoRgb;
    // El albedo es lineal: a la pantalla va en sRGB.
    int srgb(int c) {
      final v = c / 255;
      final s = v <= 0.0031308 ? v * 12.92 : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
      return (s.clamp(0.0, 1.0) * 255).round();
    }

    final flat = Color.fromARGB(
      255,
      srgb(rgb >> 16 & 255),
      srgb(rgb >> 8 & 255),
      srgb(rgb & 255),
    );
    final texture = material.texture;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox.square(
        dimension: size,
        child: texture == null
            ? ColoredBox(
                color: material.transmission > 0.3
                    ? flat.withValues(alpha: 0.45)
                    : flat,
              )
            : Image.asset(
                texture.albedoAsset,
                fit: BoxFit.cover,
                cacheWidth: (size * 2).round(),
                errorBuilder: (_, _, _) => ColoredBox(color: flat),
              ),
      ),
    );
  }
}

/// Fila del panel con el material elegido; al tocarla se abre la
/// biblioteca por familias (plan AM.1). La comparten paredes, suelos,
/// cubiertas y volúmenes.
class ArchMaterialField extends StatelessWidget {
  final String label;
  final ArchMaterial? value;
  final ValueChanged<ArchMaterial> onChanged;

  /// Qué se puede elegir; por defecto, todo lo de construir.
  final Iterable<ArchMaterial>? options;

  const ArchMaterialField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.options,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final current = value;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption(palette)),
          const SizedBox(height: 4),
          InkWell(
            key: const ValueKey('arch-material-field'),
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final picked = await showArchMaterialPicker(
                context,
                selected: current?.id,
                options: options,
              );
              if (picked != null) onChanged(picked);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  if (current != null)
                    ArchMaterialSwatch(material: current, size: 32)
                  else
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: palette.border),
                      ),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      current == null
                          ? 'Sin material'
                          : '${current.name} · ${current.family.label}',
                      style: AppTypography.bodyMedium(palette),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: palette.textTertiary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La biblioteca de materiales en una hoja, por familias, con miniaturas.
Future<ArchMaterial?> showArchMaterialPicker(
  BuildContext context, {
  String? selected,
  Iterable<ArchMaterial>? options,
}) {
  final list = (options ?? ArchMaterials.building).toList();
  return showModalBottomSheet<ArchMaterial>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final palette = context.palette;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text('Material', style: AppTypography.titleMedium(palette)),
            const SizedBox(height: 4),
            Text(
              'Texturas CC0 de ambientCG, a su tamaño real. Lo que devuelve '
              'cada una a la luz sale de su color.',
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary),
            ),
            for (final family in ArchFamily.values)
              if (list.where((m) => m.family == family).toList()
                  case final items when items.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(family.label, style: AppTypography.caption(palette)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final m in items)
                      _PickerTile(
                        material: m,
                        selected: m.id == selected,
                        onTap: () => Navigator.of(context).pop(m),
                      ),
                  ],
                ),
              ],
          ],
        ),
      );
    },
  );
}

class _PickerTile extends StatelessWidget {
  final ArchMaterial material;
  final bool selected;
  final VoidCallback onTap;

  const _PickerTile({
    required this.material,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      key: ValueKey('arch-material-${material.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? palette.accent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ArchMaterialSwatch(material: material, size: 72),
            ),
            const SizedBox(height: 4),
            Text(
              material.name,
              style: AppTypography.caption(palette),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
