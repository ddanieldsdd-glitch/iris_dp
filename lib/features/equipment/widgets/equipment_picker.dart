import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../equipment_detail_screen.dart';
import '../../optics_lab/optics_lab_screen.dart';

/// Selector unificado de equipo del catálogo / proyecto.
class EquipmentPicker extends ConsumerWidget {
  final int projectId;
  final String equipmentType;
  final int? selectedId;
  final ValueChanged<int?> onSelected;
  final String label;
  final bool syncToBible;

  const EquipmentPicker({
    super.key,
    required this.projectId,
    required this.equipmentType,
    required this.selectedId,
    required this.onSelected,
    required this.label,
    this.syncToBible = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final palette = context.palette;

    return StreamBuilder<List<ProjectEquipmentData>>(
      stream: db.watchProjectEquipment(projectId),
      builder: (context, assignSnap) {
        final assigned = assignSnap.data ?? [];
        final assignedIds = assigned
            .where((a) => a.equipmentType == equipmentType)
            .map((a) => a.equipmentId)
            .toSet();

        return switch (equipmentType) {
          'camera' => StreamBuilder<List<Camera>>(
              stream: db.watchAllCameras(),
              builder: (context, snap) => _buildDropdown<Camera>(
                context,
                ref,
                palette,
                items: _sortedCameras(snap.data ?? [], assignedIds),
                selectedId: selectedId,
                label: label,
                title: (c) => '${c.brand} ${c.model}',
                subtitle: (c) =>
                    '${c.mountType ?? '—'} · ${c.sensorWidthMm.toStringAsFixed(1)}×${c.sensorHeightMm.toStringAsFixed(1)} mm',
                chip: (c) => c.mountType ?? '',
              ),
            ),
          'lens' => StreamBuilder<List<Lense>>(
              stream: db.watchAllLenses(),
              builder: (context, snap) => _buildDropdown<Lense>(
                context,
                ref,
                palette,
                items: _sortedLenses(snap.data ?? [], assignedIds),
                selectedId: selectedId,
                label: label,
                title: (l) => '${l.brand} ${l.model}',
                subtitle: (l) {
                  final focal = l.focalLength > 0
                      ? '${l.focalLength.toStringAsFixed(0)} mm'
                      : '${l.focalMin?.toStringAsFixed(0)}–${l.focalMax?.toStringAsFixed(0)} mm';
                  return '$focal · T${l.minTStop} · ${l.formatCoverage}';
                },
                chip: (l) => l.mountType ?? l.formatCoverage,
              ),
            ),
          'light' => StreamBuilder<List<Light>>(
              stream: db.watchAllLights(),
              builder: (context, snap) => _buildDropdown<Light>(
                context,
                ref,
                palette,
                items: _sortedLights(snap.data ?? [], assignedIds),
                selectedId: selectedId,
                label: label,
                title: (l) => '${l.brand} ${l.model}',
                subtitle: (l) => '${l.powerW} W · ${l.colorTempMin}–${l.colorTempMax} K',
                chip: (l) => l.lightType,
              ),
            ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }

  List<Camera> _sortedCameras(List<Camera> all, Set<int> assignedIds) {
    final assigned = all.where((c) => assignedIds.contains(c.id)).toList();
    final rest = all.where((c) => !assignedIds.contains(c.id)).toList();
    return [...assigned, ...rest];
  }

  List<Lense> _sortedLenses(List<Lense> all, Set<int> assignedIds) {
    final assigned = all.where((l) => assignedIds.contains(l.id)).toList();
    final rest = all.where((l) => !assignedIds.contains(l.id)).toList();
    return [...assigned, ...rest];
  }

  List<Light> _sortedLights(List<Light> all, Set<int> assignedIds) {
    final assigned = all.where((l) => assignedIds.contains(l.id)).toList();
    final rest = all.where((l) => !assignedIds.contains(l.id)).toList();
    return [...assigned, ...rest];
  }

  Widget _buildDropdown<T>(
    BuildContext context,
    WidgetRef ref,
    AppPalette palette, {
    required List<T> items,
    required int? selectedId,
    required String label,
    required String Function(T) title,
    required String Function(T) subtitle,
    required String Function(T) chip,
  }) {
    int idOf(T item) => switch (item) {
          Camera c => c.id,
          Lense l => l.id,
          Light l => l.id,
          _ => 0,
        };

    if (items.isEmpty) {
      return Text('Catálogo vacío', style: AppTypography.caption(palette));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                decoration: InputDecoration(labelText: label),
                value: selectedId,
                items: items
                    .map((item) => DropdownMenuItem(
                          value: idOf(item),
                          child: Text(title(item), overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (id) async {
                  onSelected(id);
                  if (!syncToBible || id == null) return;
                  final db = ref.read(databaseProvider);
                  if (equipmentType == 'camera') {
                    await db.syncBiblePrimaryCamera(projectId, id);
                  } else if (equipmentType == 'lens') {
                    await db.syncBiblePrimaryLens(projectId, id);
                  }
                },
              ),
            ),
            IconButton(
              tooltip: 'Explorar por marca',
              icon: const Icon(Icons.account_tree_outlined),
              onPressed: () => _openHierarchicalPicker(
                context,
                ref,
                items: items,
                idOf: idOf,
                title: title,
              ),
            ),
          ],
        ),
        if (selectedId != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _EquipmentActions(
            projectId: projectId,
            equipmentType: equipmentType,
            equipmentId: selectedId!,
            chip: chip(items.firstWhere((i) => idOf(i) == selectedId)),
            subtitle: subtitle(items.firstWhere((i) => idOf(i) == selectedId)),
          ),
        ],
      ],
    );
  }

  Future<void> _openHierarchicalPicker<T>(
    BuildContext context,
    WidgetRef ref, {
    required List<T> items,
    required int Function(T) idOf,
    required String Function(T) title,
  }) async {
    String brandOf(T item) => switch (item) {
          Camera c => c.brand,
          Lense l => l.brand,
          Light l => l.brand,
          _ => 'Otro',
        };
    String seriesOf(T item) => switch (item) {
          Camera c => c.series ?? 'General',
          Lense l => l.series ?? 'General',
          Light l => l.series ?? 'General',
          _ => 'General',
        };

    final brands = items.map(brandOf).toSet().toList()..sort();
    if (!context.mounted) return;
    final brand = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Marca'),
        children: brands
            .map((b) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, b),
                  child: Text(b),
                ))
            .toList(),
      ),
    );
    if (brand == null || !context.mounted) return;

