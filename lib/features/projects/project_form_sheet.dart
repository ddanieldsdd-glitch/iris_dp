import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/sync/project_cloud_actions.dart';
import '../../core/cloud/cloud_runtime_config.dart';
import '../../core/database/app_database.dart';
import '../auth/invite_director_sheet.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/utils/media_storage.dart';
import '../../core/widgets/app_button.dart';
import 'project_icon_constants.dart';

/// Formulario compartido para crear o editar un proyecto.
/// Si [project] es null → creación; si tiene valor → edición.
class ProjectFormSheet extends ConsumerStatefulWidget {
  final Project? project;

  const ProjectFormSheet({super.key, this.project});

  @override
  ConsumerState<ProjectFormSheet> createState() => _ProjectFormSheetState();
}

class _ProjectFormSheetState extends ConsumerState<ProjectFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _directorCtrl;
  late int _selectedIcon;
  late String _status;
  late int? _groupId;
  String? _coverImagePath;

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _directorCtrl = TextEditingController(text: p?.director ?? '');
    _selectedIcon = p?.iconCode ?? kProjectIcons.first.codePoint;
    _status = p?.status ?? 'preproduction';
    _groupId = p?.groupId;
    _coverImagePath = p?.coverImagePath;
  }

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    if (_isEditing) {
      final ext = p.extension(path).isEmpty ? '.jpg' : p.extension(path);
      final copied = await MediaStorage.copyFileIntoProject(
        projectId: widget.project!.id,
        sourcePath: path,
        subfolder: 'cover',
        fileName: 'cover_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      if (copied != null && mounted) {
        setState(() => _coverImagePath = copied);
      }
    } else {
      setState(() => _coverImagePath = path);
    }
  }

  Future<String?> _persistCoverForNewProject(int projectId) async {
    final path = _coverImagePath;
    if (path == null || path.isEmpty) return null;
    if (File(path).existsSync()) {
      final ext = p.extension(path).isEmpty ? '.jpg' : p.extension(path);
      return MediaStorage.copyFileIntoProject(
        projectId: projectId,
        sourcePath: path,
        subfolder: 'cover',
        fileName: 'cover_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
    }
    return null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _directorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final db = ref.read(databaseProvider);
    final director = _directorCtrl.text.trim();

    try {
    if (_isEditing) {
      final updated = widget.project!.copyWith(
        name: name,
        director: director.isEmpty ? const Value(null) : Value(director),
        status: _status,
        iconCode: _selectedIcon,
        groupId: Value(_groupId),
        coverImagePath: Value(_coverImagePath),
        updatedAt: DateTime.now(),
      );
      await ProjectCloudActions.saveProject(ref, updated);
    } else {
      final newId = await ProjectCloudActions.createProject(
        ref,
        name: name,
        director: director.isEmpty ? null : director,
        status: _status,
        iconCode: _selectedIcon,
        groupId: _groupId,
      );
      if (_coverImagePath != null) {
        final stored = await _persistCoverForNewProject(newId);
        if (stored != null) {
          final created = await db.getProject(newId);
          if (created != null) {
            await db.updateProject(
              created.copyWith(
                coverImagePath: Value(stored),
                updatedAt: DateTime.now(),
              ),
            );
          }
        }
      }
    }

    if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar el proyecto: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: AppRadius.large,
          border: Border.all(color: palette.border),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Editar proyecto' : 'Nuevo proyecto',
                style: AppTypography.titleLarge(palette),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _nameCtrl,
                style: AppTypography.bodyLarge(palette),
                decoration: const InputDecoration(hintText: 'Nombre del proyecto'),
                autofocus: !_isEditing,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _directorCtrl,
                style: AppTypography.bodyLarge(palette),
                decoration: const InputDecoration(hintText: 'Director (opcional)'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Imagen del proyecto', style: AppTypography.label(palette)),
              const SizedBox(height: AppSpacing.sm),
              _CoverImagePicker(
                coverPath: _coverImagePath,
                iconCode: _selectedIcon,
                onPick: _pickCoverImage,
                onRemove: () => setState(() => _coverImagePath = null),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Icono', style: AppTypography.label(palette)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: kProjectIcons.map((icon) {
                  final selected = icon.codePoint == _selectedIcon;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon.codePoint),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? palette.accent.withValues(alpha: 0.2)
                            : palette.surfaceOverlay,
                        borderRadius: AppRadius.small,
                        border: Border.all(
                          color: selected ? palette.accent : palette.border,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: selected ? palette.accent : palette.textSecondary,
                        size: 22,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Estado', style: AppTypography.label(palette)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  _StatusOption(
                    label: 'Preproducción',
                    selected: _status == 'preproduction',
                    onTap: () => setState(() => _status = 'preproduction'),
                  ),
                  _StatusOption(
                    label: 'Rodaje',
                    selected: _status == 'shooting',
                    onTap: () => setState(() => _status = 'shooting'),
                  ),
                  _StatusOption(
                    label: 'Post',
                    selected: _status == 'post',
                    onTap: () => setState(() => _status = 'post'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Grupo', style: AppTypography.label(palette)),
              const SizedBox(height: AppSpacing.sm),
              StreamBuilder<List<ProjectGroup>>(
                stream: db.watchAllGroups(),
                builder: (context, snap) {
                  final groups = snap.data ?? [];
                  return DropdownButtonFormField<int?>(
                    initialValue: _groupId,
                    dropdownColor: palette.surfaceElevated,
                    style: AppTypography.bodyMedium(palette),
                    decoration: const InputDecoration(hintText: 'Sin grupo'),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'Sin grupo',
                          style: AppTypography.bodyMedium(palette),
                        ),
                      ),
                      ...groups.map(
                        (g) => DropdownMenuItem<int?>(
                          value: g.id,
                          child: Text(
                            g.name,
                            style: AppTypography.bodyMedium(palette),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _groupId = v),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_isEditing &&
                  CloudRuntimeConfig.isActive &&
                  widget.project?.cloudId != null) ...[
                OutlinedButton.icon(
                  onPressed: () => InviteDirectorSheet.show(
                    context,
                    projectCloudId: widget.project!.cloudId!,
                    projectName: widget.project!.name,
                  ),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Invitar director por email'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppButton(
                label: _isEditing ? 'Guardar cambios' : 'Crear proyecto',
                icon: _isEditing ? Icons.check : Icons.add,
                onTap: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverImagePicker extends StatelessWidget {
  final String? coverPath;
  final int iconCode;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _CoverImagePicker({
    required this.coverPath,
    required this.iconCode,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasCover = coverPath != null &&
        coverPath!.isNotEmpty &&
        File(coverPath!).existsSync();
    final icon = IconData(iconCode, fontFamily: 'MaterialIcons');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AppRadius.medium,
          child: SizedBox(
            height: 120,
            width: double.infinity,
            child: hasCover
                ? Image.file(File(coverPath!), fit: BoxFit.cover)
                : ColoredBox(
                    color: palette.surfaceOverlay,
                    child: Center(
                      child: Icon(icon, color: palette.textTertiary, size: 40),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.upload_outlined, size: 16),
              label: Text(
                hasCover ? 'Cambiar imagen' : 'Elegir imagen',
                style: AppTypography.bodyMedium(palette),
              ),
            ),
            if (hasCover)
              TextButton(
                onPressed: onRemove,
                child: Text(
                  'Quitar',
                  style: AppTypography.bodyMedium(palette)
                      .copyWith(color: palette.error),
                ),
              ),
          ],
        ),
        Text(
          'Aparece en la lista de proyectos y en la cabecera del hub.',
          style: AppTypography.caption(palette),
        ),
      ],
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? palette.accent.withValues(alpha: 0.15)
              : palette.surfaceOverlay,
          borderRadius: AppRadius.pill,
          border: Border.all(
            color: selected ? palette.accent : palette.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodyMedium(palette).copyWith(
            color: selected ? palette.accent : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}
