import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_render_maintained/pdf_render_maintained.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Visor PDF del guion (pdf_render_maintained — SPM en macOS).
class ScriptPdfViewer extends StatelessWidget {
  final String path;

  const ScriptPdfViewer({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final file = File(path);

    if (!file.existsSync()) {
      return Center(
        child: Text(
          'No se encontró el archivo PDF.',
          style: AppTypography.bodyMedium(palette),
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xFF525659),
      child: PdfRenderView.file(
        file,
        params: const PdfViewerParams(
          padding: AppSpacing.md,
          minScale: 1.0,
        ),
      ),
    );
  }
}