    final brandItems = items.where((i) => brandOf(i) == brand).toList();
    final series = brandItems.map(seriesOf).toSet().toList()..sort();
    final selectedSeries = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(brand),
        children: series
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, s),
                  child: Text(s),
                ))
            .toList(),
      ),
    );
    if (selectedSeries == null || !context.mounted) return;

    final seriesItems = brandItems.where((i) => seriesOf(i) == selectedSeries).toList()
      ..sort((a, b) => title(a).compareTo(title(b)));
    final picked = await showDialog<T>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('$brand · $selectedSeries'),
        children: seriesItems
            .map((item) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, item),
                  child: Text(title(item)),
                ))
            .toList(),
      ),
    );
    if (picked == null) return;
    final id = idOf(picked);
    onSelected(id);
    if (!syncToBible) return;
    final db = ref.read(databaseProvider);
    if (equipmentType == 'camera') {
      await db.syncBiblePrimaryCamera(projectId, id);
    } else if (equipmentType == 'lens') {
      await db.syncBiblePrimaryLens(projectId, id);
    }
  }
}

class _EquipmentActions extends ConsumerWidget {
  final int projectId;
  final String equipmentType;
  final int equipmentId;
  final String chip;
  final String subtitle;

  const _EquipmentActions({
    required this.projectId,
    required this.equipmentType,
    required this.equipmentId,
    required this.chip,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(chip, style: AppTypography.caption(palette)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(subtitle, style: AppTypography.caption(palette)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EquipmentDetailScreen(
                    projectId: projectId,
                    equipmentType: equipmentType,
                    equipmentId: equipmentId,
                  ),
                ),
              );
            },
            child: const Text('Ficha'),
          ),
          if (equipmentType == 'camera' || equipmentType == 'lens')
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OpticsLabScreen(
                      projectId: projectId,
                      initialCameraId: equipmentType == 'camera' ? equipmentId : null,
                      initialLensId: equipmentType == 'lens' ? equipmentId : null,
                    ),
                  ),
                );
              },
              child: const Text('FLT'),
            ),
        ],
      ),
    );
  }
}
