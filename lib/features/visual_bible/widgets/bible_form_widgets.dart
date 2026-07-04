import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Campo de texto reutilizable para secciones de la Biblia Visual.
class BibleTextField extends StatelessWidget {
  final String label;
  final String hint;
  final int maxLines;
  final ValueChanged<String> onChanged;
  final String? initialValue;
  final TextEditingController? controller;

  const BibleTextField({
    super.key,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    required this.onChanged,
    this.initialValue,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label(palette)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          maxLines: maxLines,
          style: AppTypography.bodyLarge(palette),
          onChanged: onChanged,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

/// Desplegable para opciones predefinidas.
class BibleDropdown extends StatelessWidget {
  final String label;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String? value;

  const BibleDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.onChanged,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label(palette)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value != null && options.contains(value) ? value : null,
          dropdownColor: palette.surfaceElevated,
          style: AppTypography.bodyLarge(palette),
          decoration: const InputDecoration(),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Chips de selección múltiple.
class BibleMultiChipRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const BibleMultiChipRow({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label(palette)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final active = selected.contains(opt);
            return FilterChip(
              label: Text(opt),
              selected: active,
              onSelected: (v) {
                final next = List<String>.from(selected);
                if (v) {
                  next.add(opt);
                } else {
                  next.remove(opt);
                }
                onChanged(next);
              },
              selectedColor: palette.accent.withValues(alpha: 0.25),
              checkmarkColor: palette.accent,
            );
          }).toList(),
        ),
      ],
    );
  }
}
