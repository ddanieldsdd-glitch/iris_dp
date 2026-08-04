import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../equipment_spec_helpers.dart';
import '../lens_set_utils.dart';

/// Lista de ópticas agrupada por marca y set de lentes.
class LensSetGroupedList extends StatelessWidget {
  final List<Lense> items;
  final Set<int> assignedIds;
  final Set<int> customIds;
  final String? activeFilter;
  final bool vintageOnly;
  final bool lukaOnly;
  final void Function(Lense lens) onTap;
  final Future<void> Function(Lense lens) onToggleAssign;

  const LensSetGroupedList({
    super.key,
    required this.items,
    required this.assignedIds,
    required this.customIds,
    this.activeFilter,
    this.vintageOnly = false,
    this.lukaOnly = false,
    required this.onTap,
    required this.onToggleAssign,
  });

  List<Lense> get _filtered {
    return items.where((l) {
      if (vintageOnly && !l.vintage) return false;
      if (lukaOnly && !l.lukaCompatible) return false;
      if (activeFilter != null && l.formatCoverage != activeFilter) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final filtered = _filtered;
    final assigned = filtered.where((l) => assignedIds.contains(l.id)).toList();
    final custom = filtered.where((l) => customIds.contains(l.id)).toList();
    final catalog = filtered
        .where((l) => !customIds.contains(l.id) && !assignedIds.contains(l.id))
        .toList();

    final byBrand = LensSetUtils.groupByBrandAndSet(catalog);
    final brands = byBrand.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Catálogo agrupado por set de lentes. Expande un set para ver focales.',
            style: AppTypography.caption(palette),
          ),
        ),
        if (assigned.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Asignado al proyecto', style: AppTypography.titleMedium(palette)),
          ...assigned.map((l) => _lensRow(context, l, palette, inProject: true)),
        ],
        if (custom.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Mis custom', style: AppTypography.titleMedium(palette)),
          ...custom.map(
            (l) => _lensRow(
              context,
              l,
              palette,
              inProject: assignedIds.contains(l.id),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text('Catálogo por sets', style: AppTypography.titleMedium(palette)),
        ...brands.expand((brand) {
          final sets = byBrand[brand]!;
          final setNames = sets.keys.toList()..sort();
          final lensCount =
              sets.values.fold<int>(0, (sum, list) => sum + list.length);

          return [
            ExpansionTile(
              initiallyExpanded: brands.length <= 6,
              title: Text(
                '$brand ($lensCount lentes · ${setNames.length} sets)',
                style: AppTypography.titleMedium(palette),
              ),
              children: setNames.map((setName) {
                final setLenses = sets[setName]!;
                return _SetTile(
                  brand: brand,
                  setName: setName,
                  lenses: setLenses,
                  assignedIds: assignedIds,
                  palette: palette,
                  onTap: onTap,
                  onToggleAssign: onToggleAssign,
                );
              }).toList(),
            ),
          ];
        }),
      ],
    );
  }

  Widget _lensRow(
    BuildContext context,
    Lense lens,
    AppPalette palette, {
    required bool inProject,
    bool compact = false,
  }) {
    final title = compact
        ? LensSetUtils.focalLabel(lens)
        : '${lens.brand} ${lens.model}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: compact ? AppSpacing.xs : AppSpacing.sm,
        ),
        child: InkWell(
          onTap: () => onTap(lens),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: compact
                          ? AppTypography.bodyMedium(palette)
                              .copyWith(fontWeight: FontWeight.w600)
                          : AppTypography.titleMedium(palette),
                    ),
                    Text(
                      lensListSubtitle(lens),
                      style: AppTypography.caption(palette),
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: inProject ? 'Quitar del proyecto' : 'Añadir al proyecto',
                icon: Icon(
                  inProject ? Icons.check_circle : Icons.add_circle_outline,
                  color: inProject ? palette.accent : palette.textSecondary,
                  size: compact ? 20 : 24,
                ),
                onPressed: () => onToggleAssign(lens),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetTile extends StatelessWidget {
  final String brand;
  final String setName;
  final List<Lense> lenses;
  final Set<int> assignedIds;
  final AppPalette palette;
  final void Function(Lense lens) onTap;
  final Future<void> Function(Lense lens) onToggleAssign;

  const _SetTile({
    required this.brand,
    required this.setName,
    required this.lenses,
    required this.assignedIds,
    required this.palette,
    required this.onTap,
    required this.onToggleAssign,
  });

  @override
  Widget build(BuildContext context) {
    final summary = LensSetUtils.setSummary(lenses);
    final assignedInSet = lenses.where((l) => assignedIds.contains(l.id)).length;

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 4, bottom: 4),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
        title: Text(
          setName,
          style: AppTypography.bodyMedium(palette).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          summary,
          style: AppTypography.caption(palette),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: assignedInSet > 0
            ? Chip(
                label: Text('$assignedInSet', style: const TextStyle(fontSize: 11)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              )
            : null,
        children: lenses
            .map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _CompactLensRow(
                  lens: l,
                  inProject: assignedIds.contains(l.id),
                  palette: palette,
                  onTap: () => onTap(l),
                  onToggleAssign: () => onToggleAssign(l),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CompactLensRow extends StatelessWidget {
  final Lense lens;
  final bool inProject;
  final AppPalette palette;
  final VoidCallback onTap;
  final Future<void> Function() onToggleAssign;

  const _CompactLensRow({
    required this.lens,
    required this.inProject,
    required this.palette,
    required this.onTap,
    required this.onToggleAssign,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      LensSetUtils.focalLabel(lens),
      'T${lens.minTStop.toStringAsFixed(1)}',
      if (lens.mountType != null) lens.mountType!,
      if (lens.isAnamorphic) '${lens.squeezeRatio ?? 2.0}x',
    ];

    return Material(
      color: palette.surfaceElevated.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  parts.join(' · '),
                  style: AppTypography.bodyMedium(palette),
                ),
              ),
              if (lens.lukaCompatible)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.link, size: 14, color: palette.accent),
                ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                tooltip: inProject ? 'Quitar' : 'Añadir',
                icon: Icon(
                  inProject ? Icons.check_circle : Icons.add_circle_outline,
                  size: 20,
                  color: inProject ? palette.accent : palette.textSecondary,
                ),
                onPressed: onToggleAssign,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
