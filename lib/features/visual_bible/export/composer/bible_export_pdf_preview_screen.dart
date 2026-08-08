import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf_render_maintained/pdf_render_maintained.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Revisión final del archivo generado antes de guardarlo o compartirlo.
class BibleExportPdfPreviewScreen extends StatefulWidget {
  final Uint8List bytes;
  final String title;
  final Future<void> Function() onConfirm;

  const BibleExportPdfPreviewScreen({
    super.key,
    required this.bytes,
    required this.title,
    required this.onConfirm,
  });

  @override
  State<BibleExportPdfPreviewScreen> createState() =>
      _BibleExportPdfPreviewScreenState();
}

class _BibleExportPdfPreviewScreenState
    extends State<BibleExportPdfPreviewScreen> {
  bool _saving = false;

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onConfirm();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: const Color(0xFF525659),
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: AppTypography.titleMedium(palette)),
            Text(
              'Revisa el PDF final antes de continuar',
              style: AppTypography.caption(palette),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: FilledButton.icon(
              onPressed: _saving ? null : _confirm,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Procesando…' : 'Continuar'),
            ),
          ),
        ],
      ),
      body: PdfViewer.openData(
        widget.bytes,
        params: const PdfViewerParams(padding: AppSpacing.md, minScale: 1),
      ),
    );
  }
}
