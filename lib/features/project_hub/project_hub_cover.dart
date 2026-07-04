import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Cabecera del hub con mosaico y tiras de moodboard + storyboard.
class ProjectHubCover extends StatelessWidget {
  final Project project;
  final List<String> moodboardPaths;
  final List<String> storyboardPaths;
  final VoidCallback? onMoodboardTap;
  final VoidCallback? onStoryboardTap;

  const ProjectHubCover({
    super.key,
    required this.project,
    required this.moodboardPaths,
    required this.storyboardPaths,
    this.onMoodboardTap,
    this.onStoryboardTap,
  });

  List<String> get _mosaicPaths {
    final combined = <String>[
      ...storyboardPaths.take(4),
      ...moodboardPaths.take(4),
    ];
    return combined.toSet().take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final coverPath = project.coverImagePath;
    final hasCover =
        coverPath != null && coverPath.isNotEmpty && File(coverPath).existsSync();
    final mosaic = _mosaicPaths;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasCover)
          Image.file(File(coverPath), fit: BoxFit.cover)
        else if (mosaic.isNotEmpty)
          _MosaicBackground(paths: mosaic)
        else
          ColoredBox(color: palette.surfaceElevated),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                palette.surface.withValues(alpha: 0.35),
                palette.surface.withValues(alpha: 0.72),
                palette.surface.withValues(alpha: 0.95),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        if (!hasCover && mosaic.isEmpty)
          Center(
            child: Icon(
              Icons.movie_creation_outlined,
              color: palette.textTertiary.withValues(alpha: 0.45),
              size: 56,
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 52,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _VisualStrip(
                label: 'Moodboard',
                paths: moodboardPaths,
                accent: const Color(0xFFFF6B6B),
                emptyHint: 'Localizaciones',
                onTap: onMoodboardTap,
              ),
              const SizedBox(height: 6),
              _VisualStrip(
                label: 'Storyboard',
                paths: storyboardPaths,
                accent: const Color(0xFF5AC8FA),
                emptyHint: 'Planos',
                onTap: onStoryboardTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MosaicBackground extends StatelessWidget {
  final List<String> paths;

  const _MosaicBackground({required this.paths});

  @override
  Widget build(BuildContext context) {
    if (paths.length == 1) {
      return Image.file(File(paths.first), fit: BoxFit.cover);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / 3;
        final cellH = constraints.maxHeight / 2;
        return Wrap(
          children: [
            for (var i = 0; i < paths.length && i < 6; i++)
              SizedBox(
                width: cellW,
                height: cellH,
                child: Image.file(
                  File(paths[i]),
                  fit: BoxFit.cover,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VisualStrip extends StatelessWidget {
  final String label;
  final List<String> paths;
  final Color accent;
  final String emptyHint;
  final VoidCallback? onTap;

  const _VisualStrip({
    required this.label,
    required this.paths,
    required this.accent,
    required this.emptyHint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: AppTypography.caption(palette).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: paths.isEmpty
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Sin imágenes · $emptyHint',
                            style: AppTypography.caption(palette).copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: paths.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(paths[index]),
                                width: 64,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            );
                          },
                        ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: palette.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
