import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Visor PDF con motor nativo de macOS (CGPDF) vía pdfx.
class ScriptPdfViewer extends StatefulWidget {
  final String path;

  const ScriptPdfViewer({super.key, required this.path});

  @override
  State<ScriptPdfViewer> createState() => _ScriptPdfViewerState();
}

class _ScriptPdfViewerState extends State<ScriptPdfViewer> {
  PdfControllerPinch? _controller;

  @override
  void initState() {
    super.initState();
    _openDocument();
  }

  @override
  void didUpdateWidget(ScriptPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _controller?.dispose();
      _openDocument();
    }
  }

  void _openDocument() {
    _controller = PdfControllerPinch(
      document: PdfDocument.openFile(widget.path),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ColoredBox(
      color: const Color(0xFF525659),
      child: PdfViewPinch(
        controller: controller,
        scrollDirection: Axis.vertical,
        padding: 10,
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Cargando PDF…',
                  style: AppTypography.bodyMedium(palette),
                ),
              ],
            ),
          ),
          pageLoaderBuilder: (_) => const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorBuilder: (_, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'No se pudo abrir el PDF.\n$error',
                style: AppTypography.bodyMedium(palette),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
