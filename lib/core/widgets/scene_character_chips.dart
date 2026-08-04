import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Chips compactos de personajes para listas de escenas.
class SceneCharacterChips extends StatelessWidget {
  final List<String> characters;
  final AppPalette palette;
  final bool compact;
  final Map<String, Color>? characterColors;

  const SceneCharacterChips({
    super.key,
    required this.characters,
    required this.palette,
    this.compact = false,
    this.characterColors,
  });

  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final name in characters)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 8,
              vertical: compact ? 2 : 3,
            ),
            decoration: BoxDecoration(
              color: _chipColor(name)?.withValues(alpha: 0.18) ??
                  palette.surfaceOverlay,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _chipColor(name)?.withValues(alpha: 0.55) ??
                    palette.divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_chipColor(name) != null) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _chipColor(name),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  name,
                  style: AppTypography.caption(palette).copyWith(
                    fontSize: compact ? 11 : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color? _chipColor(String name) {
    if (characterColors == null) return null;
    return characterColors![name.trim().toUpperCase()];
  }
}
