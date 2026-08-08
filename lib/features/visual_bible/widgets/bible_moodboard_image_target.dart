import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../moodboard_helpers.dart';
import 'bible_paste_zone.dart';

/// Zona hero/referencia con ⌘V y drag desde moodboard hacia una sección.
class BibleMoodboardImageTarget extends ConsumerWidget {
  final int projectId;
  final String sectionId;
  final int? bibleId;
  final Widget child;
  final String? hint;

  const BibleMoodboardImageTarget({
    super.key,
    required this.projectId,
    required this.sectionId,
    this.bibleId,
    required this.child,
    this.hint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.read(databaseProvider);
    final pasteHint = hint ?? 'Clic aquí → ⌘V para pegar imagen';

    return BibleTargetZone(
      hint: pasteHint,
      minHeight: 0,
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
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          Positioned(
            right: 8,
            top: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⌘V',
                  style: AppTypography.mono(palette).copyWith(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
