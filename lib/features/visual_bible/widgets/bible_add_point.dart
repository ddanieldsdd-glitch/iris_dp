import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/visual_bible/bible_section_fields.dart';
import '../../../core/theme/app_typography.dart';
import 'catalog/bible_widget_catalog.dart';
import 'bible_point_panel.dart';

/// Punto recién creado: el campo y, si el widget lo necesita, su valor
/// inicial.
typedef BibleAddedPoint = ({BibleSectionField field, String? initialValue});

/// Pide nombre y widget para un punto nuevo. Devuelve `null` si se cancela.
Future<BibleAddedPoint?> showBibleAddPointDialog(BuildContext context) {
  return showDialog<BibleAddedPoint>(
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
  var _entry = BibleWidgetCatalog.entries.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    // Sin nombre, el punto toma el del widget.
    final label = _name.text.trim().isEmpty ? _entry.label : _name.text.trim();
    Navigator.pop<BibleAddedPoint>(context, (
      field: BibleSectionField(
        key: BibleSectionFieldsConfig.newFieldKey(),
        label: label,
        type: _entry.type,
      ),
      initialValue: _entry.initialValue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AlertDialog(
      title: const Text('Añadir punto'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Nombre del punto',
                  hintText: _entry.label,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final entry in BibleWidgetCatalog.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: entry == _entry
                        ? palette.accentMuted
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _entry = entry),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              entry.icon,
                              size: 20,
                              color: entry == _entry
                                  ? palette.accent
                                  : palette.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.label,
                                    style: AppTypography.bodyLarge(palette),
                                  ),
                                  Text(
                                    entry.description,
                                    style: AppTypography.caption(palette),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Añadir')),
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
