import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/location_scan_metadata.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../camera_plan/camera_plan_editor.dart';
import '../luka_export/luka_bridge_screen.dart';
import 'cinetracer_export_service.dart';
import 'location_scan_service.dart';
import '../../core/widgets/app_snackbar.dart';

/// Panel unificado: scan → planta 2D / modelo 3D / Unreal / Cine Tracer.
class LocationScanPanel extends ConsumerStatefulWidget {
  final int projectId;
  final LocationBasePlan set;
  final List<Scene> setScenes;

  const LocationScanPanel({
    super.key,
    required this.projectId,
    required this.set,
    required this.setScenes,
  });

  @override
  ConsumerState<LocationScanPanel> createState() => _LocationScanPanelState();
}

class _LocationScanPanelState extends ConsumerState<LocationScanPanel> {
  late LocationBasePlan _set;
  bool _busy = false;
  double _metersPerPixel = 0.01;

  LocationScanService get _scanService =>
      LocationScanService(ref.read(databaseProvider));

  LocationScanMetadata get _meta =>
      LocationScanMetadata.fromJson(_set.scanMetadataJson);

  bool get _hasScan =>
      (_set.scanPath != null && _set.scanPath!.isNotEmpty) ||
      (_set.model3dPath != null && _set.model3dPath!.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _set = widget.set;
    _metersPerPixel = _meta.metersPerPixel;
  }

