import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/scene_character_chips.dart';
import '../../core/widgets/scene_meta_display.dart';
import 'normalized_scene.dart';

/// Entrada del índice lateral de escenas del guion.
class ScriptSceneIndexEntry {
  final int sceneIndex;
  final int? sourceStartIndex;
  final NormalizedScene scene;
  final Color accentColor;

  const ScriptSceneIndexEntry({
    required this.sceneIndex,
    required this.sourceStartIndex,
    required this.scene,
    required this.accentColor,
  });
}

/// Panel índice: escenas, escena activa, personajes y localización.
class ScriptSceneIndexPanel extends StatelessWidget {
  final List<ScriptSceneIndexEntry> entries;
  final int? activeSceneIndex;
  final ValueChanged<ScriptSceneIndexEntry>? onSceneTap;
  final VoidCallback? onEditActiveScene;
  final bool compact;

  const ScriptSceneIndexPanel({
    super.key,
    required this.entries,
    this.activeSceneIndex,
    this.onSceneTap,
    this.onEditActiveScene,
    this.compact = false,
  });

  ScriptSceneIndexEntry? get _activeEntry {
    if (activeSceneIndex == null) return null;
    for (final entry in entries) {
      if (entry.sceneIndex == activeSceneIndex) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = _activeEntry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (active != null) ...[
          _ActiveSceneBanner(
            palette: palette,
            entry: active,
            compact: compact,
            onEdit: onEditActiveScene,
          ),
          Divider(height: 1, color: palette.divider),
        ] else if (entries.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Desplázate por el guion para ver la escena activa.',
              style: AppTypography.caption(palette),
            ),
          ),
          Divider(height: 1, color: palette.divider),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(Icons.list_alt, size: 16, color: palette.accent),
              const SizedBox(width: 8),
              Text(
                'Índice de escenas (${entries.length})',
                style: AppTypography.label(palette),
              ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Aún no hay escenas. Pulsa sluglines en el guion '
                      'escaneado o usa «Detectar escenas».',
                      style: AppTypography.bodyMedium(palette),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final entry = entries[i];
                    final isActive = entry.sceneIndex == activeSceneIndex;
                    return _SceneIndexTile(
                      palette: palette,
                      entry: entry,
                      isActive: isActive,
                      compact: compact,
                      onTap: onSceneTap == null
                          ? null
                          : () => onSceneTap!(entry),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ActiveSceneBanner extends StatelessWidget {
  final AppPalette palette;
  final ScriptSceneIndexEntry entry;
  final bool compact;
  final VoidCallback? onEdit;

  const _ActiveSceneBanner({
    required this.palette,
    required this.entry,
    required this.compact,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scene = entry.scene;

    return Material(
      color: entry.accentColor.withValues(alpha: 0.12),
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    color: entry.accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Escena ${scene.number}${scene.name != null && scene.name!.trim().isNotEmpty ? ' · ${scene.name}' : ''}',
                    style: AppTypography.titleMedium(palette),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    tooltip: 'Editar escena',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.edit_outlined,
                        color: palette.accent, size: 18),
                    onPressed: onEdit,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SceneMetaDisplay(
              intExt: scene.intExt,
              dayNight: scene.dayNight,
              location: scene.location,
              style: AppTypography.bodyMedium(palette),
            ),
            if (scene.locationSite.trim().isNotEmpty ||
                scene.shootSet.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.place_outlined,
                      size: 14, color: palette.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      scene.locationSite == scene.shootSet
                          ? scene.locationSite
                          : '${scene.locationSite} › ${scene.shootSet}',
                      style: AppTypography.caption(palette)
                          .copyWith(color: palette.accent),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (scene.characters.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Personajes', style: AppTypography.caption(palette)),
              const SizedBox(height: 4),
              SceneCharacterChips(
                characters: scene.characters,
                palette: palette,
                compact: true,
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                'Sin personajes asignados',
                style: AppTypography.caption(palette),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SceneIndexTile extends StatelessWidget {
  final AppPalette palette;
  final ScriptSceneIndexEntry entry;
  final bool isActive;
  final bool compact;
  final VoidCallback? onTap;

  const _SceneIndexTile({
    required this.palette,
    required this.entry,
    required this.isActive,
    required this.compact,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scene = entry.scene;
    final bg = isActive
        ? entry.accentColor.withValues(alpha: 0.14)
        : Colors.transparent;

    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: compact ? 6 : 8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 36,
                margin: const EdgeInsets.only(right: 10, top: 2),
                decoration: BoxDecoration(
                  color: isActive ? entry.accentColor : palette.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                '${scene.number}.',
                style: AppTypography.mono(palette).copyWith(
                  color: isActive ? palette.accent : palette.textSecondary,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SceneMetaDisplay(
                      intExt: scene.intExt,
                      dayNight: scene.dayNight,
                      location: scene.location,
                      style: AppTypography.bodyMedium(palette).copyWith(
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (scene.characters.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      SceneCharacterChips(
                        characters: scene.characters,
                        palette: palette,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: palette.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
