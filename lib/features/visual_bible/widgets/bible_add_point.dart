import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/visual_bible/bible_section_fields.dart';
import '../../../shared/visual_bible/bible_stitch_module_registry.dart';
import '../../../core/theme/app_typography.dart';
import 'catalog/bible_widget_catalog.dart';
import 'bible_point_panel.dart';

/// Punto recién creado: el campo y, si el widget lo necesita, su valor
/// inicial.
typedef BibleAddedPoint = ({BibleSectionField field, String? initialValue});

/// Pide qué punto añadir a una pantalla. Ofrece dos grupos: los puntos
/// propios de la pantalla que no están puestos y los widgets del catálogo.
/// Devuelve `null` si se cancela.
Future<BibleAddedPoint?> showBibleAddPointDialog(
  BuildContext context, {
  required String sectionId,
  required List<BibleSectionField> fields,
}) {
  return showDialog<BibleAddedPoint>(
    context: context,
    builder: (_) => _AddPointDialog(
      sectionPoints: BibleStitchModuleRegistry.missingModules(sectionId, fields)
          .map((m) => m.toField())
          .toList(),
    ),
  );
}

class _AddPointDialog extends StatefulWidget {
  /// Puntos propios de la pantalla que hoy no están en ella.
  final List<BibleSectionField> sectionPoints;

  const _AddPointDialog({required this.sectionPoints});

  @override
  State<_AddPointDialog> createState() => _AddPointDialogState();
}

class _AddPointDialogState extends State<_AddPointDialog> {
  final _name = TextEditingController();
  BibleWidgetEntry? _entry = BibleWidgetCatalog.entries.first;
  BibleSectionField? _sectionPoint;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final sectionPoint = _sectionPoint;
    if (sectionPoint != null) {
      // Un punto de la pantalla conserva su clave: recupera su contenido.
      Navigator.pop<BibleAddedPoint>(context, (
        field: sectionPoint,
        initialValue: null,
      ));
      return;
    }
    final entry = _entry!;
    // Sin nombre, el punto toma el del widget.
    final label = _name.text.trim().isEmpty ? entry.label : _name.text.trim();
    Navigator.pop<BibleAddedPoint>(context, (
      field: BibleSectionField(
        key: BibleSectionFieldsConfig.newFieldKey(),
        label: label,
        type: entry.type,
      ),
      initialValue: entry.initialValue,
    ));
  }

  Widget _option({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? palette.accentMuted : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? palette.accent : palette.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.bodyLarge(palette)),
                      Text(subtitle, style: AppTypography.caption(palette)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final heading = BiblePointPanel.labelStyle(palette);
    return AlertDialog(
      title: const Text('Añadir punto'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.sectionPoints.isNotEmpty) ...[
                Text('DE ESTA PANTALLA', style: heading),
                const SizedBox(height: AppSpacing.sm),
                for (final point in widget.sectionPoints)
                  _option(
                    icon: Icons.restore_outlined,
                    title: point.label,
                    subtitle: 'Punto propio de la pantalla. Recupera su contenido.',
                    selected: _sectionPoint?.key == point.key,
                    onTap: () => setState(() {
                      _sectionPoint = point;
                      _entry = null;
                    }),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text('WIDGETS', style: heading),
                const SizedBox(height: AppSpacing.sm),
              ],
              for (final entry in BibleWidgetCatalog.entries)
                _option(
                  icon: entry.icon,
                  title: entry.label,
                  subtitle: entry.description,
                  selected: entry == _entry,
                  onTap: () => setState(() {
                    _entry = entry;
                    _sectionPoint = null;
                  }),
                ),
              if (_entry != null) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Nombre del punto',
                    hintText: _entry!.label,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ],
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
