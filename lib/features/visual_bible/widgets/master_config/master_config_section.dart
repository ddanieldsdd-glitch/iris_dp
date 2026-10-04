import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart' hide BibleSectionGroup;
import '../../../../core/database/app_database.dart'
    as app_db
    show BibleSectionGroup;
import '../../../../core/database/database_provider.dart';
import '../../../../core/settings/user_templates_settings_section.dart';
import '../../../../core/templates/user_template_models.dart';
import '../../../../core/templates/user_template_preferences.dart';
import '../../../../core/templates/user_template_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../shared/visual_bible/bible_section_ids.dart';
import '../../bible_blueprint_service.dart';
import '../../bible_preset_service.dart';
import '../bible_navigation_scope.dart';
import '../bible_screen_library_sheet.dart';
import '../bible_section_fields_editor.dart';

/// Configuración de la biblia: sus pantallas y sus plantillas.
///
/// Cada acción existe una sola vez. Las que reemplazan la estructura piden
/// confirmación y ninguna borra lo escrito.
class MasterConfigSection extends ConsumerStatefulWidget {
  final int bibleId;
  final int projectId;

  const MasterConfigSection({
    super.key,
    required this.bibleId,
    required this.projectId,
  });

  @override
  ConsumerState<MasterConfigSection> createState() =>
      _MasterConfigSectionState();
}

class _MasterConfigSectionState extends ConsumerState<MasterConfigSection> {
  @override
  void initState() {
    super.initState();
    unawaited(
      BibleBlueprintService.repairCorruptedTemplates(
        db: ref.read(databaseProvider),
        bibleId: widget.bibleId,
        projectId: widget.projectId,
      ),
    );
  }

  AppDatabase get _db => ref.read(databaseProvider);

  // ── Pantallas ────────────────────────────────────────────────────────────

  Future<void> _renameGroup(app_db.BibleSectionGroup group) async {
    final label = await _promptName('Renombrar grupo', group.label);
    if (label == null || label.isEmpty) return;
    await _db.upsertBibleSectionGroup(group.copyWith(label: label));
  }

  Future<void> _renameScreen(BibleSectionDefinition def) async {
    final label = await _promptName('Renombrar pantalla', def.label);
    if (label == null || label.isEmpty) return;
    await _db.upsertBibleSectionDefinition(def.copyWith(label: label));
  }

  Future<void> _addCustomScreen(String groupId) async {
    final label = await _promptName('Nueva pantalla', '');
    if (label == null || label.isEmpty) return;
    await _db.insertCustomBibleSection(
      bibleId: widget.bibleId,
      groupId: groupId,
      label: label,
    );
    if (mounted) AppSnackBar.show(context, 'Pantalla «$label» creada');
  }

  Future<void> _addFromLibrary(List<BibleSectionDefinition> defs) async {
    await BibleScreenLibrarySheet.show(
      context,
      existingSectionIds: defs.map((d) => d.id).toSet(),
      onAdd: (sectionId) => _db.addBuiltinBibleSection(
        bibleId: widget.bibleId,
        sectionId: sectionId,
      ),
    );
  }

  Future<void> _deleteScreen(BibleSectionDefinition def) async {
    final ok = await _confirm(
      title: 'Eliminar «${def.label}»',
      body:
          'Es una pantalla que creaste tú. Se borra con todo su contenido y '
          'no se puede recuperar.\n\nSi solo quieres que no se vea, ocúltala '
          'con el interruptor.',
      action: 'Eliminar pantalla',
    );
    if (!ok) return;
    await _db.deleteCustomBibleSection(
      bibleId: widget.bibleId,
      sectionId: def.id,
    );
    if (mounted) AppSnackBar.show(context, 'Pantalla eliminada');
  }

  // ── Plantillas ───────────────────────────────────────────────────────────

  Future<void> _saveTemplate() async {
    final name = await promptSaveUserTemplate(
      context,
      title: 'Guardar como plantilla',
      initialName: 'Mi biblia',
    );
    if (name == null || !mounted) return;
    final id = await BiblePresetService.saveCurrentAsBundle(
      db: _db,
      projectId: widget.projectId,
      bibleId: widget.bibleId,
      name: name,
      description: 'Pantallas y puntos, sin contenido',
    );
    if (!mounted) return;
    final asDefault = await _confirm(
      title: 'Plantilla «$name» guardada',
      body:
          'Guarda las pantallas y sus puntos, no lo que has escrito.\n\n'
          '¿Quieres usarla en los proyectos nuevos?',
      action: 'Usar en proyectos nuevos',
      cancel: 'Ahora no',
    );
    if (!asDefault) return;
    final prefs = await UserTemplatePreferences.load();
    prefs.defaultBibleLayoutTemplateId = id;
    prefs.bibleAutoApply = TemplateAutoApplyMode.always;
    await prefs.save();
    await UserTemplateService.setDefaultTemplate(
      _db,
      UserTemplateType.bibleLayout,
      id,
    );
  }

