import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../shared/visual_bible/bible_section_ids.dart';
import '../bible_blueprint.dart';
import '../bible_section_style_store.dart';
import '../bible_tutorial.dart';
import '../moodboard_helpers.dart';
import 'bible_section_fields_editor.dart';
import 'moodboard_sources_sidebar.dart';

/// Panel contextual de ajuste rápido según la sección activa.
class BibleQuickAdjustPanel extends ConsumerStatefulWidget {
  final int bibleId;
  final int projectId;
  final String sectionId;
  final VoidCallback onOpenMasterConfig;
  final VoidCallback? onClose;
  final bool embedded;

  const BibleQuickAdjustPanel({
    super.key,
    required this.bibleId,
    required this.projectId,
    required this.sectionId,
    required this.onOpenMasterConfig,
    this.onClose,
    this.embedded = false,
  });

  @override
  ConsumerState<BibleQuickAdjustPanel> createState() =>
      _BibleQuickAdjustPanelState();
}

class _BibleQuickAdjustPanelState extends ConsumerState<BibleQuickAdjustPanel> {
  BibleSectionStyle? _style;
  bool _loadingStyle = true;

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  @override
  void didUpdateWidget(BibleQuickAdjustPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sectionId != widget.sectionId ||
        oldWidget.projectId != widget.projectId) {
      _loadStyle();
    }
  }

  Future<void> _loadStyle() async {
    setState(() => _loadingStyle = true);
    final style = await BibleSectionStyleStore.load(
      widget.projectId,
      widget.sectionId,
    );
    if (!mounted) return;
    setState(() {
      _style = style;
      _loadingStyle = false;
    });
  }

  Future<void> _setStyle(BibleSectionStyle style) async {
    setState(() => _style = style);
    await BibleSectionStyleStore.save(
      widget.projectId,
      widget.sectionId,
      style,
    );
    if (mounted) {
      AppSnackBar.show(context, 'Densidad «${style.label}» aplicada');
    }
  }

  Future<void> _importMoodboard(MoodboardSourceKind kind) async {
    final db = ref.read(databaseProvider);
    switch (kind) {
      case MoodboardSourceKind.irisLibrary:
      case MoodboardSourceKind.personalLibrary:
      case MoodboardSourceKind.localFolder:
        await MoodboardHelpers.addManualImages(
          db: db,
          projectId: widget.projectId,
          bibleId: widget.bibleId,
          assignedSections: widget.sectionId == BibleSectionId.moodboard
              ? const []
              : [widget.sectionId],
        );
        if (mounted) {
          AppSnackBar.show(context, 'Imágenes añadidas al moodboard');
          widget.onClose?.call();
        }
      case MoodboardSourceKind.shotDeck:
      case MoodboardSourceKind.filmGrab:
      case MoodboardSourceKind.tmdb:
      case MoodboardSourceKind.imdb:
        if (mounted) {
          AppSnackBar.show(
            context,
            'Integración pendiente — usa Biblioteca IRIS o carpeta local',
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isMoodboard = widget.sectionId == BibleSectionId.moodboard;
    final isSettings = widget.sectionId == BibleSectionId.settings;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<BibleSectionDefinition>>(
      stream: widget.bibleId > 0
          ? db.watchBibleSectionDefinitions(widget.bibleId)
          : Stream.value(const []),
      builder: (context, snap) {
        final defs = snap.data ?? const <BibleSectionDefinition>[];
        final def = defs.where((d) => d.id == widget.sectionId).firstOrNull;
        final sectionTitle = (def != null && def.label.trim().isNotEmpty)
            ? def.label
            : BibleSectionId.label(widget.sectionId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.embedded) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.tune, color: palette.accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ajustes de pantalla',
                            style: AppTypography.titleMedium(palette),
                          ),
                          Text(
                            sectionTitle,
                            style: AppTypography.caption(
                              palette,
                            ).copyWith(color: palette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onClose != null)
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: widget.onClose,
                        icon: Icon(Icons.close, color: palette.textSecondary),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: palette.border),
            ],
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(widget.embedded ? AppSpacing.md : AppSpacing.lg),
                children: [
                  if (isMoodboard) ...[
                    Text(
                      'VISUAL SOURCES',
                      style: AppTypography.mono(palette).copyWith(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Importa stills sin ocupar el canvas del moodboard.',
                      style: AppTypography.caption(
                        palette,
                      ).copyWith(color: palette.textTertiary),
                    ),
                    const SizedBox(height: 12),
                    for (final item in kMoodboardSources) ...[
                      if (item.kind == MoodboardSourceKind.shotDeck)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            'Integrations',
                            style: AppTypography.caption(
                              palette,
                            ).copyWith(color: palette.textTertiary),
                          ),
                        ),
                      if (item.kind == MoodboardSourceKind.personalLibrary)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            'Local',
                            style: AppTypography.caption(
                              palette,
                            ).copyWith(color: palette.textTertiary),
                          ),
                        ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        enabled: item.enabled,
                        leading: Icon(
                          item.icon,
                          color: item.enabled
                              ? palette.accent
                              : palette.textTertiary,
                        ),
                        title: Text(item.label),
                        subtitle: item.badge != null ? Text(item.badge!) : null,
                        onTap: item.enabled
                            ? () => _importMoodboard(item.kind)
                            : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Divider(color: palette.border),
                    const SizedBox(height: 16),
                  ],
                  if (!isSettings) ...[
                    Text(
                      'ESTILO DE PANTALLA',
                      style: AppTypography.mono(palette).copyWith(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_loadingStyle)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in BibleSectionStyle.values)
                            ChoiceChip(
                              label: Text(s.label),
                              selected: _style == s,
                              onSelected: (_) => _setStyle(s),
                              selectedColor: palette.accent.withValues(
                                alpha: 0.2,
                              ),
                              labelStyle: TextStyle(
                                color: _style == s
                                    ? palette.accent
                                    : palette.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    if (def != null && !widget.embedded) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          BibleSectionFieldsEditor.show(
                            context,
                            bibleId: widget.bibleId,
                            definition: def,
                          );
                        },
                        icon: const Icon(Icons.view_agenda_outlined, size: 18),
                        label: const Text('Editar sub-apartados'),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                  if (!widget.embedded) ...[
                    FilledButton.tonalIcon(
                      onPressed: widget.onOpenMasterConfig,
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('Estructura y plantillas'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await BibleTutorial.reset(widget.projectId);
                        if (context.mounted) {
                          await BibleTutorial.show(context, widget.projectId);
                        }
                      },
                      icon: const Icon(Icons.school_outlined, size: 18),
                      label: const Text('Ver tutorial de la Biblia'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Todas las opciones pertenecen al mismo sistema de personalización.',
                    style: AppTypography.caption(
                      palette,
                    ).copyWith(color: palette.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
