import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../services/exposure_overlay_service.dart';

/// Preview con overlay de falso color o zebra.
class ExposureOverlayPreview extends StatefulWidget {
  final String imagePath;

  const ExposureOverlayPreview({super.key, required this.imagePath});

  @override
  State<ExposureOverlayPreview> createState() => _ExposureOverlayPreviewState();
}

class _ExposureOverlayPreviewState extends State<ExposureOverlayPreview> {
  ExposureOverlayMode _mode = ExposureOverlayMode.falseColor;
  ui.Image? _overlayImage;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _generateOverlay();
  }

  @override
  void didUpdateWidget(covariant ExposureOverlayPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _generateOverlay();
    }
  }

  Future<void> _generateOverlay() async {
    setState(() => _loading = true);
    final file = File(widget.imagePath);
    if (!await file.exists()) {
      setState(() {
        _overlayImage = null;
        _loading = false;
      });
      return;
    }

    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final overlay = await ExposureOverlayService.applyOverlay(
      frame.image,
      mode: _mode,
    );
    frame.image.dispose();

    if (mounted) {
      setState(() {
        _overlayImage?.dispose();
        _overlayImage = overlay;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _overlayImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Overlay de exposición', style: AppTypography.label(palette)),
            const Spacer(),
            SegmentedButton<ExposureOverlayMode>(
              segments: const [
                ButtonSegment(
                  value: ExposureOverlayMode.falseColor,
                  label: Text('Falso color'),
                ),
                ButtonSegment(
                  value: ExposureOverlayMode.zebra,
                  label: Text('Zebra'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (v) {
                setState(() => _mode = v.first);
                _generateOverlay();
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_loading)
          const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_overlayImage != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: RawImage(
              image: _overlayImage,
              height: 160,
              fit: BoxFit.cover,
            ),
          ),
      ],
    );
  }
}
