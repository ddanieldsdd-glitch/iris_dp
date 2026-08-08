import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart' hide BibleSectionGroup;
import '../../../core/database/app_database.dart'
    as app_db
    show BibleSectionGroup;
import '../../../core/database/database_provider.dart';
import '../../../core/settings/user_templates_settings_section.dart';
import '../../../core/templates/user_template_models.dart';
import '../../../core/templates/user_template_preferences.dart';
import '../../../core/templates/user_template_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../shared/visual_bible/bible_section_fields.dart';
import '../../../shared/visual_bible/bible_section_ids.dart';
import '../bible_blueprint.dart';
import '../bible_section_style_store.dart';
import 'bible_navigation_scope.dart';
import 'bible_section_fields_editor.dart';

/// Editor de estructura: renombrar, ocultar/eliminar y sub-apartados.
/// El reordenamiento vive en el área central de Personalizar Biblia.
class BibleStructureEditor extends ConsumerStatefulWidget {
  final int bibleId;
  final int projectId;
  final VoidCallback? onStructureReset;
  final bool compact;

  const BibleStructureEditor({
    super.key,
    required this.bibleId,
    required this.projectId,
    this.onStructureReset,
    this.compact = false,
  });

  @override
  ConsumerState<BibleStructureEditor> createState() =>
      _BibleStructureEditorState();
}

