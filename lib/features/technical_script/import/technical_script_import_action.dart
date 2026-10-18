import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/utils/export_file_saver.dart';
import '../../../core/utils/user_error.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../technical_script_settings.dart';
import 'docx_technical_script_reader.dart';
import 'technical_script_import_applier.dart';
import 'technical_script_import_plan.dart';
import 'technical_script_import_review.dart';

/// Elige un guion técnico en Word, enseña la revisión y aplica lo decidido.
Future<void> importTechnicalScriptDocx(
  BuildContext context,
  WidgetRef ref, {
  required int projectId,
}) async {
  final picked = await UserFilePicker.pickFiles(
    dialogTitle: 'Importar guion técnico (.docx)',
    type: FileType.custom,
    allowedExtensions: const ['docx'],
  );
  if (picked == null || picked.files.isEmpty || !context.mounted) return;
  final file = picked.files.first;
  final db = ref.read(databaseProvider);

  final ImportedTechnicalScript document;
  try {
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    document = await compute(DocxTechnicalScriptReader.read, bytes);
  } on FormatException catch (e) {
    if (context.mounted) AppSnackBar.show(context, e.message);
    return;
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.show(
        context,
        'No se pudo leer el Word: ${userFriendlyError(e)}',
        isError: true,
      );
    }
    return;
  }
  if (document.scenes.isEmpty) {
    if (context.mounted) {
      AppSnackBar.show(context, 'El documento no tiene escenas.');
    }
    return;
  }

  Future<T> busy<T>(String message, Future<T> Function() work) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
    try {
      return await work();
    } finally {
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<TechnicalScriptImportPlan> prepare(Map<String, int?> pairing) =>
      prepareTechnicalScriptImport(
        db: db,
        projectId: projectId,
        document: document,
        pairing: pairing,
      );

  final plan = await busy(
    'Comparando con el guion técnico…',
    () => prepare({}),
  );
  if (!context.mounted) return;
  final review = await showTechnicalScriptImportReview(
    context,
    fileName: file.name,
    plan: plan,
    replan: prepare,
  );
  if (review == null || !context.mounted) return;

  final (finalPlan, decisions) = review;
  try {
    final result = await busy(
      'Importando…',
      () => applyTechnicalScriptImport(
        db: db,
        projectId: projectId,
        plan: finalPlan,
        decisions: decisions,
        generalPlanView: ref.read(technicalScriptSettingsProvider).planView,
      ),
    );
    if (!context.mounted) return;
    final summary = result.summary;
    AppSnackBar.show(
      context,
      summary.isEmpty
          ? 'Nada que cambiar: el guion técnico ya estaba al día.'
          : 'Guion técnico importado: $summary.',
      duration: const Duration(seconds: 6),
    );
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.show(
        context,
        'No se pudo importar el guion técnico: ${userFriendlyError(e)}',
        isError: true,
      );
    }
  }
}
