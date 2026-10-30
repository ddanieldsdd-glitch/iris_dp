import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_element_model.dart';
import 'plan_category.dart';

/// La lista de elementos de la planta (F6.20 A4), como el World Outliner de
/// Unreal: agrupada por categoría, con buscador. Cada fila dice qué es y
/// cómo se llama, si tiene asset de Unreal («UE»), y se oculta con el ojo.
/// Tocar una fila la selecciona en la planta y en el 3D.
class PlanOutliner extends StatefulWidget {
  final List<PlanElement> elements;
  final PlanElement? selected;
  final Set<PlanElement> hidden;
  final ValueChanged<PlanElement> onSelect;
  final ValueChanged<PlanElement> onToggleHidden;
  final VoidCallback? onClose;

  const PlanOutliner({
    super.key,
    required this.elements,
    required this.selected,
    required this.hidden,
    required this.onSelect,
    required this.onToggleHidden,
    this.onClose,
  });

  /// Si [el] encaja con lo que se busca: nombre, tipo, modelo o categoría.
  static bool matches(PlanElement el, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = [
      el.displayLabel,
      el.typeLabel,
      el.model ?? '',
      PlanCategory.of(el).label,
      if (PlanCategory.hasUnrealAsset(el)) 'ue unreal',
    ].join(' ').toLowerCase();
    return q.split(RegExp(r'\s+')).every(hay.contains);
  }

  /// Agrupa por categoría, en el orden de [PlanCategory], y por nombre.
  static List<(PlanCategory, List<PlanElement>)> group(
    Iterable<PlanElement> elements,
    String query,
  ) {
    final by = <PlanCategory, List<PlanElement>>{};
    for (final el in elements) {
      if (!matches(el, query)) continue;
      by.putIfAbsent(PlanCategory.of(el), () => []).add(el);
    }
    return [
      for (final c in PlanCategory.values)
        if (by[c] case final list?)
          (
            c,
            list..sort(
              (a, b) => a.displayLabel.toLowerCase().compareTo(
                b.displayLabel.toLowerCase(),
              ),
            ),
          ),
    ];
  }

  @override
  State<PlanOutliner> createState() => _PlanOutlinerState();
}

class _PlanOutlinerState extends State<PlanOutliner> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final groups = PlanOutliner.group(widget.elements, _query.text);
    final withUe = widget.elements.where(PlanCategory.hasUnrealAsset).length;
    return Material(
      color: palette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xs,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Elementos · ${widget.elements.length}',
                    style: AppTypography.titleMedium(palette),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    tooltip: 'Cerrar la lista',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              '$withUe con asset de Unreal',
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: TextField(
              controller: _query,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Buscar por nombre, tipo o modelo',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: groups.isEmpty
                ? Center(
                    child: Text(
                      'Nada con ese nombre.',
                      style: AppTypography.caption(palette),
                    ),
                  )
                : ListView(
                    children: [
                      for (final (cat, list) in groups) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: cat.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                '${cat.label.toUpperCase()} · ${list.length}',
                                style: AppTypography.label(palette),
                              ),
                            ],
                          ),
                        ),
                        for (final el in list) _row(palette, cat, el),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(AppPalette palette, PlanCategory cat, PlanElement el) {
    final hidden = widget.hidden.contains(el);
    final selected = identical(el, widget.selected);
    final sub = el.displayLabel == el.typeLabel ? null : el.typeLabel;
    return Material(
      color: selected ? cat.color.withValues(alpha: 0.16) : Colors.transparent,
      child: InkWell(
        onTap: hidden ? null : () => widget.onSelect(el),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            6,
            AppSpacing.xs,
            6,
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: sub == null ? 18 : 30,
                color: cat.color,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      el.displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium(palette).copyWith(
                        color: hidden ? palette.textTertiary : null,
                      ),
                    ),
                    if (sub != null)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(
                          palette,
                        ).copyWith(color: palette.textTertiary),
                      ),
                  ],
                ),
              ),
              if (PlanCategory.hasUnrealAsset(el))
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.textSecondary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'UE',
                    style: AppTypography.caption(
                      palette,
                    ).copyWith(fontSize: 9, fontWeight: FontWeight.w800),
                  ),
                ),
              IconButton(
                tooltip: hidden
                    ? 'Mostrar'
                    : 'Ocultar: no se ve ni alumbra en la planta, pero sigue '
                          'en la lista de material y en la carga del rigging',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: hidden ? palette.textTertiary : palette.textSecondary,
                ),
                onPressed: () => widget.onToggleHidden(el),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