class _BibleStructureEditorState extends ConsumerState<BibleStructureEditor> {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<app_db.BibleSectionGroup>>(
      stream: db.watchBibleSectionGroups(widget.bibleId),
      builder: (context, groupSnap) {
        final groups = groupSnap.data ?? [];
        return StreamBuilder<List<BibleSectionDefinition>>(
          stream: db.watchBibleSectionDefinitions(widget.bibleId),
          builder: (context, defSnap) {
            final defs = defSnap.data ?? [];
            if (widget.compact) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  for (final group in groups) ...[
                    Text(
                      group.label.toUpperCase(),
                      style: AppTypography.mono(palette).copyWith(
                        fontSize: 10,
                        letterSpacing: 1,
                        color: palette.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CompactReorderList(
                      defs: defs
                          .where((d) => d.groupId == group.id && !d.isHidden)
                          .toList()
                        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
                      onReorder: (ids) => ref
                          .read(databaseProvider)
                          .reorderBibleSectionsInGroup(
                            widget.bibleId,
                            group.id,
                            ids,
                          ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            }
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Estructura de la biblia',
                      style: AppTypography.titleMedium(palette),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Renombra, oculta o elimina pantallas. Para cambiar el orden, '
                      'abre Personalizar Biblia (un solo drag & drop).',
                      style: AppTypography.caption(palette),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _TemplateToolbar(
                      bibleId: widget.bibleId,
                      projectId: widget.projectId,
                      onStructureReset: widget.onStructureReset,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final group in groups) ...[
                            _GroupHeader(
                              label: group.label,
                              onRename: () => _renameGroup(context, group),
                            ),
                            _SectionManageList(
                              defs: defs
                                  .where(
                                    (d) => d.groupId == group.id && !d.isHidden,
                                  )
                                  .toList(),
                              onRename: (def) => _renameSection(context, def),
                              onEditFields: (def) =>
                                  BibleSectionFieldsEditor.show(
                                    context,
                                    bibleId: widget.bibleId,
                                    definition: def,
                                  ),
                              onToggleHidden: (def, hidden) => ref
                                  .read(databaseProvider)
                                  .setBibleSectionHidden(
                                    bibleId: widget.bibleId,
                                    sectionId: def.id,
                                    hidden: hidden,
                                  ),
                              onDelete: (def) {
                                if (def.id == BibleSectionId.settings) return;
                                _deleteSection(context, def);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.add, size: 20),
                              title: const Text('Añadir sección personalizada'),
                              onTap: () => _addCustomSection(context, group.id),
                            ),
                            const Divider(height: 24),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _renameGroup(
    BuildContext context,
    app_db.BibleSectionGroup group,
  ) async {
    final label = await _promptLabel(context, 'Renombrar grupo', group.label);
    if (label == null || label.isEmpty) return;
    final db = ref.read(databaseProvider);
    await db.upsertBibleSectionGroup(group.copyWith(label: label));
  }

  Future<void> _renameSection(
    BuildContext context,
    BibleSectionDefinition def,
  ) async {
    final label = await _promptLabel(context, 'Renombrar sección', def.label);
    if (label == null || label.isEmpty) return;
    final db = ref.read(databaseProvider);
    await db.upsertBibleSectionDefinition(def.copyWith(label: label));
  }

  Future<void> _addCustomSection(BuildContext context, String groupId) async {
    final label = await _promptLabel(context, 'Nueva sección', '');
    if (label == null || label.isEmpty) return;
    if (!context.mounted) return;
    final style = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Plantilla de partida')),
            ListTile(
              title: const Text('Cinematic'),
              onTap: () => Navigator.pop(ctx, 'cinematic'),
            ),
            ListTile(
              title: const Text('Technical'),
              onTap: () => Navigator.pop(ctx, 'technical'),
            ),
            ListTile(
              title: const Text('Minimalist'),
              onTap: () => Navigator.pop(ctx, 'minimalist'),
            ),
          ],
        ),
      ),
    );
    final styleKey = style ?? 'cinematic';
    final fields = BibleSectionFieldsConfig.packForStyle(
      styleKey,
      sectionLabel: label,
    );
    final db = ref.read(databaseProvider);
    final sectionId = await db.insertCustomBibleSection(
      bibleId: widget.bibleId,
      groupId: groupId,
      label: label,
      contentJson: BibleSectionFieldsConfig.encode(fields),
    );
    await BibleSectionStyleStore.save(
      widget.projectId,
      sectionId,
      BibleSectionStyle.values.firstWhere(
        (e) => e.name == styleKey,
        orElse: () => BibleSectionStyle.cinematic,
      ),
    );
    if (context.mounted) {
      AppSnackBar.show(context, 'Sección «$label» creada');
    }
  }

  Future<void> _deleteSection(
    BuildContext context,
    BibleSectionDefinition def,
  ) async {
    final isCustom = !def.isBuiltIn;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCustom ? 'Eliminar sección' : 'Quitar sección'),
        content: Text(
          isCustom
              ? '¿Eliminar «${def.label}»?'
              : '¿Ocultar «${def.label}» de esta biblia?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isCustom ? 'Eliminar' : 'Quitar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final db = ref.read(databaseProvider);
    if (isCustom) {
      await db.deleteCustomBibleSection(
        bibleId: widget.bibleId,
        sectionId: def.id,
      );
      if (context.mounted) {
        AppSnackBar.show(context, 'Sección eliminada');
      }
    } else {
      await db.setBibleSectionHidden(
        bibleId: widget.bibleId,
        sectionId: def.id,
        hidden: true,
      );
      if (context.mounted) {
        AppSnackBar.show(context, 'Sección ocultada');
      }
    }
  }

  Future<String?> _promptLabel(
    BuildContext context,
    String title,
    String initial,
  ) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _TemplateToolbar extends ConsumerWidget {
  final int bibleId;
  final int projectId;
  final VoidCallback? onStructureReset;

  const _TemplateToolbar({
    required this.bibleId,
    required this.projectId,
    this.onStructureReset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Guardar como plantilla'),
          onPressed: () async {
            final name = await promptSaveUserTemplate(
              context,
              title: 'Guardar estructura de biblia',
              initialName: 'Mi biblia de fotografía',
            );
            if (name == null || !context.mounted) return;
            final id = await UserTemplateService.saveBibleLayoutTemplate(
              db: db,
              name: name,
              bibleId: bibleId,
            );
            final prefs = await UserTemplatePreferences.load();
            if (!context.mounted) return;
            final setDefault = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Plantilla predeterminada'),
                content: const Text(
                  '¿Usar esta plantilla como predeterminada para '
                  'nuevos proyectos?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('No'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sí, predeterminada'),
                  ),
                ],
              ),
            );
            if (setDefault == true) {
              prefs.defaultBibleLayoutTemplateId = id;
              prefs.bibleAutoApply = TemplateAutoApplyMode.always;
              await prefs.save();
              await UserTemplateService.setDefaultTemplate(
                db,
                UserTemplateType.bibleLayout,
                id,
              );
            }
            if (context.mounted) {
              AppSnackBar.show(context, 'Plantilla «$name» guardada');
            }
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.file_open_outlined, size: 18),
          label: const Text('Aplicar plantilla'),
          onPressed: () => _applyTemplate(context, ref),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
          label: const Text('Resetear estructura'),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Resetear estructura'),
                content: const Text(
                  'Se eliminarán todas las pantallas y grupos de la biblia. '
                  'El contenido técnico (moodboard, bloques de color, specs) '
                  'se conservará. Volverás a elegir cómo empezar.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Resetear'),
                  ),
                ],
              ),
            );
            if (ok != true) return;
            await db.resetBibleStructureToEmpty(bibleId);
            if (context.mounted) {
              Navigator.pop(context);
              onStructureReset?.call();
              AppSnackBar.show(context, 'Estructura reseteada');
            }
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.restore_outlined, size: 18),
          label: const Text('Restaurar base IRIS'),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Restaurar plantilla base'),
                content: const Text(
                  'Se restaurará la estructura original de la biblia IRIS. '
                  'Los nombres y sub-apartados personalizados se perderán.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Restaurar'),
                  ),
                ],
              ),
            );
            if (ok != true) return;
            await db.resetBibleSectionLayoutToBuiltin(bibleId);
            if (context.mounted) {
              AppSnackBar.show(context, 'Estructura base restaurada');
            }
          },
        ),
      ],
    );
  }

  Future<void> _applyTemplate(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final templates = await UserTemplateService.listTemplates(
      db,
      UserTemplateType.bibleLayout,
    );
    if (!context.mounted) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.palette.surfaceElevated,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_stories_outlined),
              title: const Text('Plantilla IRIS (base de fotografía)'),
              onTap: () => Navigator.pop(ctx, kBuiltinBibleLayoutTemplateId),
            ),
            for (final t in templates)
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: Text(t.name),
                subtitle: t.description != null ? Text(t.description!) : null,
                onTap: () => Navigator.pop(ctx, t.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aplicar plantilla'),
        content: const Text(
          'Se reemplazará la estructura actual (grupos, secciones y '
          'sub-apartados). El contenido escrito se conserva donde los IDs coincidan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await UserTemplateService.applyBibleLayoutTemplate(
      db: db,
      bibleId: bibleId,
      templateId: picked,
    );

    final prefs = await UserTemplatePreferences.load();
    if (prefs.bibleAutoApply == TemplateAutoApplyMode.perProject) {
      prefs.projectBibleTemplateIds[projectId] = picked;
      await prefs.save();
    }

    if (context.mounted) {
      AppSnackBar.show(context, 'Plantilla aplicada');
    }
  }
}

