import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart' hide BibleSectionGroup;
import '../../../core/database/app_database.dart'
    as app_db
    show BibleSectionGroup;
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'bible_navigation_scope.dart';
import '../../../core/widgets/safe_reorderable_column.dart';

/// Orden de las pantallas visibles, para el panel lateral.
///
/// El resto (renombrar, ocultar, añadir, plantillas) vive en la
/// configuración de la biblia.
class BibleStructureEditor extends ConsumerWidget {
  final int bibleId;

  const BibleStructureEditor({super.key, required this.bibleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<app_db.BibleSectionGroup>>(
      stream: db.watchBibleSectionGroups(bibleId),
      builder: (context, groupSnap) {
        final groups = groupSnap.data ?? const [];
        return StreamBuilder<List<BibleSectionDefinition>>(
          stream: db.watchBibleSectionDefinitions(bibleId),
          builder: (context, defSnap) {
            final defs = defSnap.data ?? const <BibleSectionDefinition>[];
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
                  _ReorderList(
                    defs:
                        defs
                            .where((d) => d.groupId == group.id && !d.isHidden)
                            .toList()
                          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
                    onReorder: (ids) =>
                        db.reorderBibleSectionsInGroup(bibleId, group.id, ids),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _ReorderList extends StatelessWidget {
  final List<BibleSectionDefinition> defs;
  final ValueChanged<List<String>> onReorder;

  const _ReorderList({required this.defs, required this.onReorder});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeReorderableColumn(
      scrollable: false,
      itemCount: defs.length,
      keyOf: (index) => ValueKey(defs[index].id),
      dragLabel: (index) => defs[index].label,
      onReorder: (oldIndex, newIndex) {
        final next = List<BibleSectionDefinition>.from(defs);
        next.insert(newIndex, next.removeAt(oldIndex));
        onReorder(next.map((d) => d.id).toList());
      },
      itemBuilder: (context, index) {
        final def = defs[index];
        return Material(
          color: palette.surfaceOverlay,
          borderRadius: BorderRadius.circular(8),
          child: ListTile(
            dense: true,
            leading: Icon(
              bibleIconFromKey(def.iconKey),
              size: 16,
              color: palette.accent,
            ),
            title: Text(
              def.label,
              style: AppTypography.bodyMedium(palette).copyWith(fontSize: 13),
            ),
          ),
        );
      },
    );
  }
}
