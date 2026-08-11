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
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../bible_block_catalog.dart';
import '../../bible_blueprint.dart';
import '../../bible_blueprint_service.dart';
import '../../bible_preset_bundle.dart';
import '../../bible_preset_service.dart';
import '../../bible_section_style_store.dart';
import '../../bible_style_showcase.dart';
import '../../../../shared/visual_bible/bible_section_fields.dart';
import '../../../../shared/visual_bible/bible_section_ids.dart';
import '../bible_navigation_scope.dart';
import '../bible_section_fields_editor.dart';
import '../bible_structure_editor.dart';

/// Master Configuration (Stitch): blueprint + estructura + vault.
class MasterConfigSection extends ConsumerStatefulWidget {
  final int bibleId;
  final int projectId;
  final VoidCallback? onStructureReset;

  const MasterConfigSection({
    super.key,
    required this.bibleId,
    required this.projectId,
    this.onStructureReset,
  });

  @override
  ConsumerState<MasterConfigSection> createState() =>
      _MasterConfigSectionState();
}

class _MasterConfigSectionState extends ConsumerState<MasterConfigSection> {
  BibleBlueprintType _blueprint = BibleBlueprintType.fiction;
  String _pdfPreset = 'gallery';
  bool _loading = true;
  String? _expandedSectionId;
  Map<String, BibleSectionStyle> _styles = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final repaired = await BibleBlueprintService.repairCorruptedTemplates(
      db: db,
      bibleId: widget.bibleId,
      projectId: widget.projectId,
    );
    final blueprint = await BibleConfigStore.loadBlueprint(widget.projectId);
    final pdf = await BibleConfigStore.loadPdfPreset(widget.projectId);
    final styles = await BibleSectionStyleStore.loadAll(widget.projectId);
    if (!mounted) return;
    setState(() {
      _blueprint = blueprint;
      _pdfPreset = pdf;
      _styles = styles;
      _loading = false;
    });
    if (repaired > 0 && mounted) {
      AppSnackBar.show(
        context,
        'Se repararon $repaired secciones (estilo vs tipo de pantalla).',
      );
    }
  }

  Future<void> _applyBlueprint(BibleBlueprintType type) async {
    if (!type.isAvailable) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        '«${type.label}» estará disponible próximamente. Usa Ficción (Plantilla 1).',
      );
      return;
    }
    final db = ref.read(databaseProvider);
    await BibleBlueprintService.apply(
      db: db,
      bibleId: widget.bibleId,
      projectId: widget.projectId,
      type: type,
    );
    final styles = await BibleSectionStyleStore.loadAll(widget.projectId);
    if (!mounted) return;
    setState(() {
      _blueprint = type;
      _styles = styles;
    });
    AppSnackBar.show(
      context,
      'Base «Plantilla 1 · ${type.label}»: estructura cinematic aplicada',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<app_db.BibleSectionGroup>>(
      stream: db.watchBibleSectionGroups(widget.bibleId),
      builder: (context, groupSnap) {
        return StreamBuilder<List<BibleSectionDefinition>>(
          stream: db.watchBibleSectionDefinitions(widget.bibleId),
          builder: (context, defSnap) {
            final groups = groupSnap.data ?? [];
            final defs = defSnap.data ?? [];

            return LayoutBuilder(
              builder: (context, constraints) {
                // En drawer estrecho o pantallas < 1100: una columna scrolleable.
                // El vault no puede ser ListView anidado sin shrinkWrap.
                final wide = constraints.maxWidth >= 1100;
                final compact = constraints.maxWidth < 560;
                final body = _MainColumn(
                  palette: palette,
                  blueprint: _blueprint,
                  styles: _styles,
                  groups: groups,
                  defs: defs,
                  expandedSectionId: _expandedSectionId,
                  compact: compact,
                  onBlueprint: _applyBlueprint,
                  onExpandSection: (id) => setState(
                    () => _expandedSectionId = _expandedSectionId == id
                        ? null
                        : id,
                  ),
                  onToggleHidden: (def, hidden) => db.setBibleSectionHidden(
                    bibleId: widget.bibleId,
                    sectionId: def.id,
                    hidden: hidden,
                  ),
                  onStyleChanged: (def, style) async {
                    await BibleSectionStyleStore.save(
                      widget.projectId,
                      def.id,
                      style,
                    );
                    setState(() => _styles = {..._styles, def.id: style});
                  },
                  onReorder: (groupId, orderedIds) =>
                      db.reorderBibleSectionsInGroup(
                        widget.bibleId,
                        groupId,
                        orderedIds,
                      ),
                  onRename: (def) => _renameSection(def),
                  onEditFields: (def) => BibleSectionFieldsEditor.show(
                    context,
                    bibleId: widget.bibleId,
                    definition: def,
                  ),
                  onDelete: (def) => _deleteSection(def),
                  onAddSection: (groupId) => _addCustomSection(groupId),
                  onInstallExamples: () => _installStyleExamples(),
                  onSaveTemplate: () => _saveTemplate(),
                  onRestoreBuiltin: () async {
                    await db.resetBibleSectionLayoutToBuiltin(widget.bibleId);
                    if (context.mounted) {
                      AppSnackBar.show(
                        context,
                        'Estructura base IRIS restaurada',
                      );
                    }
                  },
                );

                final vault = _TemplateVault(
                  bibleId: widget.bibleId,
                  projectId: widget.projectId,
                  pdfPreset: _pdfPreset,
                  onPdfPreset: (v) async {
                    await BibleConfigStore.savePdfPreset(widget.projectId, v);
                    setState(() => _pdfPreset = v);
                  },
                  onStructureReset: widget.onStructureReset,
                );

                if (!wide) {
                  return CustomScrollView(
                    slivers: [
                      ...body.slivers,
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            compact ? 16 : 32,
                            0,
                            compact ? 16 : 32,
                            48,
                          ),
                          child: vault,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: CustomScrollView(slivers: body.slivers)),
                    SizedBox(
                      width: 300,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.surfaceElevated.withValues(alpha: 0.5),
                          border: Border(
                            left: BorderSide(color: palette.border),
                          ),
                        ),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [vault],
                        ),
                      ),
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

  Future<void> _deleteSection(BibleSectionDefinition def) async {
    if (def.id == BibleSectionId.settings) return;
    final isCustom = !def.isBuiltIn;
    final ok = await showDialog<bool>(
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
    if (ok != true) return;
    final db = ref.read(databaseProvider);
    if (isCustom) {
      await db.deleteCustomBibleSection(
        bibleId: widget.bibleId,
        sectionId: def.id,
      );
      if (mounted) AppSnackBar.show(context, 'Sección eliminada');
    } else {
      await db.setBibleSectionHidden(
        bibleId: widget.bibleId,
        sectionId: def.id,
        hidden: true,
      );
      if (mounted) AppSnackBar.show(context, 'Sección ocultada');
    }
  }

  Future<void> _installStyleExamples() async {
    final created = await BibleStyleShowcase.install(
      db: ref.read(databaseProvider),
      bibleId: widget.bibleId,
      projectId: widget.projectId,
    );
    if (!mounted) return;
    AppSnackBar.show(
      context,
      created > 0
          ? 'Añadidas $created pantallas de ejemplo (Cinematic / Technical / Minimalist)'
          : 'Ejemplos de estilo actualizados',
    );
  }

  Future<void> _renameSection(BibleSectionDefinition def) async {
    final label = await _prompt(context, 'Renombrar sección', def.label);
    if (label == null || label.isEmpty) return;
    await ref
        .read(databaseProvider)
        .upsertBibleSectionDefinition(def.copyWith(label: label));
  }

  Future<void> _addCustomSection(String groupId) async {
    final label = await _prompt(context, 'Nueva sección', '');
    if (label == null || label.isEmpty) return;
    if (!mounted) return;
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
    final sectionId = await ref
        .read(databaseProvider)
        .insertCustomBibleSection(
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
    if (mounted) AppSnackBar.show(context, 'Sección «$label» creada');
  }

  Future<void> _saveTemplate() async {
    final name = await promptSaveUserTemplate(
      context,
      title: 'Guardar plantilla de biblia',
      initialName: 'Mi biblia · ${_blueprint.label}',
    );
    if (name == null || !mounted) return;
    final db = ref.read(databaseProvider);
    final id = await BiblePresetService.saveCurrentAsBundle(
      db: db,
      projectId: widget.projectId,
      bibleId: widget.bibleId,
      name: name,
      description: 'Base ${_blueprint.label} · estructura, estilos y export',
    );
    final prefs = await UserTemplatePreferences.load();
    prefs.defaultBibleLayoutTemplateId = id;
    await prefs.save();
    if (mounted) AppSnackBar.show(context, 'Plantilla «$name» guardada');
  }

  Future<String?> _prompt(
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

class _MainColumn {
  _MainColumn({
    required this.palette,
    required this.blueprint,
    required this.styles,
    required this.groups,
    required this.defs,
    required this.expandedSectionId,
    this.compact = false,
    required this.onBlueprint,
    required this.onExpandSection,
    required this.onToggleHidden,
    required this.onStyleChanged,
    required this.onReorder,
    required this.onRename,
    required this.onEditFields,
    required this.onDelete,
    required this.onAddSection,
    required this.onInstallExamples,
    required this.onSaveTemplate,
    required this.onRestoreBuiltin,
  });

  final AppPalette palette;
  final BibleBlueprintType blueprint;
  final Map<String, BibleSectionStyle> styles;
  final List<app_db.BibleSectionGroup> groups;
  final List<BibleSectionDefinition> defs;
  final String? expandedSectionId;
  final bool compact;
  final ValueChanged<BibleBlueprintType> onBlueprint;
  final ValueChanged<String> onExpandSection;
  final void Function(BibleSectionDefinition, bool) onToggleHidden;
  final void Function(BibleSectionDefinition, BibleSectionStyle) onStyleChanged;
  final void Function(String groupId, List<String> orderedIds) onReorder;
  final ValueChanged<BibleSectionDefinition> onRename;
  final ValueChanged<BibleSectionDefinition> onEditFields;
  final ValueChanged<BibleSectionDefinition> onDelete;
  final ValueChanged<String> onAddSection;
  final VoidCallback onInstallExamples;
  final VoidCallback onSaveTemplate;
  final VoidCallback onRestoreBuiltin;

  List<Widget> get slivers {
    final padH = compact ? 16.0 : 32.0;
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(padH, 24, padH, 0),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personalizar Biblia',
                style: TextStyle(
                  fontSize: compact ? 28 : 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Centraliza estructura, diseño, campos, plantillas y exportación.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.view_quilt_outlined,
                          color: palette.accent,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Estructura base',
                            style: AppTypography.titleMedium(palette),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Elige la plantilla base. Ahora solo Ficción (Plantilla 1 · Cinematic) '
                      'está operativa; Comercial y Documental llegan próximamente.',
                      style: AppTypography.caption(palette),
                    ),
                    const SizedBox(height: 16),
                    // Cards apiladas (evita GridView + Expanded rotos en drawer).
                    for (final t in BibleBlueprintType.values) ...[
                      _BlueprintCard(
                        type: t,
                        selected: blueprint == t,
                        onTap: () => onBlueprint(t),
                        compact: true,
                      ),
                      if (t != BibleBlueprintType.values.last)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estructura de la biblia',
                          style: AppTypography.titleMedium(palette),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Renombra, reordena (único drag & drop), oculta o elimina pantallas.',
                          style: AppTypography.caption(palette),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onInstallExamples,
                    icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                    label: const Text('Ejemplos de estilo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onSaveTemplate,
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Guardar plantilla'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onRestoreBuiltin,
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('Base IRIS'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(padH, 0, padH, 32),
        sliver: SliverToBoxAdapter(
          child: _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final group in groups) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Text(
                      group.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: palette.textTertiary,
                      ),
                    ),
                  ),
                  _SectionReorderList(
                    defs: defs.where((d) => d.groupId == group.id).toList(),
                    styles: styles,
                    blueprint: blueprint,
                    expandedSectionId: expandedSectionId,
                    onExpand: onExpandSection,
                    onToggleHidden: onToggleHidden,
                    onStyleChanged: onStyleChanged,
                    onReorder: (ids) => onReorder(group.id, ids),
                    onRename: onRename,
                    onEditFields: onEditFields,
                    onDelete: onDelete,
                  ),
                  TextButton.icon(
                    onPressed: () => onAddSection(group.id),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir sección personalizada'),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    ];
  }
}

class _BlueprintCard extends StatelessWidget {
  const _BlueprintCard({
    required this.type,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final BibleBlueprintType type;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: selected
          ? palette.accent.withValues(alpha: 0.12)
          : palette.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: type.isAvailable ? onTap : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: type.isAvailable ? 1 : 0.55,
          child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? palette.accent.withValues(alpha: 0.5)
                  : palette.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    type.icon,
                    color: selected ? palette.accent : palette.textSecondary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      type.availabilityLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  if (!type.isAvailable)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surfaceOverlay,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PRÓXIMAMENTE',
                        style: TextStyle(
                          fontSize: 9,
                          fontFamily: 'monospace',
                          letterSpacing: 0.6,
                          color: palette.textTertiary,
                        ),
                      ),
                    )
                  else if (selected)
                    Icon(Icons.check_circle, color: palette.accent, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                type.isAvailable
                    ? 'Plantilla 1 · estilo cinematic. ${type.subtitle}'
                    : type.subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final tag in type.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surfaceOverlay,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _SectionReorderList extends StatelessWidget {
  const _SectionReorderList({
    required this.defs,
    required this.styles,
    required this.blueprint,
    required this.expandedSectionId,
    required this.onExpand,
    required this.onToggleHidden,
    required this.onStyleChanged,
    required this.onReorder,
    required this.onRename,
    required this.onEditFields,
    required this.onDelete,
  });

  final List<BibleSectionDefinition> defs;
  final Map<String, BibleSectionStyle> styles;
  final BibleBlueprintType blueprint;
  final String? expandedSectionId;
  final ValueChanged<String> onExpand;
  final void Function(BibleSectionDefinition, bool) onToggleHidden;
  final void Function(BibleSectionDefinition, BibleSectionStyle) onStyleChanged;
  final ValueChanged<List<String>> onReorder;
  final ValueChanged<BibleSectionDefinition> onRename;
  final ValueChanged<BibleSectionDefinition> onEditFields;
  final ValueChanged<BibleSectionDefinition> onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final visible = defs;

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      onReorderItem: (oldIndex, newIndex) {
        final next = List<BibleSectionDefinition>.from(visible);
        final item = next.removeAt(oldIndex);
        next.insert(newIndex, item);
        onReorder(next.map((d) => d.id).toList());
      },
      itemBuilder: (context, index) {
        final def = visible[index];
        final style =
            styles[def.id] ?? defaultStyleForSection(def.id, blueprint);
        final dimmed = def.isHidden;
        final recommended = BibleBlueprintPacks.blocksFor(def.id, blueprint);
        final rendererLabel = BibleSectionRenderer.label(def.template);

        return Material(
          key: ValueKey(def.id),
          color: Colors.transparent,
          child: Opacity(
            opacity: dimmed ? 0.55 : 1,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                        color: dimmed ? palette.textTertiary : palette.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              def.label,
                              style: TextStyle(
                                fontSize: 14,
                                decoration: dimmed
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: palette.textPrimary,
                              ),
                            ),
                            Text(
                              'Tipo: $rendererLabel',
                              style: TextStyle(
                                fontSize: 10,
                                color: palette.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'PRESET',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: palette.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      PopupMenuButton<BibleSectionStyle>(
                        initialValue: style,
                        onSelected: (s) {
                          if (!s.isAvailable) return;
                          onStyleChanged(def, s);
                        },
                        itemBuilder: (_) => [
                          for (final s in BibleSectionStyle.values)
                            PopupMenuItem(
                              value: s,
                              enabled: s.isAvailable,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: s.dotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(s.availabilityLabel),
                                ],
                              ),
                            ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surfaceOverlay,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: palette.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: style.dotColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                style.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: palette.textPrimary,
                                ),
                              ),
                              Icon(
                                Icons.expand_more,
                                size: 14,
                                color: palette.textTertiary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Sub-apartados',
                        icon: Icon(
                          Icons.list_alt,
                          size: 18,
                          color: expandedSectionId == def.id
                              ? palette.accent
                              : palette.textSecondary,
                        ),
                        onPressed: () {
                          onExpand(def.id);
                          onEditFields(def);
                        },
                      ),
                      IconButton(
                        tooltip: 'Renombrar',
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: palette.textSecondary,
                        ),
                        onPressed: () => onRename(def),
                      ),
                      if (def.id != BibleSectionId.settings)
                        IconButton(
                          tooltip: def.isBuiltIn
                              ? 'Quitar de la biblia'
                              : 'Eliminar pantalla',
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: palette.error,
                          ),
                          onPressed: () => onDelete(def),
                        ),
                      Switch.adaptive(
                        value: !def.isHidden,
                        onChanged: (v) => onToggleHidden(def, !v),
                      ),
                    ],
                  ),
                  if (recommended.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final block in recommended.take(5))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surfaceOverlay,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: palette.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  block.icon,
                                  size: 12,
                                  color: palette.textTertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  block.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: palette.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  block.status.label,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: block.status == BibleBlockStatus.live
                                        ? palette.success
                                        : palette.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TemplateVault extends ConsumerWidget {
  const _TemplateVault({
    required this.bibleId,
    required this.projectId,
    required this.pdfPreset,
    required this.onPdfPreset,
    this.onStructureReset,
  });

  final int bibleId;
  final int projectId;
  final String pdfPreset;
  final ValueChanged<String> onPdfPreset;
  final VoidCallback? onStructureReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Text(
          'TEMPLATE VAULT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: palette.textTertiary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'PLANTILLAS DE EJEMPLO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: palette.accent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Plantilla 1 (Ficción · Cinematic) es la base operativa. '
          'Comercial y Documental llegan próximamente.',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 12),
        for (final preset in BibleBuiltinPresets.all) ...[
          _VaultCard(
            title: preset.isAvailable
                ? preset.name
                : '${preset.name} · Próximamente',
            subtitle: preset.isAvailable
                ? preset.includes.take(2).join(' · ')
                : 'No aplicable todavía',
            accent: preset.isAvailable,
            actionLabel: preset.isAvailable ? 'Aplicar' : 'Pronto',
            onAction: preset.isAvailable
                ? () async {
                    await BiblePresetService.applyBundle(
                      db: db,
                      projectId: projectId,
                      bibleId: bibleId,
                      bundle: preset,
                    );
                    if (context.mounted) {
                      AppSnackBar.show(
                        context,
                        '«${preset.name}» aplicada con datos de ejemplo',
                      );
                    }
                  }
                : () {
                    AppSnackBar.show(
                      context,
                      '«${preset.name}» estará disponible próximamente',
                    );
                  },
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        _VaultCard(
          title: 'Ejemplos de estilo · solo Cinematic',
          subtitle:
              'Technical y Minimalist llegan próximamente. '
              'Por ahora se mantiene el ejemplo cinematic.',
          accent: true,
          actionLabel: 'Añadir',
          onAction: () async {
            final created = await BibleStyleShowcase.install(
              db: db,
              bibleId: bibleId,
              projectId: projectId,
            );
            if (context.mounted) {
              AppSnackBar.show(
                context,
                created > 0
                    ? 'Ejemplos instalados ($created nuevas)'
                    : 'Ejemplos actualizados',
              );
            }
          },
        ),
        const SizedBox(height: 10),
        for (final spec in BibleStyleShowcase.specs) ...[
          _StyleExampleHint(spec: spec),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        _VaultCard(
          title: 'Base IRIS (vacía)',
          subtitle: 'Solo estructura, sin datos de ejemplo',
          accent: false,
          actionLabel: 'Apply',
          onAction: () async {
            await UserTemplateService.applyBibleLayoutTemplate(
              db: db,
              bibleId: bibleId,
              templateId: kBuiltinBibleLayoutTemplateId,
            );
            if (context.mounted) {
              AppSnackBar.show(context, 'Plantilla base IRIS aplicada');
            }
          },
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<UserTemplate>>(
          stream: UserTemplateService.watchTemplates(
            db,
            UserTemplateType.bibleLayout,
          ),
          builder: (context, snap) {
            final templates = snap.data ?? [];
            if (templates.isEmpty) {
              return Text(
                'Guarda tu biblia (layout + estilos + export) para verla aquí.',
                style: AppTypography.caption(palette),
              );
            }
            return Column(
              children: [
                for (final t in templates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VaultCard(
                      title: t.name,
                      subtitle: t.description ?? 'Plantilla personalizada',
                      accent: true,
                      actionLabel: 'Apply',
                      onAction: () async {
                        await BiblePresetService.applyById(
                          db: db,
                          projectId: projectId,
                          bibleId: bibleId,
                          templateId: t.id,
                        );
                        if (context.mounted) {
                          AppSnackBar.show(
                            context,
                            'Plantilla «${t.name}» aplicada',
                          );
                        }
                      },
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'EXPORT POR DEFECTO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: palette.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Los presets de export se configuran al pulsar «Exportar PDF». '
          'Aquí solo se guarda la última preferencia del proyecto.',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 12),
        _PdfPresetTile(
          label: 'Preferencia visual (gallery)',
          selected: pdfPreset == 'gallery',
          onTap: () => onPdfPreset('gallery'),
        ),
        const SizedBox(height: 8),
        _PdfPresetTile(
          label: 'Preferencia técnica (technical)',
          selected: pdfPreset == 'technical',
          onTap: () => onPdfPreset('technical'),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => SizedBox(
                height: MediaQuery.of(context).size.height * 0.85,
                child: BibleStructureEditor(
                  bibleId: bibleId,
                  projectId: projectId,
                  onStructureReset: onStructureReset,
                ),
              ),
            );
          },
          icon: const Icon(Icons.tune, size: 16),
          label: const Text('Editor de estructura'),
        ),
      ],
    );
  }
}

class _StyleExampleHint extends StatelessWidget {
  const _StyleExampleHint({required this.spec});

  final BibleShowcaseSpec spec;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: spec.style.dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.style.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(spec.description, style: AppTypography.caption(palette)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultCard extends StatelessWidget {
  const _VaultCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final bool accent;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent
            ? palette.accent.withValues(alpha: 0.06)
            : palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent
              ? palette.accent.withValues(alpha: 0.35)
              : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: accent ? palette.accent : palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTypography.caption(palette)),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              backgroundColor: palette.surfaceOverlay,
              foregroundColor: palette.textPrimary,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _PdfPresetTile extends StatelessWidget {
  const _PdfPresetTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? palette.accent.withValues(alpha: 0.4)
                : palette.border,
          ),
          color: selected
              ? palette.accent.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? palette.accent : palette.textTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: AppTypography.bodyMedium(palette)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surfaceElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.04),
            blurRadius: 24,
          ),
        ],
      ),
      child: child,
    );
  }
}
