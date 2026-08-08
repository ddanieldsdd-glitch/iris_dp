import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../moodboard_helpers.dart';
import '../visual_bible_model.dart';
import 'bible_paste_zone.dart';
import 'bible_section_references_manager.dart';

/// Referencias visuales editables por sección (fuente única moodboard).
class BibleReferencesPanel extends ConsumerWidget {
  final int projectId;
  final String sectionId;
  final int? bibleId;
  final VoidCallback? onOpenMoodboard;
  final String? title;
  final bool compact;

  const BibleReferencesPanel({
    super.key,
    required this.projectId,
    required this.sectionId,
    this.bibleId,
    this.onOpenMoodboard,
    this.title,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final sectionLabel = BibleSectionId.label(sectionId);
    final db = ref.read(databaseProvider);
    final resolvedBibleId = bibleId ?? 0;

    if (compact) {
      return BibleSectionReferencesManager(
        projectId: projectId,
        bibleId: resolvedBibleId,
        sectionId: sectionId,
        compact: true,
        title: title,
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onOpenMoodboard != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpenMoodboard,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Ir al moodboard'),
              ),
            ),
          Text(
            'Clic en la zona de abajo y ⌘V para pegar directamente en $sectionLabel.',
            style: AppTypography.caption(palette),
          ),
          const SizedBox(height: AppSpacing.md),
          BibleTargetZone(
            hint: 'Clic aquí → ⌘V para pegar en $sectionLabel',
            minHeight: 72,
            onPaste: (payload) => MoodboardHelpers.addImageFromBytesAssigned(
              db: db,
              projectId: projectId,
              bibleId: bibleId,
              bytes: payload.bytes,
              extension: payload.extension,
              assignedSections: [sectionId],
            ),
            onMoodboardDropped: (drag) => MoodboardHelpers.linkMoodboardToSection(
              db: db,
              projectId: projectId,
              payload: drag,
              sectionId: sectionId,
            ),
            child: BibleSectionReferencesManager(
              projectId: projectId,
              bibleId: resolvedBibleId,
              sectionId: sectionId,
              title: title ?? 'Referencias visuales',
            ),
          ),
        ],
      ),
    );
  }
}

/// @deprecated Usar [BibleReferencesPanel].
typedef BibleUnifiedReferencesPanel = BibleReferencesPanel;
