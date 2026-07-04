import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../look_bible/look_bible_model.dart';

/// Prepara PDFs de IRIS DP para anotar en GoodNotes vía hoja de compartir.
class GoodNotesExportService {
  GoodNotesExportService._();

  static Future<void> shareForAnnotation({
    required List<int> pdfBytes,
    required String filename,
    required String documentType,
  }) async {
    final dir = await getTemporaryDirectory();
    final safeName = filename.endsWith('.pdf') ? filename : '$filename.pdf';
    final file = File(p.join(dir.path, safeName));
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'IRIS DP — ${GoodNotesModuleType.label(documentType)}',
      text: 'Ábrelo en GoodNotes para anotar a mano con el Apple Pencil.',
    );
  }
}
