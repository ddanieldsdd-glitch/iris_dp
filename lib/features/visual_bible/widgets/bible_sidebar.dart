import 'package:flutter/material.dart';

import '../visual_bible_completion.dart';
import '../../../core/database/app_database.dart' hide BibleSectionGroup show BibleSectionDefinition;
import '../../../core/database/app_database.dart' as app_db show BibleSectionGroup;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../visual_bible_completion.dart';
import '../visual_bible_model.dart';
import 'bible_navigation_scope.dart';

/// Navegación lateral de la Biblia de Fotografía.
class BibleSidebar extends StatelessWidget {
  final String activeSection;
  final VisualBibleData? data;
  final ValueChanged<String> onSectionSelected;
  final List<app_db.BibleSectionGroup>? groups;
  final List<BibleSectionDefinition>? definitions;
  final VoidCallback? onEditStructure;

  const BibleSidebar({
    super.key,
    required this.activeSection,
    required this.data,
    required this.onSectionSelected,
    this.groups,
    this.definitions,
    this.onEditStructure,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final useDynamic = groups != null &&
        definitions != null &&
        groups!.isNotEmpty &&
        definitions!.isNotEmpty;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(right: BorderSide(color: palette.divider)),
      ),
      child: Column(
        children: [
          if (onEditStructure != null)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.tune, size: 18),
                tooltip: 'Editar estructura',
                onPressed: onEditStructure,
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: useDynamic
                  ? _dynamicItems(palette)
                  : _fallbackItems(palette),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _dynamicItems(AppPalette palette) {
    final items = <Widget>[];
    for (final group in groups!) {
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            group.label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              color: palette.textTertiary,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      final sectionDefs = definitions!
          .where((d) => d.groupId == group.id && !d.isHidden)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      for (final def in sectionDefs) {
        items.add(
          _SidebarItem(
            id: def.id,
            label: def.label,
            icon: bibleIconFromKey(def.iconKey),
            active: def.id == activeSection,
            completion: data == null
                ? 0
                : bibleSectionCompletion(data!, def.id),
            onTap: () => onSectionSelected(def.id),
          ),
        );
      }
    }
    return items;
  }

  List<Widget> _fallbackItems(AppPalette palette) {
    final items = <Widget>[];
    for (final group in BibleLayoutGroup.orderedGroups) {
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            BibleLayoutGroup.label(group).toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              color: palette.textTertiary,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      for (final id in BibleLayoutGroup.sectionsByGroup[group]!) {
        items.add(
          _SidebarItem(
            id: id,
            label: BibleSectionId.label(id),
            icon: BibleSectionId.icon(id),
            active: id == activeSection,
            completion: data == null ? 0 : bibleSectionCompletion(data!, id),
            onTap: () => onSectionSelected(id),
          ),
        );
      }
    }
    return items;
  }
}

class _SidebarItem extends StatelessWidget {
  final String id;
  final String label;
  final IconData icon;
  final bool active;
  final double completion;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.active,
    required this.completion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pct = (completion * 100).round();
    final complete = completion >= 1.0;

    return Material(
      color: active
          ? palette.accent.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? palette.accent : palette.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    color: active ? palette.accent : palette.textPrimary,
                  ),
                ),
              ),
              if (complete)
                Icon(Icons.check_circle, size: 14, color: palette.success)
              else if (pct > 0)
                Text(
                  '$pct%',
                  style: TextStyle(fontSize: 11, color: palette.textTertiary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
