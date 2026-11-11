import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/export_file_saver.dart';
import '../../../core/utils/user_error.dart';
import '../../../core/widgets/app_snackbar.dart';
import 'shoot_plan_file_reader.dart';
import 'shoot_plan_import_service.dart';
import 'shoot_plan_text_parser.dart';

const _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _dayDate(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return 'sin fecha';
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
}

/// Abre la importación de un plan de rodaje. Devuelve `true` si se importó.
Future<bool?> openShootPlanImport(
  BuildContext context, {
  required int projectId,
  String? fileName,
  Uint8List? bytes,
}) => Navigator.of(context).push<bool>(
  MaterialPageRoute(
    builder: (_) => ShootPlanImportScreen(
      projectId: projectId,
      fileName: fileName,
      bytes: bytes,
    ),
  ),
);

/// Pega o elige el plan, mira lo que se va a cambiar y lo importa.
class ShootPlanImportScreen extends ConsumerStatefulWidget {
  final int projectId;
  final String? fileName;
  final Uint8List? bytes;

  const ShootPlanImportScreen({
    super.key,
    required this.projectId,
    this.fileName,
    this.bytes,
  });

  @override
  ConsumerState<ShootPlanImportScreen> createState() => _ImportState();
}

class _ImportState extends ConsumerState<ShootPlanImportScreen> {
  final _text = TextEditingController();
  String? _fileName;
  ShootPlanImportPreview? _preview;
  Timer? _debounce;
  bool _reading = false;
  bool _saving = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _text.addListener(_schedule);
    if (widget.bytes != null && widget.fileName != null) {
      _load(widget.fileName!, widget.bytes!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _refresh);
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    final text = _text.text;
    if (text.trim().isEmpty) {
      setState(() => _preview = null);
      return;
    }
    final plan = parseShootPlanText(text);
    final preview = await ShootPlanImportService(
      ref.read(databaseProvider),
    ).preview(widget.projectId, plan);
    if (!mounted || generation != _generation) return;
    setState(() => _preview = preview);
  }

  Future<void> _load(String name, Uint8List bytes) async {
    setState(() => _reading = true);
    try {
      final text = await compute(readShootPlanFile, (name, bytes));
      if (!mounted) return;
      _fileName = name;
      _text.text = text;
    } on FormatException catch (e) {
      if (mounted) AppSnackBar.show(context, e.message, isError: true);
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          'No se pudo leer $name: ${userFriendlyError(e)}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _pick() async {
    try {
      final picked = await UserFilePicker.pickFiles(
        dialogTitle: 'Importar plan de rodaje',
        type: FileType.custom,
        allowedExtensions: kShootPlanExtensions,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.first;
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      await _load(file.name, bytes);
    } catch (e) {
      if (mounted) AppSnackBar.show(context, '$e', isError: true);
    }
  }

  Future<void> _drop(List<String> paths) async {
    if (paths.isEmpty) return;
    final path = paths.first;
    await _load(
      path.split(Platform.pathSeparator).last,
      await File(path).readAsBytes(),
    );
  }

  Future<void> _apply() async {
    final preview = _preview;
    if (preview == null || preview.days.isEmpty) return;
    setState(() => _saving = true);
    final service = ShootPlanImportService(ref.read(databaseProvider));
    try {
      final before = await service.snapshot(widget.projectId);
      await service.apply(widget.projectId, preview);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final days = preview.days.length;
      Navigator.of(context).pop(true);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 12),
          content: Text(
            'Plan importado: $days ${days == 1 ? 'jornada' : 'jornadas'}.',
          ),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => service.undo(widget.projectId, before),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackBar.show(
          context,
          'No se pudo importar: ${userFriendlyError(e)}',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final gutter = AppLayout.gutter(context);
    final preview = _preview;
    final canApply =
        !_saving && !_reading && preview != null && preview.days.isNotEmpty;

    final editor = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _fileName ?? 'Pega el plan o elige un archivo',
                style: AppTypography.label(palette),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: _reading ? null : _pick,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Elegir archivo'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: TextField(
            controller: _text,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: AppTypography.mono(palette).copyWith(fontSize: 12),
            decoration: const InputDecoration(
              hintText:
                  'DÍA 1 - 13 NOVIEMBRE (7:30 - 17:00)\n'
                  '7:30 - 8:30 Llegada de camión\n'
                  '10:15 8.1 PMC de Ali (35 min)\n'
                  '…\n\n'
                  'Word (.docx), Excel (.xlsx), PDF o texto. También puedes '
                  'soltar el archivo aquí.',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );

    final result = _reading
        ? const Center(child: CircularProgressIndicator())
        : preview == null
        ? Center(
            child: Text(
              'Aquí verás las jornadas que se van a crear o cambiar.',
              style: AppTypography.caption(palette),
              textAlign: TextAlign.center,
            ),
          )
        : _PreviewList(preview: preview);

    final body = LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 760;
        final padding = EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, 24);
        if (wide) {
          return Padding(
            padding: padding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: editor),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: result),
              ],
            ),
          );
        }
        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: editor),
              const SizedBox(height: AppSpacing.md),
              Expanded(flex: 3, child: result),
            ],
          ),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text(
          'Importar plan de rodaje',
          style: AppTypography.titleMedium(palette),
        ),
        actions: [
          TextButton(
            onPressed: canApply ? _apply : null,
            child: const Text('Importar'),
          ),
        ],
      ),
      body: Platform.isMacOS || Platform.isWindows
          ? DropTarget(
              onDragDone: (d) => _drop([for (final f in d.files) f.path]),
              child: body,
            )
          : body,
    );
  }
}

