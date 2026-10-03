import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/visual_bible/bible_section_fields.dart';
import 'bible_generic_point_views.dart';
import 'bible_point_panel.dart';

/// Tipos que el usuario puede elegir al añadir un punto propio.
const kBibleUserPointTypes = [
  BibleSectionFieldType.text,
  BibleSectionFieldType.list,
  BibleSectionFieldType.specs,
  BibleSectionFieldType.references,
];

String _userPointTypeLabel(BibleSectionFieldType type) => switch (type) {
      BibleSectionFieldType.list => 'Lista',
      BibleSectionFieldType.specs => 'Datos técnicos',
      BibleSectionFieldType.references => 'Referencias',
      _ => 'Texto',
    };

IconData _userPointTypeIcon(BibleSectionFieldType type) =>
    type == BibleSectionFieldType.references
        ? Icons.collections_outlined
        : BibleGenericPointView.iconFor(type);

/// Pide nombre y tipo para un punto nuevo. Devuelve `null` si se cancela.
Future<BibleSectionField?> showBibleAddPointDialog(BuildContext context) {
  return showDialog<BibleSectionField>(
    context: context,
    builder: (_) => const _AddPointDialog(),
  );
}

class _AddPointDialog extends StatefulWidget {
  const _AddPointDialog();

  @override
  State<_AddPointDialog> createState() => _AddPointDialogState();
}

class _AddPointDialogState extends State<_AddPointDialog> {
  final _name = TextEditingController();
  var _type = BibleSectionFieldType.text;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _name.text.trim();
    if (label.isEmpty) return;
    Navigator.pop(
      context,
      BibleSectionField(
        key: BibleSectionFieldsConfig.newFieldKey(),
        label: label,
        type: _type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir punto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Nombre del punto'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final type in kBibleUserPointTypes)
                ChoiceChip(
                  avatar: Icon(_userPointTypeIcon(type), size: 16),
                  label: Text(_userPointTypeLabel(type)),
                  selected: _type == type,
                  onSelected: (_) => setState(() => _type = type),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _submit,
          child: const Text('Añadir'),
        ),
      ],
    );
  }
}

/// Botón «Añadir punto» que cierra cada sección de la biblia.
class BibleAddPointTile extends StatelessWidget {
  final VoidCallback onTap;

  const BibleAddPointTile({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BiblePointPanel.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BiblePointPanel.radius),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 16, color: palette.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text('AÑADIR PUNTO', style: BiblePointPanel.labelStyle(palette)),
            ],
          ),
        ),
      ),
    );
  }
}
