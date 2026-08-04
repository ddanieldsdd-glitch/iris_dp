import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'optics_calculator.dart';

/// Preview con imagen de referencia y overlay de encuadre FOV.
class FltReferencePreview extends StatefulWidget {
  final OpticsResult result;
  final double aspectRatio;
  final bool isAnamorphic;
  final double squeezeRatio;
  final String? initialImagePath;
  final ValueChanged<String?>? onImagePathChanged;
  final VoidCallback? onSaveCapture;

  const FltReferencePreview({
    super.key,
    required this.result,
    required this.aspectRatio,
    this.isAnamorphic = false,
    this.squeezeRatio = 2.0,
    this.initialImagePath,
    this.onImagePathChanged,
    this.onSaveCapture,
  });

  @override
  State<FltReferencePreview> createState() => _FltReferencePreviewState();
}

class _FltReferencePreviewState extends State<FltReferencePreview> {
  String? _imagePath;
  bool _showGate = true;
  bool _showFullFov = true;
  bool _applyDesqueeze = false;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.initialImagePath;
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    setState(() => _imagePath = result.files.single.path);
    widget.onImagePathChanged?.call(_imagePath);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final effectiveAspect = widget.isAnamorphic && _applyDesqueeze
        ? widget.aspectRatio * widget.squeezeRatio
        : widget.aspectRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Preview referencia', style: AppTypography.titleMedium(palette)),
            const Spacer(),
            IconButton(
              tooltip: 'Cargar imagen',
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: _pickImage,
            ),
            if (widget.onSaveCapture != null)
              IconButton(
                tooltip: 'Guardar captura',
                icon: const Icon(Icons.save_alt_outlined),
                onPressed: widget.onSaveCapture,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('Gate'),
              selected: _showGate,
              onSelected: (v) => setState(() => _showGate = v),
            ),
            FilterChip(
              label: const Text('Encuadre FOV'),
              selected: _showFullFov,
              onSelected: (v) => setState(() => _showFullFov = v),
            ),
            if (widget.isAnamorphic)
              FilterChip(
                label: const Text('Desqueeze'),
                selected: _applyDesqueeze,
                onSelected: (v) => setState(() => _applyDesqueeze = v),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: AspectRatio(
            aspectRatio: effectiveAspect.clamp(0.5, 3.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_imagePath != null && File(_imagePath!).existsSync())
                      Image.file(File(_imagePath!), fit: BoxFit.cover)
                    else
                      Center(
                        child: TextButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Añadir imagen de referencia'),
                        ),
                      ),
                    if (_showFullFov) _FovOverlay(result: widget.result),
                    if (_showGate)
                      CustomPaint(
                        painter: _GateOverlayPainter(
                          aspectRatio: effectiveAspect,
                          color: const Color(0xAA00C853),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'HFOV ${widget.result.hFovDeg.toStringAsFixed(1)}° · '
          'DFOV ${widget.result.dFovDeg.toStringAsFixed(1)}°',
          style: AppTypography.caption(palette),
        ),
      ],
    );
  }
}

class _FovOverlay extends StatelessWidget {
  final OpticsResult result;

  const _FovOverlay({required this.result});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FovFramePainter(hFovDeg: result.hFovDeg),
      child: const SizedBox.expand(),
    );
  }
}

class _FovFramePainter extends CustomPainter {
  final double hFovDeg;

  _FovFramePainter({required this.hFovDeg});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final halfRad = (hFovDeg / 2) * math.pi / 180;
    final depth = size.height * 0.45;
    final halfWidth = depth * math.tan(halfRad);

    final path = Path()
      ..moveTo(cx - halfWidth, cy - depth / 2)
      ..lineTo(cx + halfWidth, cy - depth / 2)
      ..lineTo(cx + halfWidth * 1.2, cy + depth / 2)
      ..lineTo(cx - halfWidth * 1.2, cy + depth / 2)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xCCFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _FovFramePainter oldDelegate) =>
      oldDelegate.hFovDeg != hFovDeg;
}

class _GateOverlayPainter extends CustomPainter {
  final double aspectRatio;
  final Color color;

  _GateOverlayPainter({required this.aspectRatio, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final containerAr = size.width / size.height;
    Rect gate;
    if (aspectRatio >= containerAr) {
      final h = size.height;
      final w = h * aspectRatio;
      gate = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: w.clamp(0, size.width),
        height: h,
      );
    } else {
      final w = size.width;
      final h = w / aspectRatio;
      gate = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: w,
        height: h.clamp(0, size.height),
      );
    }
    canvas.drawRect(
      gate,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _GateOverlayPainter oldDelegate) =>
      oldDelegate.aspectRatio != aspectRatio;
}
