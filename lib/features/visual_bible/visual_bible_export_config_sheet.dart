import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'visual_bible_export_config.dart';
import 'visual_bible_model.dart';

/// Abre la pantalla de configuración de export PDF de la Biblia.
Future<VisualBibleExportConfig?> showVisualBibleExportConfigSheet(
  BuildContext context, {
  required int projectId,
  VisualBibleExportDestination? preferredDestination,
}) {
  final palette = context.palette;
  return showModalBottomSheet<VisualBibleExportConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => VisualBibleExportConfigSheet(
      projectId: projectId,
      preferredDestination: preferredDestination,
    ),
  );
}

class VisualBibleExportConfigSheet extends StatefulWidget {
  final int projectId;
  final VisualBibleExportDestination? preferredDestination;

  const VisualBibleExportConfigSheet({
    super.key,
    required this.projectId,
    this.preferredDestination,
  });

  @override
  State<VisualBibleExportConfigSheet> createState() =>
      _VisualBibleExportConfigSheetState();
}

class _VisualBibleExportConfigSheetState
    extends State<VisualBibleExportConfigSheet> {
  late VisualBibleExportConfig _config;
  List<VisualBibleExportConfig> _saved = const [];
  bool _loading = true;
  final _recipientsCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _config = VisualBibleExportConfig.defaults();
    if (widget.preferredDestination != null) {
      _config = _config.copyWith(destination: widget.preferredDestination);
    }
    _load();
  }

  @override
  void dispose() {
    _recipientsCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final last = await VisualBibleExportConfigStore.loadLast(widget.projectId);
    final saved =
        await VisualBibleExportConfigStore.loadAll(widget.projectId);
    if (!mounted) return;
    setState(() {
      if (last != null) {
        _config = widget.preferredDestination != null
            ? last.copyWith(destination: widget.preferredDestination)
            : last;
      }
      _saved = saved;
      _recipientsCtrl.text = _config.recipients;
      _nameCtrl.text = _config.name;
      _loading = false;
    });
  }

  void _applyPreset(VisualBibleExportConfig preset) {
    setState(() {
      _config = preset;
      _recipientsCtrl.text = preset.recipients;
      _nameCtrl.text = preset.name;
    });
  }

  void _setAudience(VisualBibleExportAudience audience) {
    setState(() {
      if (audience == VisualBibleExportAudience.general) {
        _config = _config.copyWith(
          audience: audience,
          clearDepartment: true,
          mode: _config.mode,
          sections:
              VisualBibleExportConfig.defaultSectionsForMode(_config.mode),
          name: _config.id == 'default' || _config.name.startsWith('Ficha')
              ? VisualBibleExportMode.label(_config.mode)
              : _config.name,
        );
      } else {
        final dept =
            _config.department ?? VisualBibleDepartment.gaffer;
        _config = _config.copyWith(
          audience: audience,
          department: dept,
          sections:
              VisualBibleExportConfig.defaultSectionsForDepartment(dept),
          name: _config.id == 'default' ||
                  _config.name == 'Documento general' ||
                  VisualBibleExportMode.label(_config.mode) == _config.name
              ? 'Ficha · ${VisualBibleDepartment.label(dept)}'
              : _config.name,
        );
      }
      _nameCtrl.text = _config.name;
    });
  }

  void _setMode(String mode) {
    setState(() {
      _config = _config.copyWith(
        mode: mode,
        sections: VisualBibleExportConfig.defaultSectionsForMode(mode),
        name: _config.id == 'default' ||
                _saved.every((e) => e.id != _config.id)
            ? VisualBibleExportMode.label(mode)
            : _config.name,
      );
      _nameCtrl.text = _config.name;
    });
  }

  void _setDepartment(String department) {
    setState(() {
      _config = _config.copyWith(
        department: department,
        sections:
            VisualBibleExportConfig.defaultSectionsForDepartment(department),
        name: 'Ficha · ${VisualBibleDepartment.label(department)}',
      );
      _nameCtrl.text = _config.name;
    });
  }

  void _toggleSection(String id) {
    final next = Set<String>.from(_config.sections);
    if (next.contains(id)) {
      if (next.length <= 1) return;
      next.remove(id);
    } else {
      next.add(id);
    }
    setState(() => _config = _config.copyWith(sections: next));
  }

  Future<void> _saveDocument() async {
    final name = await _promptName(
      title: 'Guardar documento de export',
      initial: _nameCtrl.text.trim().isEmpty
          ? _config.summaryLabel
          : _nameCtrl.text.trim(),
      hint: 'Ej. Ficha Gaffer — entrega eléctrica',
    );
    if (name == null || name.trim().isEmpty || !mounted) return;

    final id = _config.id == 'default'
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : _config.id;
    final saved = _config.copyWith(
      id: id,
      name: name.trim(),
      recipients: _recipientsCtrl.text.trim(),
      updatedAt: DateTime.now(),
    );
    await VisualBibleExportConfigStore.save(widget.projectId, saved);
    final all =
        await VisualBibleExportConfigStore.loadAll(widget.projectId);
    if (!mounted) return;
    setState(() {
      _config = saved;
      _saved = all;
      _nameCtrl.text = saved.name;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Documento «${saved.name}» guardado'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deletePreset(VisualBibleExportConfig preset) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar documento'),
        content: Text('¿Eliminar «${preset.name}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await VisualBibleExportConfigStore.delete(widget.projectId, preset.id);
    final all =
        await VisualBibleExportConfigStore.loadAll(widget.projectId);
    if (!mounted) return;
    setState(() {
      _saved = all;
      if (_config.id == preset.id) {
        _config = VisualBibleExportConfig.defaults().copyWith(
          destination: _config.destination,
        );
        _nameCtrl.text = _config.name;
        _recipientsCtrl.text = '';
      }
    });
  }

  Future<String?> _promptName({
    required String title,
    required String initial,
    required String hint,
  }) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  void _export() {
    final result = _config.copyWith(
      name: _nameCtrl.text.trim().isEmpty
          ? _config.summaryLabel
          : _nameCtrl.text.trim(),
      recipients: _recipientsCtrl.text.trim(),
      updatedAt: DateTime.now(),
    );
    VisualBibleExportConfigStore.saveLast(widget.projectId, result);
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.92;

    return SizedBox(
      height: height,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Exportar PDF',
                              style: AppTypography.titleMedium(palette),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Configura documento, destino y audiencia',
                              style: AppTypography.caption(palette)
                                  .copyWith(color: palette.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    children: [
                      _sectionLabel(palette, 'Documentos guardados'),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _PresetChip(
                              label: 'Nueva config',
                              selected: _config.id == 'default' &&
                                  !_saved.any((e) => e.id == _config.id),
                              icon: Icons.add,
                              onTap: () {
                                final base =
                                    VisualBibleExportConfig.defaults();
                                setState(() {
                                  _config = base.copyWith(
                                    destination: _config.destination,
                                  );
                                  _nameCtrl.text = _config.name;
                                  _recipientsCtrl.text = '';
                                });
                              },
                            ),
                            ..._saved.map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _PresetChip(
                                  label: p.name,
                                  selected: p.id == _config.id,
                                  onTap: () => _applyPreset(p),
                                  onLongPress: () => _deletePreset(p),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Nombre del documento',
                          hintText: 'Para reabrir o entregar a otro equipo',
                          filled: true,
                          fillColor: palette.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: palette.border),
                          ),
                        ),
                        onChanged: (v) =>
                            setState(() => _config = _config.copyWith(name: v)),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _sectionLabel(palette, 'Tipo de documento'),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _ChoiceCard(
                              title: 'General',
                              subtitle: 'Biblia completa o por modo',
                              icon: Icons.description_outlined,
                              selected: _config.audience ==
                                  VisualBibleExportAudience.general,
                              onTap: () => _setAudience(
                                VisualBibleExportAudience.general,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _ChoiceCard(
                              title: 'Personalizado',
                              subtitle: 'Por departamento o persona',
                              icon: Icons.groups_outlined,
                              selected: _config.audience ==
                                  VisualBibleExportAudience.customized,
                              onTap: () => _setAudience(
                                VisualBibleExportAudience.customized,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (_config.audience ==
                          VisualBibleExportAudience.general) ...[
                        _sectionLabel(palette, 'Qué PDF exportar'),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final mode in [
                              VisualBibleExportMode.full,
                              VisualBibleExportMode.pitch,
                              VisualBibleExportMode.techScout,
                            ])
                              ChoiceChip(
                                label: Text(VisualBibleExportMode.label(mode)),
                                selected: _config.mode == mode,
                                onSelected: (_) => _setMode(mode),
                              ),
                          ],
                        ),
                      ] else ...[
                        _sectionLabel(palette, 'Departamento'),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final dept in VisualBibleDepartment.all)
                              ChoiceChip(
                                label:
                                    Text(VisualBibleDepartment.label(dept)),
                                selected: _config.department == dept,
                                onSelected: (_) => _setDepartment(dept),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _recipientsCtrl,
                          decoration: InputDecoration(
                            labelText: 'Personas / equipo (opcional)',
                            hintText: 'Ej. Eléctricos A, AC cámara B',
                            filled: true,
                            fillColor: palette.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: palette.border),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          Expanded(
                            child: _sectionLabel(palette, 'Secciones'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _config = _config.copyWith(
                                  sections: BibleSectionId.all.toSet(),
                                );
                              });
                            },
                            child: const Text('Todas'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _config.isDepartment
                            ? 'La ficha de departamento usa plantilla fija; las secciones indican el foco del documento guardado.'
                            : 'Incluye solo las secciones que quieras en el PDF.',
                        style: AppTypography.caption(palette)
                            .copyWith(color: palette.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in BibleSectionId.all)
                            FilterChip(
                              label: Text(BibleSectionId.label(id)),
                              selected: _config.sections.contains(id),
                              onSelected: (_) => _toggleSection(id),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _sectionLabel(palette, 'Destino'),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _ChoiceCard(
                              title: 'Guardar archivo',
                              subtitle: 'Elegir carpeta o disco',
                              icon: Icons.folder_outlined,
                              selected: _config.destination ==
                                  VisualBibleExportDestination.saveFile,
                              onTap: () => setState(() {
                                _config = _config.copyWith(
                                  destination:
                                      VisualBibleExportDestination.saveFile,
                                );
                              }),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _ChoiceCard(
                              title: 'Compartir',
                              subtitle: 'AirDrop, mail, apps',
                              icon: Icons.ios_share,
                              selected: _config.destination ==
                                  VisualBibleExportDestination.share,
                              onTap: () => setState(() {
                                _config = _config.copyWith(
                                  destination:
                                      VisualBibleExportDestination.share,
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 18, color: palette.textSecondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Guarda el documento para reabrirlo, ajustar secciones '
                                'y volver a exportarlo para otro equipo.',
                                style: AppTypography.caption(palette)
                                    .copyWith(color: palette.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md + bottom,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceElevated,
                    border: Border(
                      top: BorderSide(color: palette.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saveDocument,
                          icon: const Icon(Icons.bookmark_add_outlined),
                          label: const Text('Guardar documento'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _config.sections.isEmpty ? null : _export,
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: Text(
                            _config.destination ==
                                    VisualBibleExportDestination.share
                                ? 'Compartir PDF'
                                : 'Exportar PDF',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionLabel(AppPalette palette, String text) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.label(palette).copyWith(
            letterSpacing: 0.8,
            color: palette.accent,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: selected ? palette.accentMuted : palette.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: palette.accent),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTypography.label(palette).copyWith(
                  color: selected ? palette.accent : palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: selected ? palette.accentMuted : palette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? palette.accent : palette.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: AppTypography.titleMedium(palette).copyWith(
                  fontSize: 14,
                  color: selected ? palette.accent : palette.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.caption(palette)
                    .copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
