import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';

typedef EquipmentIdGetter<T> = int Function(T item);
typedef EquipmentBrandGetter<T> = String Function(T item);
typedef EquipmentSeriesGetter<T> = String? Function(T item);
typedef EquipmentTitleGetter<T> = String Function(T item);
typedef EquipmentSubtitleGetter<T> = String Function(T item);
typedef EquipmentFilterGetter<T> = String? Function(T item);

/// Lista agrupada por marca y serie con sección de asignados al proyecto.
class EquipmentBrandGroupedList<T extends Object> extends StatelessWidget {
  final List<T> items;
  final Set<int> assignedIds;
  final Set<int> customIds;
  final EquipmentIdGetter<T> idOf;
  final EquipmentBrandGetter<T> brandOf;
  final EquipmentSeriesGetter<T> seriesOf;
  final EquipmentTitleGetter<T> titleOf;
  final EquipmentSubtitleGetter<T> subtitleOf;
  final EquipmentFilterGetter<T>? filterOf;
  final String? activeFilter;
  final bool vintageOnly;
  final bool lukaOnly;
  final void Function(T item) onTap;
  final Future<void> Function(T item) onToggleAssign;
  final String? Function(T item)? projectRoleLabel;
  final Widget? Function(T item)? trailingBuilder;

  const EquipmentBrandGroupedList({
    super.key,
    required this.items,
    required this.assignedIds,
    required this.customIds,
    required this.idOf,
    required this.brandOf,
    required this.seriesOf,
    required this.titleOf,
    required this.subtitleOf,
    this.filterOf,
    this.activeFilter,
    this.vintageOnly = false,
    this.lukaOnly = false,
    required this.onTap,
    required this.onToggleAssign,
    this.projectRoleLabel,
    this.trailingBuilder,
  });

  List<T> get _filtered {
    return items.where((item) {
      if (vintageOnly && item is! Camera && item is! Lense && item is! Light) {
        return false;
      }
      if (vintageOnly) {
        final v = switch (item) {
          Camera c => c.vintage,
          Lense l => l.vintage,
          Light l => l.vintage,
          _ => false,
        };
        if (!v) return false;
      }
      if (lukaOnly) {
        final ok = switch (item) {
          Camera c => c.lukaCompatible,
          Lense l => l.lukaCompatible,
          Light l => l.isLukaCompatible,
          _ => false,
        };
        if (!ok) return false;
      }
      if (activeFilter != null && filterOf != null) {
        final chip = filterOf!(item);
        if (chip != activeFilter) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final filtered = _filtered;
    final assigned = filtered.where((i) => assignedIds.contains(idOf(i))).toList();
    final custom = filtered.where((i) => customIds.contains(idOf(i))).toList();
    final catalog = filtered
        .where((i) =>
            !customIds.contains(idOf(i)) && !assignedIds.contains(idOf(i)))
        .toList();

    final byBrand = <String, List<T>>{};
    for (final item in catalog) {
      byBrand.putIfAbsent(brandOf(item), () => []).add(item);
    }
    final brands = byBrand.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Catálogo IRIS v2 — agrupado por marca. Toca para ficha, FLT o Biblia.',
            style: AppTypography.caption(palette),
          ),
        ),
        if (assigned.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Asignado al proyecto', style: AppTypography.titleMedium(palette)),
          ...assigned.map((i) => _row(context, i, palette, inProject: true)),
        ],
        if (custom.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Mis custom', style: AppTypography.titleMedium(palette)),
          ...custom.map((i) => _row(context, i, palette, inProject: assignedIds.contains(idOf(i)))),
        ],
        const SizedBox(height: AppSpacing.md),
        Text('Catálogo', style: AppTypography.titleMedium(palette)),
        ...brands.expand((brand) {
          final brandItems = byBrand[brand]!;
          final bySeries = <String, List<T>>{};
          for (final item in brandItems) {
            final series = seriesOf(item) ?? 'General';
            bySeries.putIfAbsent(series, () => []).add(item);
          }
          return [
            ExpansionTile(
              initiallyExpanded: brands.length <= 8,
              title: Text('$brand (${brandItems.length})',
                  style: AppTypography.titleMedium(palette)),
              children: bySeries.entries.map((entry) {
                final sorted = List<T>.from(entry.value);
                sorted.sort((a, b) => titleOf(a).compareTo(titleOf(b)));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        entry.key,
                        style: AppTypography.caption(palette).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...sorted.map(
                      (i) => _row(
                        context,
                        i,
                        palette,
                        inProject: assignedIds.contains(idOf(i)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ];
        }),
      ],
    );
  }

  Widget _row(BuildContext context, T item, AppPalette palette, {required bool inProject}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: InkWell(
          onTap: () => onTap(item),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            titleOf(item),
                            style: AppTypography.titleMedium(palette),
                          ),
                        ),
                        if (inProject) ...[
                          const SizedBox(width: 8),
                          ..._roleBadges(item, palette),
                        ],
                      ],
                    ),
                    Text(subtitleOf(item), style: AppTypography.bodyMedium(palette)),
                  ],
                ),
              ),
              if (trailingBuilder != null) trailingBuilder!(item) ?? const SizedBox.shrink(),
              IconButton(
                tooltip: inProject ? 'Quitar del proyecto' : 'Añadir al proyecto',
                icon: Icon(
                  inProject ? Icons.check_circle : Icons.add_circle_outline,
                  color: inProject ? palette.accent : palette.textSecondary,
                ),
                onPressed: () => onToggleAssign(item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _roleBadges(T item, AppPalette palette) {
    final role = projectRoleLabel?.call(item);
    if (role == null || role.isEmpty) return const [];
    final active = role == 'A-CAM';
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: active
              ? palette.accent.withValues(alpha: 0.15)
              : palette.surfaceElevated,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active
                ? palette.accent.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          role,
          style: AppTypography.mono(palette).copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: active ? palette.accent : palette.textTertiary,
          ),
        ),
      ),
    ];
  }
}