class _SectionManageList extends StatelessWidget {
  final List<BibleSectionDefinition> defs;
  final void Function(BibleSectionDefinition def) onRename;
  final void Function(BibleSectionDefinition def) onEditFields;
  final void Function(BibleSectionDefinition def, bool hidden)? onToggleHidden;
  final void Function(BibleSectionDefinition def)? onDelete;

  const _SectionManageList({
    required this.defs,
    required this.onRename,
    required this.onEditFields,
    this.onToggleHidden,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      children: [
        for (final def in defs)
          ListTile(
            key: ValueKey(def.id),
            leading: Icon(bibleIconFromKey(def.iconKey), size: 20),
            title: Text(def.label),
            subtitle: def.isBuiltIn
                ? null
                : Text('Personalizada', style: AppTypography.caption(palette)),
            trailing: SizedBox(
              width: onDelete != null && onToggleHidden != null ? 192 : 144,
              child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onToggleHidden != null)
                  IconButton(
                    icon: Icon(
                      def.isHidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                    tooltip: def.isHidden
                        ? 'Mostrar sección'
                        : 'Ocultar sección',
                    onPressed: () => onToggleHidden!(def, !def.isHidden),
                  ),
                IconButton(
                  icon: const Icon(Icons.view_list_outlined, size: 18),
                  tooltip: 'Sub-apartados',
                  onPressed: () => onEditFields(def),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => onRename(def),
                ),
                if (onDelete != null && def.id != 'settings')
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: palette.error,
                    ),
                    tooltip: def.isBuiltIn
                        ? 'Quitar de la biblia'
                        : 'Eliminar pantalla',
                    onPressed: () => onDelete!(def),
                  ),
              ],
            ),
          ),
          ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  final VoidCallback onRename;

  const _GroupHeader({required this.label, required this.onRename});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: AppTypography.caption(
                palette,
              ).copyWith(letterSpacing: 1.1, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: onRename,
            tooltip: 'Renombrar grupo',
          ),
        ],
      ),
    );
  }
}

class _CompactReorderList extends StatelessWidget {
  final List<BibleSectionDefinition> defs;
  final ValueChanged<List<String>> onReorder;

  const _CompactReorderList({
    required this.defs,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: defs.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final next = List<BibleSectionDefinition>.from(defs);
        final item = next.removeAt(oldIndex);
        next.insert(newIndex, item);
        onReorder(next.map((d) => d.id).toList());
      },
      itemBuilder: (context, index) {
        final def = defs[index];
        return Material(
          key: ValueKey(def.id),
          color: palette.surfaceOverlay,
          borderRadius: BorderRadius.circular(8),
          child: ListTile(
            dense: true,
            leading: ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_handle, color: palette.textTertiary, size: 18),
            ),
            title: Text(
              def.label,
              style: AppTypography.bodyMedium(palette).copyWith(fontSize: 13),
            ),
            trailing: Icon(bibleIconFromKey(def.iconKey), size: 16, color: palette.accent),
          ),
        );
      },
    );
  }
}
