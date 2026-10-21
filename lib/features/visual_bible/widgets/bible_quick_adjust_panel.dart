import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../shared/visual_bible/bible_section_ids.dart';
import '../bible_tutorial.dart';
import '../moodboard_helpers.dart';
import 'bible_section_fields_editor.dart';
import 'moodboard_sources_sidebar.dart';
import '../../settings/settings_launcher.dart';

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
            'Integración pendiente: usa la Biblioteca IRIS o una carpeta local',
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
                padding: EdgeInsets.all(
                  widget.embedded ? AppSpacing.md : AppSpacing.lg,
                ),
                children: [
                  if (isMoodboard) ...[
                    Text(
                      'FUENTES DE IMÁGENES',
                      style: AppTypography.mono(palette).copyWith(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Añade imágenes al moodboard desde aquí.',
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
                            'Integraciones',
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
                  ],
                  if (def != null && !isSettings && !widget.embedded) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        BibleSectionFieldsEditor.show(
                          context,
                          bibleId: widget.bibleId,
                          definition: def,
                        );
                      },
                      icon: const Icon(Icons.view_agenda_outlined, size: 18),
                      label: const Text('Editar puntos'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!widget.embedded) ...[
                    FilledButton.tonalIcon(
                      onPressed: widget.onOpenMasterConfig,
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('Configuración de la biblia'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => openScreenSettings(
                        context,
                        sectionId: SettingsSectionIds.bible,
                        projectId: widget.projectId,
                      ),
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Ajustes de la biblia'),
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
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