  Future<void> _applyTemplate() async {
    final templates = await UserTemplateService.listTemplates(
      _db,
      UserTemplateType.bibleLayout,
    );
    if (!mounted) return;
    if (templates.isEmpty) {
      AppSnackBar.show(
        context,
        'Aún no tienes plantillas. Crea una con «Guardar como plantilla».',
      );
      return;
    }

    final picked = await showModalBottomSheet<UserTemplate>(
      context: context,
      backgroundColor: context.palette.surfaceElevated,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Aplicar plantilla')),
            for (final t in templates)
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: Text(t.name),
                subtitle: t.description != null ? Text(t.description!) : null,
                onTap: () => Navigator.pop(ctx, t),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final ok = await _confirm(
      title: 'Aplicar «${picked.name}»',
      body:
          'Las pantallas y sus puntos pasan a ser los de la plantilla.\n\n'
          'Lo que has escrito se conserva. Las pantallas que la plantilla no '
          'tiene quedan ocultas, y los puntos que añadiste tú quedan al final '
          'de su pantalla.',
      action: 'Aplicar',
    );
    if (!ok) return;

    await BiblePresetService.applyById(
      db: _db,
      projectId: widget.projectId,
      bibleId: widget.bibleId,
      templateId: picked.id,
      applySampleSeed: false,
    );
    final prefs = await UserTemplatePreferences.load();
    if (prefs.bibleAutoApply == TemplateAutoApplyMode.perProject) {
      prefs.projectBibleTemplateIds[widget.projectId] = picked.id;
      await prefs.save();
    }
    if (mounted) {
      AppSnackBar.show(context, 'Plantilla «${picked.name}» aplicada');
    }
  }

  Future<void> _resetStructure() async {
    final ok = await _confirm(
      title: 'Restablecer estructura',
      body:
          'Vuelven las pantallas originales de IRIS, con su orden, sus '
          'nombres y sus puntos.\n\n'
          'Lo que has escrito se conserva. Las pantallas que creaste tú '
          'quedan ocultas, y los puntos que añadiste quedan al final de su '
          'pantalla.',
      action: 'Restablecer',
    );
    if (!ok) return;
    await _db.resetBibleSectionLayoutToBuiltin(widget.bibleId);
    if (mounted) AppSnackBar.show(context, 'Estructura restablecida');
  }

  // ── Diálogos ─────────────────────────────────────────────────────────────

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    String cancel = 'Cancelar',
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<String?> _promptName(String title, String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<app_db.BibleSectionGroup>>(
      stream: db.watchBibleSectionGroups(widget.bibleId),
      builder: (context, groupSnap) {
        return StreamBuilder<List<BibleSectionDefinition>>(
          stream: db.watchBibleSectionDefinitions(widget.bibleId),
          builder: (context, defSnap) {
            final groups = groupSnap.data ?? const [];
            final defs = defSnap.data ?? const <BibleSectionDefinition>[];

            return LayoutBuilder(
              builder: (context, constraints) {
                final pad = constraints.maxWidth < 560
                    ? AppSpacing.md
                    : AppSpacing.xl;
                return ListView(
                  padding: EdgeInsets.all(pad),
                  children: [
                    Text(
                      'Configuración de la biblia',
                      style: AppTypography.titleLarge(palette),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Una biblia tiene pantallas, y cada pantalla tiene '
                      'puntos. El orden de aquí es el del lateral y el del PDF.',
                      style: AppTypography.bodyMedium(
                        palette,
                      ).copyWith(color: palette.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ConfigBlock(
                      icon: Icons.view_agenda_outlined,
                      title: 'Pantallas',
                      description:
                          'Arrastra para ordenar. El interruptor muestra u '
                          'oculta una pantalla sin borrar su contenido.',
                      trailing: OutlinedButton.icon(
                        onPressed: () => _addFromLibrary(defs),
                        icon: const Icon(Icons.library_add_outlined, size: 16),
                        label: const Text('Añadir de la biblioteca'),
                      ),
                      children: [
                        for (final group in groups) ...[
                          _GroupHeader(
                            label: group.label,
                            onRename: () => _renameGroup(group),
                          ),
                          _ScreenList(
                            defs: defs
                                .where((d) => d.groupId == group.id)
                                .toList(),
                            onReorder: (ids) => db.reorderBibleSectionsInGroup(
                              widget.bibleId,
                              group.id,
                              ids,
                            ),
                            onToggleHidden: (def, hidden) =>
                                db.setBibleSectionHidden(
                                  bibleId: widget.bibleId,
                                  sectionId: def.id,
                                  hidden: hidden,
                                ),
                            onEditPoints: (def) =>
                                BibleSectionFieldsEditor.show(
                                  context,
                                  bibleId: widget.bibleId,
                                  definition: def,
                                ),
                            onRename: _renameScreen,
                            onDelete: _deleteScreen,
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _addCustomScreen(group.id),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Crear pantalla personalizada'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ConfigBlock(
                      icon: Icons.bookmarks_outlined,
                      title: 'Plantillas',
                      description:
                          'Una plantilla guarda las pantallas y sus puntos, '
                          'no lo que has escrito. Aplicar una plantilla o '
                          'restablecer nunca borra contenido.',
                      children: [
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _saveTemplate,
                              icon: const Icon(Icons.save_outlined, size: 18),
                              label: const Text('Guardar como plantilla'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _applyTemplate,
                              icon: const Icon(
                                Icons.file_open_outlined,
                                size: 18,
                              ),
                              label: const Text('Aplicar plantilla'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _resetStructure,
                              icon: const Icon(Icons.restart_alt, size: 18),
                              label: const Text('Restablecer estructura'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ConfigBlock extends StatelessWidget {
  const _ConfigBlock({
    required this.icon,
    required this.title,
    required this.description,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surfaceElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: palette.accent, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Text(title, style: AppTypography.titleMedium(palette)),
                ],
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(description, style: AppTypography.caption(palette)),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.onRename});

  final String label;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: AppTypography.caption(palette).copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: palette.textTertiary,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 16),
          tooltip: 'Renombrar grupo',
          onPressed: onRename,
        ),
      ],
    );
  }
}

class _ScreenList extends StatelessWidget {
  const _ScreenList({
    required this.defs,
    required this.onReorder,
    required this.onToggleHidden,
    required this.onEditPoints,
    required this.onRename,
    required this.onDelete,
  });

  final List<BibleSectionDefinition> defs;
  final ValueChanged<List<String>> onReorder;
  final void Function(BibleSectionDefinition, bool hidden) onToggleHidden;
  final ValueChanged<BibleSectionDefinition> onEditPoints;
  final ValueChanged<BibleSectionDefinition> onRename;
  final ValueChanged<BibleSectionDefinition> onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: defs.length,
      onReorderItem: (oldIndex, newIndex) {
        final next = List<BibleSectionDefinition>.from(defs);
        next.insert(newIndex, next.removeAt(oldIndex));
        onReorder(next.map((d) => d.id).toList());
      },
      itemBuilder: (context, index) {
        final def = defs[index];
        final isSettings = def.id == BibleSectionId.settings;
        final hidden = def.isHidden;

        return Material(
          key: ValueKey(def.id),
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_indicator,
                    size: 18,
                    color: palette.textTertiary,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  bibleIconFromKey(def.iconKey),
                  size: 18,
                  color: hidden ? palette.textTertiary : palette.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.label,
                        style: AppTypography.bodyMedium(palette).copyWith(
                          color: hidden
                              ? palette.textTertiary
                              : palette.textPrimary,
                        ),
                      ),
                      if (hidden || !def.isBuiltIn)
                        Text(
                          [
                            if (!def.isBuiltIn) 'Personalizada',
                            if (hidden) 'Oculta',
                          ].join(' · '),
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(color: palette.textTertiary),
                        ),
                    ],
                  ),
                ),
                if (!isSettings)
                  IconButton(
                    tooltip: 'Puntos',
                    icon: const Icon(Icons.list_alt, size: 18),
                    onPressed: () => onEditPoints(def),
                  ),
                IconButton(
                  tooltip: 'Renombrar',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => onRename(def),
                ),
                if (!def.isBuiltIn)
                  IconButton(
                    tooltip: 'Eliminar pantalla',
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: palette.error,
                    ),
                    onPressed: () => onDelete(def),
                  ),
                if (!isSettings)
                  Tooltip(
                    message: hidden ? 'Mostrar' : 'Ocultar',
                    child: Switch.adaptive(
                      value: !hidden,
                      onChanged: (v) => onToggleHidden(def, !v),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
