import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../../core/utils/media_storage.dart';

/// Importa y registra PDFs anotados devueltos desde GoodNotes.
class AnnotatedPdfService {
  final AppDatabase db;

  AnnotatedPdfService(this.db);

  Future<String?> importAnnotatedPdf({
    required int projectId,
    required String moduleType,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return null;

    final source = File(result.files.single.path!);
    if (!await source.exists()) return null;

    final fileName =
        'annotated_${moduleType}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final destPath = await MediaStorage.copyFileIntoProject(
      projectId: projectId,
      sourcePath: source.path,
      subfolder: p.join('annotated', moduleType),
      fileName: fileName,
    );
    if (destPath == null) return null;

    await db.insertAnnotatedPdf(
      ProjectAnnotatedPdfsCompanion.insert(
        projectId: projectId,
        moduleType: moduleType,
        pdfPath: destPath,
      ),
    );

    return destPath;
  }

  Stream<List<ProjectAnnotatedPdf>> watchForProject(
    int projectId, {
    String? moduleType,
  }) =>
      db.watchAnnotatedPdfsForProject(projectId, moduleType: moduleType);

  Future<void> deleteAnnotatedPdf(ProjectAnnotatedPdf row) async {
    final file = File(row.pdfPath);
    if (await file.exists()) {
      await file.delete();
    }
    await db.deleteAnnotatedPdf(row.id);
  }
}
