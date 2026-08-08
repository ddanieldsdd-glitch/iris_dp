import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_layout.dart';
import '../../../shared/visual_bible/bible_section_ids.dart';

class BibleScreenLibrarySheet extends StatelessWidget {
  final Set<String> existingSectionIds;
  final Future<void> Function(String sectionId) onAdd;

  const BibleScreenLibrarySheet({
    super.key,
    required this.existingSectionIds,
    required this.onAdd,
  });

  static Future<String?> show(
    BuildContext context, {
    required Set<String> existingSectionIds,
    required Future<void> Function(String sectionId) onAdd,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: BibleScreenLibrarySheet(
          existingSectionIds: existingSectionIds,
          onAdd: onAdd,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Biblioteca de pantallas',
                        style: AppTypography.titleLarge(palette),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Añade sólo las pantallas que necesita este proyecto.',
                        style: AppTypography.bodyMedium(
                          palette,
                        ).copyWith(color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final groupId in BibleLayoutGroup.orderedGroups)
                  if (_sectionsFor(groupId).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.md,
                        bottom: AppSpacing.sm,
                      ),
                      child: Text(
                        BibleLayoutGroup.label(groupId).toUpperCase(),
                        style: AppTypography.mono(palette).copyWith(
                          color: palette.textSecondary,
                          fontSize: 11,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 900
                            ? 3
                            : constraints.maxWidth >= 560
                            ? 2
                            : 1;
                        final width = columns == 1
                            ? constraints.maxWidth
                            : (constraints.maxWidth -
                                      ((columns - 1) * AppSpacing.sm)) /
                                  columns;
                        return Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final sectionId in _sectionsFor(groupId))
                              SizedBox(
                                width: width,
                                child: _ScreenCard(
                                  sectionId: sectionId,
                                  alreadyAdded: existingSectionIds.contains(
                                    sectionId,
                                  ),
                                  onAdd: () async {
                                    await onAdd(sectionId);
                                    if (context.mounted) {
                                      Navigator.pop(context, sectionId);
                                    }
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _sectionsFor(String groupId) =>
      (BibleLayoutGroup.sectionsByGroup[groupId] ?? const [])
          .where((id) => id != BibleSectionId.settings)
          .toList();
}

class _ScreenCard extends StatelessWidget {
  final String sectionId;
  final bool alreadyAdded;
  final Future<void> Function() onAdd;

  const _ScreenCard({
    required this.sectionId,
    required this.alreadyAdded,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              BibleSectionId.icon(sectionId),
              color: palette.accent,
              size: 21,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  BibleSectionId.label(sectionId),
                  style: AppTypography.label(palette),
                ),
                const SizedBox(height: 2),
                Text(
                  _description(sectionId),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(
                    palette,
                  ).copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          alreadyAdded
              ? Icon(Icons.check_circle, color: palette.success, size: 20)
              : IconButton(
                  tooltip: 'Añadir',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline),
                ),
        ],
      ),
    );
  }

  String _description(String id) => switch (id) {
    BibleSectionId.direction => 'Intención narrativa y enfoque visual.',
    BibleSectionId.concept => 'Concepto, tono y referencias principales.',
    BibleSectionId.camera => 'Cámara, sensor y configuración de captura.',
    BibleSectionId.optics => 'Ópticas, focales, carácter y filtración.',
    BibleSectionId.exposure => 'Exposición, ISO, T-stop y contraste.',
    BibleSectionId.lighting => 'Filosofía, setups y diagramas de luz.',
    BibleSectionId.colorImage => 'Paletas, temperatura y estrategia de color.',
    BibleSectionId.format => 'Formato, resolución y aspect ratio.',
    BibleSectionId.texture => 'Grano, difusión y textura de imagen.',
    BibleSectionId.location => 'Localizaciones, sets y scouting.',
    BibleSectionId.cameraTests => 'Pruebas de cámara, ópticas y LUT.',
    BibleSectionId.workflow => 'Pipeline técnico y entregables.',
    BibleSectionId.moodboard => 'Referencias visuales organizadas.',
    _ => 'Pantalla modular de la Biblia.',
  };
}
