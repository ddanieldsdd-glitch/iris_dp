import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'shoot_document_block_resolver.dart';
import 'shoot_document_block_tile.dart';

/// Vista de lectura optimizada para rodaje en set.
class ShootDocumentOnSetView extends StatelessWidget {
  final ShootDocument document;
  final List<ResolvedShootBlock> blocks;
  final AppPalette palette;

  const ShootDocumentOnSetView({
    super.key,
    required this.document,
    required this.blocks,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          document.name,
          style: AppTypography.displayMedium(palette).copyWith(fontSize: 28),
        ),
        if (document.shootDate != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Jornada: ${document.shootDate}',
            style: AppTypography.bodyMedium(palette),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        for (final resolved in blocks)
          ShootDocumentBlockTile(
            resolved: resolved,
            palette: palette,
            editing: false,
          ),
      ],
    );
  }
}
