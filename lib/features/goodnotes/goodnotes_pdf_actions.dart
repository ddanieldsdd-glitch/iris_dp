import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/user_error.dart';
import 'annotated_pdf_service.dart';
import 'goodnotes_export_service.dart';
import '../../core/widgets/app_snackbar.dart';

/// Menú GoodNotes: compartir PDF para anotar e importar versión anotada.
class GoodNotesPdfActions extends ConsumerWidget {
  final int projectId;
  final String moduleType;
  final String filenameBase;
  final Future<List<int>> Function() buildPdfBytes;

  const GoodNotesPdfActions({
    super.key,
    required this.projectId,
    required this.moduleType,
    required this.filenameBase,
    required this.buildPdfBytes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return PopupMenuButton<String>(
      tooltip: 'GoodNotes',
      icon: Icon(Icons.ios_share_outlined, color: palette.accent),
      onSelected: (value) => _handleAction(context, ref, value),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'share',
          child: Text(
            'Abrir en GoodNotes',
            style: AppTypography.bodyMedium(palette),
          ),
        ),
        PopupMenuItem(
          value: 'import',
          child: Text(
            'Importar PDF anotado',
            style: AppTypography.bodyMedium(palette),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final palette = context.palette;
    final db = ref.read(databaseProvider);
    final annotated = AnnotatedPdfService(db);

    try {
      if (action == 'share') {
        final bytes = await buildPdfBytes();
        await GoodNotesExportService.shareForAnnotation(
          pdfBytes: bytes,
          filename: filenameBase,
          documentType: moduleType,
        );
      } else if (action == 'import') {
        final path = await annotated.importAnnotatedPdf(
          projectId: projectId,
          moduleType: moduleType,
        );
        if (!context.mounted) return;
        if (path != null) {
          AppSnackBar.show(context, 'PDF anotado guardado en el proyecto.');
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.show(context, userFriendlyError(e));
    }
  }
}
