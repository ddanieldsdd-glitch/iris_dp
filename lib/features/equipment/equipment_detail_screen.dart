import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../luka_export/luka_compatibility_service.dart';
import '../luka_export/luka_manifest_service.dart';
import '../luka_export/luka_manual_setup_sheet.dart';
import '../optics_lab/optics_lab_screen.dart';
import 'equipment_spec_helpers.dart';

class EquipmentDetailScreen extends ConsumerStatefulWidget {
  final int projectId;
  final String equipmentType;
  final int equipmentId;

  const EquipmentDetailScreen({
    super.key,
    required this.projectId,
    required this.equipmentType,
    required this.equipmentId,
  });

  @override
  ConsumerState<EquipmentDetailScreen> createState() =>
      _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends ConsumerState<EquipmentDetailScreen> {
  bool _assigned = false;
  bool _loading = true;
  LukaCompatReport? _lukaReport;

  @override
  void initState() {
    super.initState();
    _checkAssigned();
    _loadLukaReport();
  }

  Future<void> _checkAssigned() async {
    final db = ref.read(databaseProvider);
    _assigned = await db.isEquipmentAssigned(
      projectId: widget.projectId,
      equipmentType: widget.equipmentType,
      equipmentId: widget.equipmentId,
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadLukaReport() async {
    final db = ref.read(databaseProvider);
    final item = await _loadItem(db);
    if (item == null) return;
    final svc = await LukaCompatibilityService.create(LukaManifestService(db));
    _lukaReport = switch (item) {
      Camera c => svc.evaluateCamera(c),
      Lense l => svc.evaluateLens(l),
      Light l => svc.evaluateLight(l),
      _ => null,
    };
    if (mounted) setState(() {});
  }

  Future<void> _toggleAssign() async {
    final db = ref.read(databaseProvider);
    if (_assigned) {
      final rows = await db.watchProjectEquipment(widget.projectId).first;
      final row = rows.firstWhere(
        (r) =>
            r.equipmentType == widget.equipmentType &&
            r.equipmentId == widget.equipmentId,
      );
      await db.unassignProjectEquipment(row.id);
      await db.maybeReconcilePrimaryOnEquipmentUnassign(
        projectId: widget.projectId,
        equipmentType: widget.equipmentType,
        equipmentId: widget.equipmentId,
      );
    } else {
      await db.assignEquipmentToProject(
        projectId: widget.projectId,
        equipmentType: widget.equipmentType,
        equipmentId: widget.equipmentId,
      );
      await db.maybePromotePrimaryOnEquipmentAssign(
        projectId: widget.projectId,
        equipmentType: widget.equipmentType,
        equipmentId: widget.equipmentId,
      );
    }
    await _checkAssigned();
  }

  Future<void> _setPrimaryInBible() async {
    final db = ref.read(databaseProvider);
    if (widget.equipmentType == 'camera') {
      await db.syncBiblePrimaryCamera(widget.projectId, widget.equipmentId);
    } else if (widget.equipmentType == 'lens') {
      await db.syncBiblePrimaryLens(widget.projectId, widget.equipmentId);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Establecido como principal en la Biblia')),
      );
    }
  }

  Future<void> _duplicateAsCustom() async {
    final db = ref.read(databaseProvider);
    switch (widget.equipmentType) {
      case 'camera':
        final cam = await db.getCameraById(widget.equipmentId);
        if (cam == null) return;
        await db.insertCamera(CamerasCompanion.insert(
          brand: cam.brand,
          model: '${cam.model} (custom)',
          sensorWidthMm: cam.sensorWidthMm,
          sensorHeightMm: cam.sensorHeightMm,
          mountType: Value(cam.mountType),
          sensorModesJson: Value(cam.sensorModesJson),
          dynamicRangeStops: Value(cam.dynamicRangeStops),
          colorScience: Value(cam.colorScience),
          nativeIso: Value(cam.nativeIso),
          logFormats: Value(cam.logFormats),
          series: Value(cam.series),
          lukaProfileJson: Value(cam.lukaProfileJson),
          isCustom: const Value(true),
        ));
      case 'lens':
        final lens = await db.getLensById(widget.equipmentId);
        if (lens == null) return;
        await db.insertLens(LensesCompanion.insert(
          brand: lens.brand,
          model: '${lens.model} (custom)',
          focalLength: lens.focalLength,
          focalMin: Value(lens.focalMin),
          focalMax: Value(lens.focalMax),
          minTStop: lens.minTStop,
          formatCoverage: lens.formatCoverage,
          mountType: Value(lens.mountType),
          imageCircleMm: Value(lens.imageCircleMm),
          isAnamorphic: Value(lens.isAnamorphic),
          squeezeRatio: Value(lens.squeezeRatio),
          lensType: Value(lens.lensType),
          series: Value(lens.series),
          lukaProfileJson: Value(lens.lukaProfileJson),
          isCustom: const Value(true),
        ));
      case 'light':
        final light = await db.getLightById(widget.equipmentId);
        if (light == null) return;
        await db.insertLight(LightsCompanion.insert(
          brand: light.brand,
          model: '${light.model} (custom)',
          lightType: light.lightType,
          powerW: light.powerW,
          colorTempMin: light.colorTempMin,
          colorTempMax: light.colorTempMax,
          beamAngleDeg: Value(light.beamAngleDeg),
          cri: Value(light.cri),
          tlci: Value(light.tlci),
          series: Value(light.series),
          lukaProfileJson: Value(light.lukaProfileJson),
          isCustom: const Value(true),
        ));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duplicado como equipo custom')),
      );
    }
  }

  Future<void> _deleteCustom() async {
    final db = ref.read(databaseProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar equipo custom'),
        content: const Text('¿Eliminar este equipo custom del catálogo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;

    switch (widget.equipmentType) {
      case 'camera':
        await db.deleteCamera(widget.equipmentId);
      case 'lens':
        await db.deleteLens(widget.equipmentId);
      case 'light':
        await db.deleteLight(widget.equipmentId);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _saveLukaProfile(Map<String, dynamic> profile) async {
    final db = ref.read(databaseProvider);
    final jsonStr = jsonEncode(profile);
    switch (widget.equipmentType) {
      case 'camera':
        final cam = await db.getCameraById(widget.equipmentId);
        if (cam == null) return;
        await db.updateCamera(cam.copyWith(lukaProfileJson: Value(jsonStr)));
      case 'lens':
        final lens = await db.getLensById(widget.equipmentId);
        if (lens == null) return;
        await db.updateLens(lens.copyWith(lukaProfileJson: Value(jsonStr)));
      case 'light':
        final light = await db.getLightById(widget.equipmentId);
        if (light == null) return;
        await db.updateLight(light.copyWith(lukaProfileJson: Value(jsonStr)));
    }
    await _loadLukaReport();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ficha de equipo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('Ficha de equipo', style: AppTypography.titleMedium(palette)),
      ),
      body: FutureBuilder<Object?>(
        future: _loadItem(db),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final item = snap.data!;
          final isCustom = switch (item) {
            Camera c => c.isCustom,
            Lense l => l.isCustom,
            Light l => l.isCustom,
            _ => false,
          };

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(_title(item), style: AppTypography.titleMedium(palette)),
                        ),
                        if (_lukaReport != null) LukaCompatBadge(report: _lukaReport!),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ..._specSections(item).expand((section) => [
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 4),
                            child: Text(
                              section.title,
                              style: AppTypography.titleMedium(palette).copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          ...section.rows.map(
                            (row) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 140,
                                    child: Text(
                                      row.label,
                                      style: AppTypography.caption(palette).copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      row.value,
                                      style: AppTypography.bodyMedium(palette),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ]),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _toggleAssign,
                    icon: Icon(_assigned ? Icons.check : Icons.add),
                    label: Text(_assigned ? 'En proyecto' : 'Asignar al proyecto'),
                  ),
                  OutlinedButton(
                    onPressed: _setPrimaryInBible,
                    child: const Text('Usar en Biblia'),
                  ),
                  if (widget.equipmentType == 'camera' || widget.equipmentType == 'lens')
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => OpticsLabScreen(
                              projectId: widget.projectId,
                              initialCameraId:
                                  widget.equipmentType == 'camera' ? widget.equipmentId : null,
                              initialLensId:
                                  widget.equipmentType == 'lens' ? widget.equipmentId : null,
                            ),
                          ),
                        );
                      },
                      child: const Text('Laboratorio óptico'),
                    ),
                  if (_lukaReport != null &&
                      _lukaReport!.level != LukaCompatLevel.full)
                    OutlinedButton(
                      onPressed: () => LukaManualSetupSheet.show(
                        context,
                        equipmentType: widget.equipmentType,
                        item: item,
                        report: _lukaReport!,
                        onSave: _saveLukaProfile,
                      ),
                      child: const Text('Ficha manual LUKA'),
                    ),
                  OutlinedButton(
                    onPressed: _duplicateAsCustom,
                    child: const Text('Duplicar como custom'),
                  ),
                  if (isCustom)
                    OutlinedButton(
                      onPressed: _deleteCustom,
                      child: const Text('Eliminar custom'),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Object?> _loadItem(AppDatabase db) async {
    return switch (widget.equipmentType) {
      'camera' => db.getCameraById(widget.equipmentId),
      'lens' => db.getLensById(widget.equipmentId),
      'light' => db.getLightById(widget.equipmentId),
      _ => null,
    };
  }

  String _title(Object item) => switch (item) {
        Camera c => '${c.brand} ${c.model}',
        Lense l => '${l.brand} ${l.model}',
        Light l => '${l.brand} ${l.model}',
        _ => 'Equipo',
      };

  List<EquipmentSpecSection> _specSections(Object item) => switch (item) {
        Camera c => cameraSpecSections(c),
        Lense l => lensSpecSections(l),
        Light l => lightSpecSections(l),
        _ => const [],
      };
}
