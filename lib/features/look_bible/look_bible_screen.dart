import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/media_storage.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../goodnotes/annotated_pdf_service.dart';
import '../goodnotes/goodnotes_pdf_actions.dart';
import 'look_bible_model.dart';
import 'look_bible_pdf_service.dart';
import '../../core/widgets/app_snackbar.dart';

class LookBibleScreen extends ConsumerStatefulWidget {
  final int projectId;

  const LookBibleScreen({super.key, required this.projectId});

  @override
  ConsumerState<LookBibleScreen> createState() => _LookBibleScreenState();
}

class _LookBibleScreenState extends ConsumerState<LookBibleScreen> {
  LookBibleData? _data;
  Project? _project;
  bool _loading = true;
  bool _saving = false;
  Timer? _saveDebounce;
  final _conceptCtrl = TextEditingController();
  final _lutCtrl = TextEditingController();
  final _philosophyCtrl = TextEditingController();
  final _act1Ctrl = TextEditingController();
  final _act2Ctrl = TextEditingController();
  final _act3Ctrl = TextEditingController();
  final _refInputCtrl = TextEditingController();

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _conceptCtrl.dispose();
    _lutCtrl.dispose();
    _philosophyCtrl.dispose();
    _act1Ctrl.dispose();
    _act2Ctrl.dispose();
    _act3Ctrl.dispose();
    _refInputCtrl.dispose();
    super.dispose();
  }

  void _bindControllers(LookBibleData data) {
    _conceptCtrl.text = data.visualConcept ?? '';
    _lutCtrl.text = data.lutName ?? '';
    _philosophyCtrl.text = data.lightingPhilosophy ?? '';
    _act1Ctrl.text = data.actOneNotes ?? '';
    _act2Ctrl.text = data.actTwoNotes ?? '';
    _act3Ctrl.text = data.actThreeNotes ?? '';
  }

  void _syncFromControllers() {
    final data = _data;
    if (data == null) return;
    data.visualConcept = _conceptCtrl.text.trim().isEmpty
        ? null
        : _conceptCtrl.text.trim();
    data.lutName =
        _lutCtrl.text.trim().isEmpty ? null : _lutCtrl.text.trim();
    data.lightingPhilosophy = _philosophyCtrl.text.trim().isEmpty
        ? null
        : _philosophyCtrl.text.trim();
    data.actOneNotes =
        _act1Ctrl.text.trim().isEmpty ? null : _act1Ctrl.text.trim();
    data.actTwoNotes =
        _act2Ctrl.text.trim().isEmpty ? null : _act2Ctrl.text.trim();
    data.actThreeNotes =
        _act3Ctrl.text.trim().isEmpty ? null : _act3Ctrl.text.trim();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    final data = _data;
    if (data == null) return;
    _syncFromControllers();
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      final id = await db.upsertLookBible(data.toCompanion());
      data.id = id;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportPdf() async {
    final project = _project;
    final data = _data;
    if (project == null || data == null) return;
    _syncFromControllers();
    await _save();
    try {
      final path = await LookBiblePdfService.exportAndSave(
        projectName: project.name,
        director: project.director,
        data: data,
      );
      if (!mounted || path == null) return;
      AppSnackBar.show(context, 'Look Bible exportada en $path');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, userFriendlyError(e));
    }
  }

  Future<void> _addMoodboardImages() async {
    final data = _data;
    if (data == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;

    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      final ext = p.extension(path);
      final copied = await MediaStorage.copyFileIntoProject(
        projectId: widget.projectId,
        sourcePath: path,
        subfolder: 'look_bible/moodboard',
        fileName: 'mb_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      if (copied != null) data.moodboardImagePaths.add(copied);
    }
    setState(() {});
    _scheduleSave();
  }

  void _removeMoodboardImage(int index) {
    _data?.moodboardImagePaths.removeAt(index);
    setState(() {});
    _scheduleSave();
  }

  void _addColor(Color color) {
    final hex =
        '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    _data?.colorHexPalette.add(hex);
    setState(() {});
    _scheduleSave();
  }

  void _removeColor(int index) {
    _data?.colorHexPalette.removeAt(index);
    setState(() {});
    _scheduleSave();
  }

  void _addFilmReference() {
    final text = _refInputCtrl.text.trim();
    if (text.isEmpty) return;
    _data?.filmReferences.add(text);
    _refInputCtrl.clear();
    setState(() {});
    _scheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('Look Bible', style: AppTypography.titleMedium(palette)),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (_data != null && _project != null)
            GoodNotesPdfActions(
              projectId: widget.projectId,
              moduleType: GoodNotesModuleType.lookBible,
              filenameBase:
                  '${_project!.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim()}_look_bible',
              buildPdfBytes: () => LookBiblePdfService.buildBytes(
                projectName: _project!.name,
                director: _project!.director,
                data: _data!,
              ),
            ),
          IconButton(
            tooltip: 'Exportar PDF',
            icon: Icon(Icons.picture_as_pdf_outlined, color: palette.accent),
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: StreamBuilder<LookBible?>(
        stream: db.watchLookBibleForProject(widget.projectId),
        builder: (context, snap) {
          if (_loading && snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_data == null) {
            _data = snap.data != null
                ? LookBibleData.fromRow(snap.data!)
                : LookBibleData.empty(widget.projectId);
            _bindControllers(_data!);
            _loading = false;
            unawaited(
              db.getProject(widget.projectId).then((p) {
                if (mounted) setState(() => _project = p);
              }),
            );
          }

          final data = _data!;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Concepto visual',
                      style: AppTypography.label(palette),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _conceptCtrl,
                      maxLines: 4,
                      style: AppTypography.bodyLarge(palette),
                      decoration: const InputDecoration(
                        hintText:
                            'Describe la identidad visual del proyecto…',
                      ),
                      onChanged: (_) => _scheduleSave(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paleta de color', style: AppTypography.label(palette)),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < data.colorHexPalette.length; i++)
                          GestureDetector(
                            onLongPress: () => _removeColor(i),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: data.paletteColors[i],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: palette.divider),
                              ),
                            ),
                          ),
                        ActionChip(
                          avatar: Icon(Icons.add, size: 16, color: palette.accent),
                          label: Text(
                            'Color',
                            style: AppTypography.caption(palette),
                          ),
                          onPressed: () async {
                            var picked = const Color(0xFF0A84FF);
                            await showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Añadir color'),
                                content: SingleChildScrollView(
                                  child: BlockPicker(
                                    pickerColor: picked,
                                    onColorChanged: (c) => picked = c,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _addColor(picked);
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('Añadir'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Mantén pulsado un color para eliminarlo.',
                      style: AppTypography.caption(palette).copyWith(
                        color: palette.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LUT y referencias', style: AppTypography.label(palette)),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _lutCtrl,
                      style: AppTypography.bodyLarge(palette),
                      decoration: const InputDecoration(
                        labelText: 'LUT',
                        hintText: 'ej. ARRI 709, Kodak 2383…',
                      ),
                      onChanged: (_) => _scheduleSave(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String?>(
                      value: data.contrastStyle,
                      decoration: const InputDecoration(labelText: 'Contraste'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('—')),
                        for (final s in kContrastStyles)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) {
                        data.contrastStyle = v;
                        setState(() {});
                        _scheduleSave();
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...data.filmReferences.map(
                      (r) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(r, style: AppTypography.bodyMedium(palette)),
                        trailing: IconButton(
                          icon: Icon(Icons.close, color: palette.textSecondary),
                          onPressed: () {
                            data.filmReferences.remove(r);
                            setState(() {});
                            _scheduleSave();
                          },
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _refInputCtrl,
                            style: AppTypography.bodyLarge(palette),
                            decoration: const InputDecoration(
                              hintText: 'Película de referencia…',
                            ),
                            onSubmitted: (_) => _addFilmReference(),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add, color: palette.accent),
                          onPressed: _addFilmReference,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Moodboard', style: AppTypography.label(palette)),
                    const SizedBox(height: AppSpacing.sm),
                    if (data.moodboardImagePaths.isEmpty)
                      Text(
                        'Añade imágenes de referencia visual.',
                        style: AppTypography.bodyMedium(palette),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: data.moodboardImagePaths.length,
                        itemBuilder: (context, i) {
                          final path = data.moodboardImagePaths[i];
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: palette.surfaceElevated,
                                    child: Icon(Icons.broken_image,
                                        color: palette.textTertiary),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeMoodboardImage(i),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Añadir imágenes',
                      icon: Icons.add_photo_alternate_outlined,
                      variant: AppButtonVariant.secondary,
                      onTap: _addMoodboardImages,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filosofía de luz', style: AppTypography.label(palette)),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _philosophyCtrl,
                      maxLines: 4,
                      style: AppTypography.bodyLarge(palette),
                      decoration: const InputDecoration(
                        hintText: 'Enfoque de iluminación para gaffer y color…',
                      ),
                      onChanged: (_) => _scheduleSave(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Notas por acto', style: AppTypography.label(palette)),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _act1Ctrl,
                      maxLines: 3,
                      style: AppTypography.bodyLarge(palette),
                      decoration: const InputDecoration(labelText: 'Acto I'),
                      onChanged: (_) => _scheduleSave(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _act2Ctrl,
                      maxLines: 3,
                      style: AppTypography.bodyLarge(palette),
                      decoration: const InputDecoration(labelText: 'Acto II'),
                      onChanged: (_) => _scheduleSave(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _act3Ctrl,
                      maxLines: 3,
                      style: AppTypography.bodyLarge(palette),
                      decoration: const InputDecoration(labelText: 'Acto III'),
                      onChanged: (_) => _scheduleSave(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _AnnotatedPdfsSection(
                projectId: widget.projectId,
                moduleType: GoodNotesModuleType.lookBible,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Exportar Look Bible PDF',
                icon: Icons.picture_as_pdf_outlined,
                onTap: _exportPdf,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnnotatedPdfsSection extends ConsumerWidget {
  final int projectId;
  final String moduleType;

  const _AnnotatedPdfsSection({
    required this.projectId,
    required this.moduleType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<ProjectAnnotatedPdf>>(
      stream: db.watchAnnotatedPdfsForProject(projectId, moduleType: moduleType),
      builder: (context, snap) {
        final items = snap.data ?? [];
        if (items.isEmpty) return const SizedBox.shrink();

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PDFs anotados (GoodNotes)',
                style: AppTypography.label(palette),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...items.map(
                (row) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.draw_outlined, color: palette.accent),
                  title: Text(
                    p.basename(row.pdfPath),
                    style: AppTypography.bodyMedium(palette),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    row.importedAt.toLocal().toString().substring(0, 16),
                    style: AppTypography.caption(palette),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: palette.error),
                    onPressed: () =>
                        AnnotatedPdfService(db).deleteAnnotatedPdf(row),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
