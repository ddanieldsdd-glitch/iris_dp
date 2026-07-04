import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Badge circular con número de escena y color representativo (estilo guion técnico).
class SceneNumberBadge extends StatelessWidget {
  final int sceneNumber;
  final Color color;
  final double size;

  const SceneNumberBadge({
    super.key,
    required this.sceneNumber,
    required this.color,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$sceneNumber',
        style: TextStyle(
          color: _contrastText(color),
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static Color _contrastText(Color bg) {
    return bg.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
  }
}

class SceneHeaderRow extends StatelessWidget {
  final int sceneNumber;
  final Color sceneColor;
  final String title;
  final String? subtitle;
  final AppPalette palette;

  const SceneHeaderRow({
    super.key,
    required this.sceneNumber,
    required this.sceneColor,
    required this.title,
    required this.palette,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SceneNumberBadge(sceneNumber: sceneNumber, color: sceneColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.titleMedium(palette)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppTypography.caption(palette)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class CameraPlanNavTarget {
  final int shotId;
  final int sceneId;
  final int sceneNumber;
  final int shotNumber;
  final String sceneName;
  final Color sceneColor;
  final String siteName;

  const CameraPlanNavTarget({
    required this.shotId,
    required this.sceneId,
    required this.sceneNumber,
    required this.shotNumber,
    required this.sceneName,
    required this.sceneColor,
    required this.siteName,
  });

  String get label => 'Esc $sceneNumber · Plano $shotNumber';
}