  Future<void> _refreshSet() async {
    final updated = await ref.read(databaseProvider).getLocationById(_set.id);
    if (updated != null && mounted) {
      setState(() {
        _set = updated;
        _metersPerPixel = LocationScanMetadata.fromJson(_set.scanMetadataJson)
            .metersPerPixel;
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _refreshSet();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importScan() async {
    final path = await LocationScanService.pickScanFile();
    if (path == null) return;

    await _scanService.importScanForSet(
      projectId: widget.projectId,
      set: _set,
      sourcePath: path,
    );
  }

  Future<void> _importTopDown() async {
    final path = await LocationScanService.pickTopDownImage();
    if (path == null) return;

    await _scanService.importTopDownForSet(
      projectId: widget.projectId,
      set: _set,
      sourcePath: path,
      metersPerPixel: _metersPerPixel,
    );
  }

  Future<void> _toggleFloorPlanBackground(bool value) async {
    await _scanService.enableTopDownInFloorPlan(
      set: _set,
      enabled: value,
      metersPerPixel: _metersPerPixel,
    );
  }

  Future<void> _exportCineTracer() async {
    final db = ref.read(databaseProvider);
    final project = await db.getProject(widget.projectId);
    if (project == null) return;

    final path = await CineTracerExportService(db).saveSetExport(
      project: project,
      set: _set,
      scenes: widget.setScenes,
      canvasScale: _metersPerPixel,
    );

    if (!mounted || path == null) return;
    AppSnackBar.show(context, 'Export Cine Tracer guardado');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final meta = _meta;
    final previewPath = meta.topDownImagePath ?? meta.previewImagePath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Scan de localización', style: AppTypography.titleMedium(palette)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Un solo scan alimenta la planta cenital, la vista 3D, '
          'Unreal + LUKA y Cine Tracer.',
          style: AppTypography.caption(palette),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusRow(
                icon: Icons.view_in_ar_outlined,
                label: 'Scan 3D',
                value: _hasScan
                    ? LocationScanSource.label(_set.scanSource)
                    : 'Sin importar',
                detail: _set.scanPath?.split('/').last ??
                    _set.model3dPath?.split('/').last,
              ),
              if (meta.hasTopDown) ...[
                const SizedBox(height: AppSpacing.sm),
                _StatusRow(
                  icon: Icons.grid_on_outlined,
                  label: 'Planta cenital',
                  value: '${meta.widthMeters.toStringAsFixed(1)} × '
                      '${meta.heightMeters.toStringAsFixed(1)} m',
                  detail: meta.topDownImagePath?.split('/').last,
                ),
              ],
            ],
          ),
        ),
        if (previewPath != null && File(previewPath).existsSync()) ...[
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.file(File(previewPath), fit: BoxFit.contain),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppButton(
              label: _busy ? '…' : 'Importar scan',
              icon: Icons.upload_file_outlined,
              variant: AppButtonVariant.secondary,
              onTap: _busy ? null : () => _run(_importScan),
            ),
            AppButton(
              label: 'Planta cenital',
              icon: Icons.map_outlined,
              variant: AppButtonVariant.secondary,
              onTap: _busy ? null : () => _run(_importTopDown),
            ),
            if (_set.model3dPath != null)
              AppButton(
                label: 'Abrir 3D',
                icon: Icons.open_in_new,
                variant: AppButtonVariant.ghost,
                onTap: () => LocationScanService.openFileExternally(
                  _set.model3dPath!,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Escala real', style: AppTypography.label(palette)),
        Text(
          '1 px = ${_metersPerPixel}m (${(_metersPerPixel * 100).toStringAsFixed(0)} cm)',
          style: AppTypography.caption(palette),
        ),
        Slider(
          value: _metersPerPixel,
          min: 0.005,
          max: 0.05,
          divisions: 9,
          onChanged: meta.hasTopDown
              ? (v) => setState(() => _metersPerPixel = v)
              : null,
          onChangeEnd: meta.hasTopDown
              ? (v) => _run(() async {
                    await _scanService.enableTopDownInFloorPlan(
                      set: _set,
                      metersPerPixel: v,
                    );
                  })
              : null,
        ),
        if (meta.hasTopDown)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Usar scan como fondo de planta 2D',
              style: AppTypography.bodyMedium(palette),
            ),
            subtitle: Text(
              'Visible en el editor de planta de cámara del set.',
              style: AppTypography.caption(palette),
            ),
            value: meta.useTopDownInFloorPlan,
            onChanged: _busy
                ? null
                : (v) => _run(() => _toggleFloorPlanBackground(v)),
          ),
        const SizedBox(height: AppSpacing.md),
        Text('Destinos', style: AppTypography.label(palette)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _DestinationChip(
              icon: Icons.videocam_outlined,
              label: 'Planta 2D',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CameraPlanEditor.set(
                      projectId: widget.projectId,
                      setId: _set.id,
                      setName: _set.locationName,
                    ),
                  ),
                );
              },
            ),
            _DestinationChip(
              icon: Icons.view_in_ar_outlined,
              label: 'Unreal + LUKA',
              onTap: () async {
                final db = ref.read(databaseProvider);
                final project = await db.getProject(widget.projectId);
                if (!context.mounted || project == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LukaBridgeScreen(
                      projectId: widget.projectId,
                      projectName: project.name,
                    ),
                  ),
                );
              },
            ),
            _DestinationChip(
              icon: Icons.movie_filter_outlined,
              label: 'Cine Tracer',
              onTap: _busy ? null : _exportCineTracer,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Unreal: importa .ply/.luma con Luma AI. Cine Tracer: usa el JSON '
          'con el scan como entorno. Planta 2D: coloca cámaras sobre la vista cenital.',
          style: AppTypography.caption(palette),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? detail;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.accent),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.caption(palette)),
              Text(value, style: AppTypography.bodyMedium(palette)),
              if (detail != null && detail!.isNotEmpty)
                Text(
                  detail!,
                  style: AppTypography.caption(palette),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DestinationChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _DestinationChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ActionChip(
      avatar: Icon(icon, size: 16, color: palette.accent),
      label: Text(label, style: AppTypography.caption(palette)),
      backgroundColor: palette.accent.withValues(alpha: 0.08),
      side: BorderSide(color: palette.accent.withValues(alpha: 0.3)),
      onPressed: onTap,
    );
  }
}
