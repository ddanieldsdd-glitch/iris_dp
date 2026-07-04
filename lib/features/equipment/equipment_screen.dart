import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';

class EquipmentScreen extends ConsumerStatefulWidget {
  final int projectId;

  const EquipmentScreen({super.key, required this.projectId});

  @override
  ConsumerState<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends ConsumerState<EquipmentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('Equipo', style: AppTypography.titleMedium(palette)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: palette.accent,
          unselectedLabelColor: palette.textSecondary,
          indicatorColor: palette.accent,
          tabs: const [
            Tab(text: 'Cámaras'),
            Tab(text: 'Ópticas'),
            Tab(text: 'Luces'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _EquipmentList<Camera>(
            stream: db.watchAllCameras(),
            projectId: widget.projectId,
            type: 'camera',
            titleBuilder: (c) => '${c.brand} ${c.model}',
            subtitleBuilder: (c) =>
                'Sensor ${c.sensorWidthMm.toStringAsFixed(1)} × '
                '${c.sensorHeightMm.toStringAsFixed(1)} mm',
          ),
          _EquipmentList<Lense>(
            stream: db.watchAllLenses(),
            projectId: widget.projectId,
            type: 'lens',
            titleBuilder: (l) => '${l.brand} ${l.model}',
            subtitleBuilder: (l) {
              if (l.focalLength > 0) {
                return '${l.focalLength.toStringAsFixed(0)} mm · T${l.minTStop} · ${l.formatCoverage}';
              }
              return '${l.focalMin?.toStringAsFixed(0)}–${l.focalMax?.toStringAsFixed(0)} mm · '
                  'T${l.minTStop} · ${l.formatCoverage}';
            },
          ),
          _EquipmentList<Light>(
            stream: db.watchAllLights(),
            projectId: widget.projectId,
            type: 'light',
            titleBuilder: (l) => '${l.brand} ${l.model}',
            subtitleBuilder: (l) {
              final luka = l.isLukaCompatible ? ' · LUKA' : '';
              return '${l.powerW} W · ${l.colorTempMin}–${l.colorTempMax} K$luka';
            },
            trailingBuilder: (l) => l.isLukaCompatible
                ? _LukaBadge(palette: palette)
                : null,
          ),
        ],
      ),
    );
  }
}

class _EquipmentList<T extends Object> extends ConsumerWidget {
  final Stream<List<T>> stream;
  final int projectId;
  final String type;
  final String Function(T) titleBuilder;
  final String Function(T) subtitleBuilder;
  final Widget? Function(T)? trailingBuilder;

  const _EquipmentList({
    required this.stream,
    required this.projectId,
    required this.type,
    required this.titleBuilder,
    required this.subtitleBuilder,
    this.trailingBuilder,
  });

  int _equipmentId(T item) => switch (item) {
        Camera c => c.id,
        Lense l => l.id,
        Light l => l.id,
        _ => 0,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return Center(
            child: Text(
              'Catálogo vacío.',
              style: AppTypography.bodyMedium(palette),
            ),
          );
        }

        return StreamBuilder<List<ProjectEquipmentData>>(
          stream: db.watchProjectEquipment(projectId),
          builder: (context, assignSnap) {
            final assigned = assignSnap.data ?? [];
            final assignedIds = assigned
                .where((a) => a.equipmentType == type)
                .map((a) => a.equipmentId)
                .toSet();

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Catálogo global. Pulsa + para añadir al proyecto.',
                      style: AppTypography.caption(palette),
                    ),
                  );
                }
                final item = items[i - 1];
                final id = _equipmentId(item);
                final inProject = assignedIds.contains(id);

                return AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titleBuilder(item),
                              style: AppTypography.titleMedium(palette),
                            ),
                            Text(
                              subtitleBuilder(item),
                              style: AppTypography.bodyMedium(palette),
                            ),
                          ],
                        ),
                      ),
                      if (trailingBuilder != null) trailingBuilder!(item)!,
                      IconButton(
                        tooltip: inProject
                            ? 'Quitar del proyecto'
                            : 'Añadir al proyecto',
                        icon: Icon(
                          inProject ? Icons.check_circle : Icons.add_circle_outline,
                          color: inProject ? palette.accent : palette.textSecondary,
                        ),
                        onPressed: () async {
                          if (inProject) {
                            final row = assigned.firstWhere(
                              (a) =>
                                  a.equipmentType == type &&
                                  a.equipmentId == id,
                            );
                            await db.unassignProjectEquipment(row.id);
                          } else {
                            await db.assignEquipmentToProject(
                              projectId: projectId,
                              equipmentType: type,
                              equipmentId: id,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LukaBadge extends StatelessWidget {
  final AppPalette palette;

  const _LukaBadge({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'LUKA',
        style: AppTypography.caption(palette).copyWith(
          color: palette.accent,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}
