import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/export_file_saver.dart';
import '../../../core/widgets/app_snackbar.dart';
import 'rental_format.dart';
import 'rental_import_service.dart';
import 'rental_list_formats.dart';

/// Elige una lista, la lee y abre la revisión. Devuelve el uid guardado.
Future<String?> pickAndImportRentalList(
  BuildContext context,
  WidgetRef ref,
  int projectId,
) async {
  try {
    final result = await UserFilePicker.pickFiles(
      dialogTitle: 'Importar lista de material',
      type: FileType.custom,
      allowedExtensions: rentalListExtensions,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    if (!context.mounted) return null;
    return importRentalListBytes(context, ref, projectId, file.name, bytes);
  } catch (e) {
    if (context.mounted) AppSnackBar.show(context, '$e', isError: true);
    return null;
  }
}

Future<String?> importRentalListBytes(
  BuildContext context,
  WidgetRef ref,
  int projectId,
  String fileName,
  Uint8List bytes,
) async {
  try {
    final parsed = readRentalList(fileName, bytes);
    final service = RentalImportService(ref.read(databaseProvider));
    final preview = await service.preview(projectId, parsed);
    if (!context.mounted) return null;
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RentalImportReviewScreen(
          projectId: projectId,
          fileName: fileName,
          preview: preview,
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) AppSnackBar.show(context, '$e', isError: true);
    return null;
  }
}

class RentalImportReviewScreen extends ConsumerStatefulWidget {
  final int projectId;
  final String fileName;
  final RentalImportPreview preview;

  const RentalImportReviewScreen({
    super.key,
    required this.projectId,
    required this.fileName,
    required this.preview,
  });

  @override
  ConsumerState<RentalImportReviewScreen> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<RentalImportReviewScreen> {
  late final TextEditingController _title;
  late final TextEditingController _house;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.preview;
    final dot = widget.fileName.lastIndexOf('.');
    final stem = dot > 0 ? widget.fileName.substring(0, dot) : widget.fileName;
    _title = TextEditingController(text: p.existing?.title ?? stem);
    _house = TextEditingController(text: p.parsed.suggestedHouse ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _house.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      AppSnackBar.show(context, 'Ponle un nombre a la lista.', isError: true);
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final uid = await RentalImportService(db).apply(
      projectId: widget.projectId,
      preview: widget.preview,
      title: _title.text,
      houseName: _house.text,
      contact: widget.preview.parsed.contact,
      sourceFileName: widget.fileName,
    );
    if (mounted) Navigator.of(context).pop(uid);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final p = widget.preview;
    final parsed = p.parsed;
    final gutter = AppLayout.gutter(context);
    final caption = AppTypography.caption(palette);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text(
          p.isUpdate ? 'Actualizar lista' : 'Revisar lista',
          style: AppTypography.titleMedium(palette),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, 40),
        children: [
          if (!parsed.recognizedTable) ...[
            _Notice(
              'No se ha reconocido una tabla en este archivo. Comprueba cada '
              'línea antes de usar la lista.',
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Nombre de la lista'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _house,
            decoration: const InputDecoration(
              labelText: 'Casa o lugar de recogida',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            [
              if (parsed.number != null) 'Reserva ${parsed.number}',
              if (parsed.sourceStatus != null) parsed.sourceStatus!,
            ].join(' · '),
            style: AppTypography.label(palette),
          ),
          const SizedBox(height: 4),
          Text(
            'Recogida: ${formatRentalMoment(parsed.pickupAt)}',
            style: caption,
          ),
          Text(
            'Devolución: ${formatRentalMoment(parsed.returnAt)}',
            style: caption,
          ),
          if (p.isUpdate) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Respecto a la lista guardada',
              style: AppTypography.label(palette),
            ),
            const SizedBox(height: 4),
            _Changes('Nuevo', p.added),
            _Changes('Cambia', p.changed),
            _Changes('Ya no viene', p.removed),
            if (p.added.isEmpty && p.changed.isEmpty && p.removed.isEmpty)
              Text('Sin cambios en el material.', style: caption),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${parsed.itemCount} líneas',
            style: AppTypography.label(palette),
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._items(palette),
        ],
      ),
    );
  }

  List<Widget> _items(AppPalette palette) {
    final out = <Widget>[];
    final body = AppTypography.bodyMedium(
      palette,
    ).copyWith(color: palette.textPrimary);
    final caption = AppTypography.caption(palette);
    String? section;
    for (final item in widget.preview.parsed.items) {
      if (item.section != section) {
        section = item.section;
        if (section != null) {
          out.add(
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 4),
              child: Text(section, style: AppTypography.label(palette)),
            ),
          );
        }
      }
      out.add(
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: item.quantityCertain ? null : const EdgeInsets.all(4),
          color: item.quantityCertain || item.kind == 'note'
              ? null
              : palette.warning.withValues(alpha: 0.15),
          child: Text(
            item.kind == 'note'
                ? item.name
                : '${formatRentalQuantity(item.quantity)} × ${item.name}',
            style: body,
          ),
        ),
      );
      for (final c in item.children) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md, bottom: 2),
            child: Text(
              [
                '${c.quantity == null ? '' : '${formatRentalQuantity(c.quantity)} × '}${c.name}',
                if (c.serial != null) 'nº ${c.serial}',
                if (c.note != null) c.note!,
              ].join(' · '),
              style: caption,
            ),
          ),
        );
      }
    }
    return out;
  }
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice(this.text);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      color: palette.warning.withValues(alpha: 0.15),
      child: Text(text, style: AppTypography.bodyMedium(palette)),
    );
  }
}

class _Changes extends StatelessWidget {
  final String label;
  final List<String> names;
  const _Changes(this.label, this.names);

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    return Text(
      '$label: ${names.join(', ')}',
      style: AppTypography.caption(context.palette),
    );
  }
}
