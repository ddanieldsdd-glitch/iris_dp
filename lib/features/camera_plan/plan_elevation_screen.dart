import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/export_file_saver.dart';
import '../../core/widgets/app_snackbar.dart';
import 'camera_plan_element_model.dart';
import 'plan_cad_export.dart';
import 'plan_elevation.dart';

/// La planta levantada en altura, de frente o de lado, y su exportación a
/// DXF (CAD) y MVR (iluminación).
Future<void> showPlanElevation(
  BuildContext context, {
  required List<PlanElement> elements,
  required double metersPerUnit,
  required String name,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => PlanElevationScreen(
      elements: elements,
      metersPerUnit: metersPerUnit,
      name: name,
    ),
  ),
);

class PlanElevationScreen extends StatefulWidget {
  final List<PlanElement> elements;
  final double metersPerUnit;

  /// Nombre de la planta, para los archivos.
  final String name;

  const PlanElevationScreen({
    super.key,
    required this.elements,
    required this.metersPerUnit,
    required this.name,
  });

  @override
  State<PlanElevationScreen> createState() => _PlanElevationScreenState();
}

class _PlanElevationScreenState extends State<PlanElevationScreen> {
  ElevationSide _side = ElevationSide.front;

  PlanElevation get _elevation => PlanElevation.of(
    widget.elements,
    metersPerUnit: widget.metersPerUnit,
    side: _side,
  );

  String get _base =>
      widget.name.trim().isEmpty ? 'planta' : widget.name.trim();

  Future<void> _save(
    Uint8List bytes,
    String suffix,
    String extension,
    String what,
  ) async {
    try {
      final path = await ExportFileSaver.saveBytes(
        bytes: bytes,
        dialogTitle: 'Guardar $what',
        fileName: '$_base $suffix',
        extension: extension,
      );
      if (path != null && mounted) {
        AppSnackBar.show(context, '$what guardado.');
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, 'No se pudo guardar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final elevation = _elevation;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Alzado y perfil'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Exportar',
            icon: const Icon(Icons.ios_share),
            onSelected: (choice) => switch (choice) {
              'dxf-plan' => _save(
                utf8.encode(
                  PlanCadExport.planDxf(widget.elements, widget.metersPerUnit),
                ),
                'planta',
                'dxf',
                'DXF de la planta',
              ),
              'dxf-view' => _save(
                utf8.encode(PlanCadExport.elevationDxf(elevation)),
                _side.label.toLowerCase(),
                'dxf',
                'DXF del ${_side.label.toLowerCase()}',
              ),
              _ => _save(
                PlanCadExport.planMvr(
                  widget.elements,
                  widget.metersPerUnit,
                  layerName: _base,
                ),
                'luces',
                'mvr',
                'MVR de las luces',
              ),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'dxf-plan',
                child: ListTile(
                  dense: true,
                  title: Text('Planta en DXF'),
                  subtitle: Text('Para AutoCAD, Vectorworks o LibreCAD'),
                ),
              ),
              PopupMenuItem(
                value: 'dxf-view',
                child: ListTile(
                  dense: true,
                  title: Text('${_side.label} en DXF'),
                  subtitle: const Text('Lo que se ve aquí, en metros'),
                ),
              ),
              const PopupMenuItem(
                value: 'mvr',
                child: ListTile(
                  dense: true,
                  title: Text('Luces en MVR'),
                  subtitle: Text(
                    'Para Vectorworks Spotlight, grandMA3, Capture o '
                    'WYSIWYG: posición, altura, giro y unidad',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SegmentedButton<ElevationSide>(
                  segments: [
                    for (final s in ElevationSide.values)
                      ButtonSegment(value: s, label: Text(s.label)),
                  ],
                  selected: {_side},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _side = s.first),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Visto ${_side.hint}. Las alturas que la planta no dice '
                    'son las de siempre: paredes a su techo o 2,5 m, luces '
                    'en pie a 2 m, cámara a 1,5 m y personas de 1,7 m.',
                    style: AppTypography.caption(
                      palette,
                    ).copyWith(color: palette.textTertiary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: elevation.items.isEmpty
                    ? Center(
                        child: Text(
                          'La planta está vacía.',
                          style: AppTypography.bodyMedium(palette),
                        ),
                      )
                    : CustomPaint(
                        painter: PlanElevationPainter(
                          elevation: elevation,
                          ink: palette.textPrimary,
                          faint: palette.textTertiary,
                          background: palette.surface,
                          accent: palette.accent,
                        ),
                        child: const SizedBox.expand(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
