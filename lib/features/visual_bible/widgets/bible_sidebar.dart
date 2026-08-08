import 'dart:io';

import 'package:flutter/material.dart';

import '../visual_bible_completion.dart';
import 'bible_navigation_scope.dart';
import 'bible_overview_section.dart';
import '../../../core/database/app_database.dart' hide BibleSectionGroup;
import '../../../core/database/app_database.dart'
    as app_db
    show BibleSectionGroup;
import '../../../core/theme/app_colors.dart';
import '../visual_bible_model.dart';

/// Navegación lateral de la Biblia de Fotografía.
class BibleSidebar extends StatelessWidget {
  static const overviewSectionId = '__overview__';

  final String activeSection;
  final VisualBibleData? data;
  final Project? project;
  final ValueChanged<String> onSectionSelected;
  final List<app_db.BibleSectionGroup>? groups;
  final List<BibleSectionDefinition>? definitions;
  final VoidCallback? onEditStructure;
  final VoidCallback? onAddSection;
  final VoidCallback? onOpenSettings;
  final Future<void> Function(BibleSectionDefinition def)? onRemoveSection;
  final BibleContentSnapshot contentSnapshot;
  final double width;

  const BibleSidebar({
    super.key,
    required this.activeSection,
    required this.data,
    this.project,
    required this.onSectionSelected,
    this.groups,
    this.definitions,
    this.onEditStructure,
    this.onAddSection,
    this.onOpenSettings,
    this.onRemoveSection,
    this.contentSnapshot = const BibleContentSnapshot(),
    this.width = 280,
  });

  Color _groupAccentColor(AppPalette palette, String groupLabel) {
    final l = groupLabel.toLowerCase();
    if (l.contains('técnica') ||
        l.contains('imagen') ||
        l.contains('technical')) {
      return palette.accent.withValues(alpha: 0.6);
    } else if (l.contains('espacial') ||
        l.contains('prueba') ||
        l.contains('location')) {
      return palette.success.withValues(alpha: 0.6);
    } else if (l.contains('operativa') ||
        l.contains('referencia') ||
        l.contains('workflow')) {
      return palette.warning.withValues(alpha: 0.6);
    }
    return palette.textTertiary;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final useDynamic =
        groups != null &&
        definitions != null &&
        groups!.isNotEmpty &&
        definitions!.isNotEmpty;
    final projectName = project?.name.trim().isNotEmpty == true
        ? project!.name.trim()
        : 'Proyecto';
    final cover = project?.coverImagePath;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E10),
        border: Border(right: BorderSide(color: palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
            child: Row(
              children: [
                _ProjectAvatar(coverPath: cover, palette: palette),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projectName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.2,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Biblia visual',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onEditStructure != null)
                  InkWell(
                    onTap: onEditStructure,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Tooltip(
                        message: 'Estructura y plantillas',
                        child: Icon(
                          Icons.account_tree_outlined,
                          size: 16,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.border),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: useDynamic
                  ? _dynamicItems(palette)
                  : _fallbackItems(palette),
            ),
          ),
          if (onAddSection != null || onOpenSettings != null) ...[
            Divider(height: 1, color: palette.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (onAddSection != null)
                    TextButton.icon(
                      onPressed: onAddSection,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Añadir pantalla'),
                      ),
                    ),
                  if (onOpenSettings != null) ...[
                    const SizedBox(height: 4),
                    Material(
                      color: palette.surfaceOverlay,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: onOpenSettings,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.tune, size: 18, color: palette.accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ajustes de pantalla',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Widgets, refs y estilo en vivo',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: palette.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: palette.textTertiary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _dynamicItems(AppPalette palette) {
    final items = <Widget>[_overviewItem(palette)];
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
      final sectionDefs =
          definitions!
              .where(
                (d) =>
                    d.groupId == group.id &&
                    (!d.isHidden || d.id == BibleSectionId.settings),
              )
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
                : contentSnapshot.sectionCompletion(data!, def.id),
            onTap: () => onSectionSelected(def.id),
            onRemove:
                onRemoveSection == null || def.id == BibleSectionId.settings
                ? null
                : () => onRemoveSection!(def),
            isBuiltIn: def.isBuiltIn,
          ),
        );
      }
    }
    return items;
  }

  List<Widget> _fallbackItems(AppPalette palette) {
    final items = <Widget>[_overviewItem(palette)];
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
            completion: data == null
                ? 0
                : contentSnapshot.sectionCompletion(data!, id),
            onTap: () => onSectionSelected(id),
          ),
        );
      }
    }
    return items;
  }

  Widget _overviewItem(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _SidebarItem(
        id: overviewSectionId,
        label: 'Resumen',
        icon: Icons.dashboard_outlined,
        active: activeSection == overviewSectionId,
        completion: 0,
        onTap: () => onSectionSelected(overviewSectionId),
      ),
    );
  }
}

class _ProjectAvatar extends StatelessWidget {
  final String? coverPath;
  final AppPalette palette;

  const _ProjectAvatar({required this.coverPath, required this.palette});

  @override
  Widget build(BuildContext context) {
    final path = coverPath;
    final hasCover = path != null && path.isNotEmpty && File(path).existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 44,
        height: 44,
        child: hasCover
            ? Image.file(File(path), fit: BoxFit.cover)
            : ColoredBox(
                color: palette.surfaceOverlay,
                child: Icon(
                  Icons.movie_creation_outlined,
                  color: palette.accent,
                  size: 22,
                ),
              ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String id;
  final String label;
  final IconData icon;
  final bool active;
  final double completion;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final bool isBuiltIn;

  const _SidebarItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.active,
    required this.completion,
    required this.onTap,
    this.onRemove,
    this.isBuiltIn = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: active
          ? palette.accent.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onSecondaryTapDown: onRemove == null
            ? null
            : (details) => _showMenu(context, details.globalPosition),
        onLongPress: onRemove == null
            ? null
            : () {
                final box = context.findRenderObject() as RenderBox?;
                final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
                _showMenu(context, pos);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? palette.textPrimary : palette.textSecondary,
                  ),
                ),
              ),
              if (completion > 0)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completion >= 0.85
                        ? palette.success
                        : palette.accent.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, Offset globalPosition) async {
    final palette = context.palette;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      color: palette.surfaceElevated,
      items: [
        PopupMenuItem(
          value: 'remove',
          child: Text(
            isBuiltIn ? 'Quitar de la biblia' : 'Eliminar pantalla',
            style: TextStyle(color: palette.error),
          ),
        ),
      ],
    );
    if (action == 'remove') onRemove?.call();
  }
}
