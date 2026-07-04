import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
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

    if (_isEditing) {
      final updated = widget.project!.copyWith(
        name: name,
        director: director.isEmpty ? const Value(null) : Value(director),
        status: _status,
        iconCode: _selectedIcon,
        groupId: Value(_groupId),
        updatedAt: DateTime.now(),
      );
      await db.updateProject(updated);
    } else {
      await db.insertProject(
        ProjectsCompanion.insert(
          name: name,
          director: Value(director.isEmpty ? null : director),
          status: Value(_status),
          iconCode: Value(_selectedIcon),
          groupId: Value(_groupId),
        ),
      );
    }

    if (mounted) Navigator.pop(context);
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
                    value: _groupId,
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
