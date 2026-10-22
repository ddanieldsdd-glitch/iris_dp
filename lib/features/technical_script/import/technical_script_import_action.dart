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
import 'technical_script_import_history.dart';
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
    // Copia de cómo estaba: «Deshacer» y «Volver al guion anterior».
    final before = await saveImportSnapshot(
      db,
      projectId,
      reason: 'Antes de importar ${file.name}',
    );
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
      duration: const Duration(seconds: 10),
      actionLabel: summary.isEmpty ? null : 'Deshacer',
      onAction: summary.isEmpty
          ? null
          : () => restoreImportSnapshot(db, projectId, before),
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

/// Vuelve el guion técnico a como estaba antes de una importación (o de
/// otra vuelta atrás). Enseña las copias guardadas, la más reciente arriba.
Future<void> restoreTechnicalScriptBeforeImport(
  BuildContext context,
  WidgetRef ref, {
  required int projectId,
}) async {
  final db = ref.read(databaseProvider);
  final snapshots = await listImportSnapshots(projectId);
  if (!context.mounted) return;
  if (snapshots.isEmpty) {
    AppSnackBar.show(
      context,
      'Aún no hay copias: se guarda una cada vez que importas un Word.',
    );
    return;
  }
  String when(DateTime t) =>
      '${t.day}/${t.month} ${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
  final picked = await showDialog<ImportSnapshot>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Volver al guion técnico anterior'),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            'Elige a qué momento vuelve el guion técnico (escenas, planos, '
            'referencias y plantas). Lo de ahora se guarda también, por si '
            'quieres deshacerlo.',
          ),
        ),
        for (final s in snapshots)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, s),
            child: ListTile(
              leading: const Icon(Icons.history),
              title: Text(s.reason.isEmpty ? 'Copia' : s.reason),
              subtitle: Text(when(s.at)),
            ),
          ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  try {
    await restoreImportSnapshot(db, projectId, picked);
    if (context.mounted) {
      AppSnackBar.show(
        context,
        'El guion técnico ha vuelto a como estaba (${when(picked.at)}).',
      );
    }
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.show(
        context,
        'No se pudo volver atrás: ${userFriendlyError(e)}',
        isError: true,
      );
    }
  }
}

/// Quita las referencias repetidas de los planos (la misma imagen dos
/// veces), pidiendo antes confirmación.
Future<void> removeRepeatedReferences(
  BuildContext context,
  WidgetRef ref, {
  required int projectId,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Quitar imágenes repetidas'),
      content: const Text(
        'En cada plano se busca la misma imagen dos veces (por ejemplo, la '
        'tuya y la que traía un Word, más pequeña) y se deja solo la de más '
        'calidad. Antes se guarda una copia por si quieres volver atrás.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Quitar repetidas'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final db = ref.read(databaseProvider);
  await saveImportSnapshot(db, projectId, reason: 'Antes de quitar repetidas');
  final removed = await removeDuplicateReferences(db, projectId);
  if (!context.mounted) return;
  AppSnackBar.show(
    context,
    removed == 0
        ? 'No había imágenes repetidas.'
        : 'Quitadas $removed imágenes repetidas.',
  );
}
