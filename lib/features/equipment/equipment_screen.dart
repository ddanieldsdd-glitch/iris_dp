import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/export_file_saver.dart';
import '../../core/widgets/app_snackbar.dart';
import '../luka_export/luka_manifest_service.dart';
import '../optics_lab/optics_lab_screen.dart';
import '../storage_calculator/storage_calculator_screen.dart';
import 'equipment_detail_screen.dart';
import 'equipment_spec_helpers.dart';
import 'services/catalog_sync_service.dart';
import 'services/equipment_spreadsheet_service.dart';
import 'widgets/equipment_brand_grouped_list.dart';
import 'widgets/equipment_import_sheet.dart';
import 'widgets/lens_set_grouped_list.dart';

class EquipmentScreen extends ConsumerStatefulWidget {
  final int projectId;

  const EquipmentScreen({super.key, required this.projectId});

  @override
  ConsumerState<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends ConsumerState<EquipmentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String? _syncMessage;
  String? _cameraFilter;
  String? _lensFilter;
  String? _lightFilter;
  bool _vintageOnly = false;
  bool _lukaOnly = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCatalog());
  }

  Future<void> _ensureCatalog() async {
    final db = ref.read(databaseProvider);
    final result = await CatalogSyncService(db).importEmbeddedCatalog(force: true);
    await LukaManifestService(db).recordSyncCheck();
    if (mounted) setState(() => _syncMessage = result.message);
  }

  Future<void> _checkRemote() async {
    final db = ref.read(databaseProvider);
    final result = await CatalogSyncService(db).checkRemoteUpdates();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Sin cambios')),
      );
    }
  }

  Future<void> _exportEquipmentList() async {
    final db = ref.read(databaseProvider);
    final project = await db.getProject(widget.projectId);
    final projectSlug = (project?.name ?? 'proyecto')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final fileName = 'equipo_${projectSlug}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    try {
      final bytes = await EquipmentSpreadsheetService(db).exportProjectEquipment(
        projectId: widget.projectId,
        projectName: project?.name,
      );

      final savedPath = await ExportFileSaver.saveBytes(
        dialogTitle: 'Exportar lista de equipo',
        fileName: fileName,
        extension: 'xlsx',
        bytes: bytes,
      );

      if (!mounted) return;

      if (savedPath != null) {
        AppSnackBar.show(context, 'Lista exportada');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Error al exportar: $e', isError: true);
      }
    }
  }

  Future<void> _importEquipmentList() async {
    try {
      final result = await UserFilePicker.pickFiles(
        dialogTitle: 'Importar lista de equipo',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      final db = ref.read(databaseProvider);
      final service = EquipmentSpreadsheetService(db);
      final data = service.parseBytes(bytes);

      if (!mounted) return;

      final preview = await service.buildPreview(
        projectId: widget.projectId,
        data: data,
      );

      if (!mounted) return;

      final applied = await showEquipmentImportSheet(
        context,
        preview: preview,
        onApply: () => service.applyImport(
          projectId: widget.projectId,
          data: data,
        ),
      );

      if (applied == true && mounted) {
        AppSnackBar.show(context, 'Lista de equipo actualizada');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Error al importar: $e', isError: true);
      }
    }
  }

  Future<void> _shareExportedTemplate() async {
    final db = ref.read(databaseProvider);
    try {
      final bytes = await EquipmentSpreadsheetService(db).exportProjectEquipment(
        projectId: widget.projectId,
      );
      final dir = await Directory.systemTemp.createTemp('iris_equipo_');
      final file = File('${dir.path}/equipo_proyecto.xlsx');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Lista de equipo IRIS DP');
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Error al compartir: $e', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Widget _filterBar(AppPalette palette, List<String> chips, String? value, ValueChanged<String?> onChanged) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Vintage'),
            selected: _vintageOnly,
            onSelected: (v) => setState(() => _vintageOnly = v),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('LUKA'),
            selected: _lukaOnly,
            onSelected: (v) => setState(() => _lukaOnly = v),
          ),
          const SizedBox(width: 8),
          ...chips.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(c),
                  selected: value == c,
                  onSelected: (sel) => onChanged(sel ? c : null),
                ),
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('Equipo', style: AppTypography.titleMedium(palette)),
        actions: [
          IconButton(
            tooltip: 'Buscar actualizaciones de catálogo',
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: _checkRemote,
          ),
          PopupMenuButton<String>(
            tooltip: 'Importar / exportar',
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportEquipmentList();
                case 'import':
                  _importEquipmentList();
                case 'share':
                  _shareExportedTemplate();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.upload_file_outlined),
                  title: Text('Exportar a Excel'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.download_outlined),
                  title: Text('Importar desde Excel'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share_outlined),
                  title: Text('Compartir lista'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: palette.accent,
          unselectedLabelColor: palette.textSecondary,
          indicatorColor: palette.accent,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Cámaras'),
            Tab(text: 'Ópticas'),
            Tab(text: 'Luces'),
            Tab(text: 'Laboratorio óptico'),
            Tab(text: 'Almacenamiento'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_syncMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              color: palette.surfaceElevated,
              child: Text(_syncMessage!, style: AppTypography.caption(palette)),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                StreamBuilder<List<Camera>>(
                  stream: db.watchAllCameras(),
                  builder: (context, snap) {
                    final items = snap.data ?? [];
                    final mounts = items.map((c) => c.mountType).whereType<String>().toSet().toList()..sort();
                    return Column(
                      children: [
                        _filterBar(palette, mounts, _cameraFilter, (v) => setState(() => _cameraFilter = v)),
                        Expanded(
                          child: StreamBuilder<List<ProjectEquipmentData>>(
                            stream: db.watchProjectEquipment(widget.projectId),
                            builder: (context, assignSnap) {
                              final assigned = assignSnap.data ?? [];
                              final assignedIds = assigned
                                  .where((a) => a.equipmentType == 'camera')
                                  .map((a) => a.equipmentId)
                                  .toSet();
                              final customIds = items.where((c) => c.isCustom).map((c) => c.id).toSet();
                              return EquipmentBrandGroupedList<Camera>(
                                items: items,
                                assignedIds: assignedIds,
                                customIds: customIds,
                                activeFilter: _cameraFilter,
                                vintageOnly: _vintageOnly,
                                lukaOnly: _lukaOnly,
                                idOf: (c) => c.id,
                                brandOf: (c) => c.brand,
                                seriesOf: (c) => c.series,
                                titleOf: (c) => '${c.brand} ${c.model}',
                                subtitleOf: cameraListSubtitle,
                                filterOf: (c) => c.mountType,
                                onTap: (c) => _openDetail(context, 'camera', c.id),
                                onToggleAssign: (c) => _toggleAssign(db, 'camera', c.id, assignedIds.contains(c.id), assigned),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                StreamBuilder<List<Lense>>(
                  stream: db.watchAllLenses(),
                  builder: (context, snap) {
                    final items = snap.data ?? [];
                    final coverages = items.map((l) => l.formatCoverage).toSet().toList()..sort();
                    return Column(
                      children: [
                        _filterBar(palette, coverages, _lensFilter, (v) => setState(() => _lensFilter = v)),
                        Expanded(
                          child: StreamBuilder<List<ProjectEquipmentData>>(
                            stream: db.watchProjectEquipment(widget.projectId),
                            builder: (context, assignSnap) {
                              final assigned = assignSnap.data ?? [];
                              final assignedIds = assigned
                                  .where((a) => a.equipmentType == 'lens')
                                  .map((a) => a.equipmentId)
                                  .toSet();
                              final customIds = items.where((l) => l.isCustom).map((l) => l.id).toSet();
                              return LensSetGroupedList(
                                items: items,
                                assignedIds: assignedIds,
                                customIds: customIds,
                                activeFilter: _lensFilter,
                                vintageOnly: _vintageOnly,
                                lukaOnly: _lukaOnly,
                                onTap: (l) => _openDetail(context, 'lens', l.id),
                                onToggleAssign: (l) => _toggleAssign(db, 'lens', l.id, assignedIds.contains(l.id), assigned),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                StreamBuilder<List<Light>>(
                  stream: db.watchAllLights(),
                  builder: (context, snap) {
                    final items = snap.data ?? [];
                    final types = items.map((l) => l.lightType).toSet().toList()..sort();
                    return Column(
                      children: [
                        _filterBar(palette, types, _lightFilter, (v) => setState(() => _lightFilter = v)),
                        Expanded(
                          child: StreamBuilder<List<ProjectEquipmentData>>(
                            stream: db.watchProjectEquipment(widget.projectId),
                            builder: (context, assignSnap) {
                              final assigned = assignSnap.data ?? [];
                              final assignedIds = assigned
                                  .where((a) => a.equipmentType == 'light')
                                  .map((a) => a.equipmentId)
                                  .toSet();
                              final customIds = items.where((l) => l.isCustom).map((l) => l.id).toSet();
                              return EquipmentBrandGroupedList<Light>(
                                items: items,
                                assignedIds: assignedIds,
                                customIds: customIds,
                                activeFilter: _lightFilter,
                                vintageOnly: _vintageOnly,
                                lukaOnly: _lukaOnly,
                                idOf: (l) => l.id,
                                brandOf: (l) => l.brand,
                                seriesOf: (l) => l.series,
                                titleOf: (l) => '${l.brand} ${l.model}',
                                subtitleOf: lightListSubtitle,
                                filterOf: (l) => l.lightType,
                                trailingBuilder: (l) => l.isLukaCompatible
                                    ? _LukaBadge(palette: palette)
                                    : null,
                                onTap: (l) => _openDetail(context, 'light', l.id),
                                onToggleAssign: (l) => _toggleAssign(db, 'light', l.id, assignedIds.contains(l.id), assigned),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                OpticsLabScreen(
                  projectId: widget.projectId,
                  showSaveToBible: true,
                  embedded: true,
                ),
                StorageCalculatorScreen(projectId: widget.projectId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, String type, int id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EquipmentDetailScreen(
          projectId: widget.projectId,
          equipmentType: type,
          equipmentId: id,
        ),
      ),
    );
  }

  Future<void> _toggleAssign(
    AppDatabase db,
    String type,
    int id,
    bool inProject,
    List<ProjectEquipmentData> assigned,
  ) async {
    if (inProject) {
      final row = assigned.firstWhere(
        (a) => a.equipmentType == type && a.equipmentId == id,
      );
      await db.unassignProjectEquipment(row.id);
    } else {
      await db.assignEquipmentToProject(
        projectId: widget.projectId,
        equipmentType: type,
        equipmentId: id,
      );
    }
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