class _PreviewList extends StatelessWidget {
  final ShootPlanImportPreview preview;

  const _PreviewList({required this.preview});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final caption = AppTypography.caption(palette);
    if (preview.days.isEmpty) {
      return Center(
        child: Text(
          'No se encuentra ningún día. Cada jornada empieza con una línea '
          'como «DÍA 1 - 13 NOVIEMBRE (7:30 - 17:00)».',
          style: caption,
          textAlign: TextAlign.center,
        ),
      );
    }
    final missing = [
      ...preview.missingScenes.map((s) => 'escena $s'),
      ...preview.missingShots.map((s) => 'plano $s'),
    ];
    return ListView(
      children: [
        if (preview.plan.title case final title? when title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(title, style: AppTypography.titleMedium(palette)),
          ),
        Text(
          'Las jornadas emparejadas cambian su orden por el del plan. Las '
          'marcas de En set de los planos que siguen se conservan, y al '
          'terminar puedes deshacerlo.',
          style: caption,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final day in preview.days) _DayTile(day: day),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            color: palette.warning.withValues(alpha: 0.15),
            child: Text(
              'No están en el guion: ${missing.join(', ')}. Entran como '
              'apuntes en su sitio del horario.',
              style: AppTypography.bodyMedium(palette),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  final ShootPlanImportDay day;

  const _DayTile({required this.day});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final p = day.parsed;
    final strips = p.lines.whereType<ParsedPlanStrip>().length;
    final scenes = {
      for (final l in p.lines)
        if (l is ParsedPlanShot) l.scene else if (l is ParsedPlanScene) l.scene,
    };
    final window = p.from == null ? '' : ' · ${p.from}–${p.to ?? '…'}';
    final target = day.existing == null
        ? 'Nueva jornada'
        : 'Sustituye el orden de «${day.existing!.name}»';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Día ${p.number} · ${_dayDate(p.date)}$window',
            style: AppTypography.label(palette),
          ),
          const SizedBox(height: 2),
          Text(
            target,
            style: AppTypography.caption(palette).copyWith(
              color: day.existing == null ? palette.accent : palette.warning,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              '${scenes.length} ${scenes.length == 1 ? 'escena' : 'escenas'}',
              '${day.shots} ${day.shots == 1 ? 'plano' : 'planos'}',
              '$strips ${strips == 1 ? 'franja' : 'franjas'}',
            ].join(' · '),
            style: AppTypography.caption(palette),
          ),
          if (p.note.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              p.note.trim(),
              style: AppTypography.caption(palette),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          for (final l in p.lines.take(40)) _LineRow(line: l),
          if (p.lines.length > 40)
            Text(
              '… y ${p.lines.length - 40} más',
              style: AppTypography.caption(palette),
            ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  final ParsedPlanLine line;

  const _LineRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = AppTypography.caption(palette);
    final time = line.from == null
        ? '     '
        : line.to == null
        ? line.from!
        : '${line.from}–${line.to}';
    final (label, color) = switch (line) {
      ParsedPlanStrip(:final kind, :final label) => (
        label.isEmpty ? kind.label : label,
        palette.textTertiary,
      ),
      ParsedPlanScene(:final scene) => ('Escena $scene', palette.textPrimary),
      ParsedPlanShot(:final scene, :final shot, :final text) => (
        '$scene.$shot  $text',
        palette.textSecondary,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              time,
              style: AppTypography.mono(
                palette,
              ).copyWith(fontSize: 11, color: palette.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: style.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
