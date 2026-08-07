import 'package:flutter/material.dart';

import '../visual_bible_completion.dart';
import 'bible_navigation_scope.dart';
import '../../../core/database/app_database.dart' hide BibleSectionGroup show BibleSectionDefinition;
import '../../../core/database/app_database.dart' as app_db show BibleSectionGroup;
import '../../../core/theme/app_colors.dart';
import '../visual_bible_model.dart';

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

  Color _groupAccentColor(AppPalette palette, String groupLabel) {
    final l = groupLabel.toLowerCase();
    if (l.contains('técnica') || l.contains('imagen') || l.contains('technical')) {
      return palette.accent.withValues(alpha: 0.6);
    } else if (l.contains('espacial') || l.contains('prueba') || l.contains('location')) {
      return palette.success.withValues(alpha: 0.6);
    } else if (l.contains('operativa') || l.contains('referencia') || l.contains('workflow')) {
      return palette.warning.withValues(alpha: 0.6);
    }
    return palette.textTertiary;
  }

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
        color: palette.background,
        border: Border(right: BorderSide(color: palette.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'BIBLIA DE FOTOGRAFÍA',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: palette.textTertiary,
                    ),
                  ),
                ),
                if (onEditStructure != null)
                  InkWell(
                    onTap: onEditStructure,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.tune, size: 14, color: palette.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
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
      final color = _groupAccentColor(palette, group.label);
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
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
            ],
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
      final label = BibleLayoutGroup.label(group);
      final color = _groupAccentColor(palette, label);
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.textTertiary,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
    final complete = completion >= 1.0;

    return Material(
      color: active
          ? palette.accent.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            if (active)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: palette.accent,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: active ? palette.accent : palette.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                            color: active ? palette.accent : palette.textPrimary,
                          ),
                        ),
                        if (!complete && completion > 0) ...[
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: completion,
                              minHeight: 4,
                              backgroundColor: palette.textTertiary.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (complete) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle, size: 14, color: palette.success),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
