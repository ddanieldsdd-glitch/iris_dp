import '../../../../shared/visual_bible/lighting_card_page.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../visual_bible_model.dart';

/// Tile de carta en el deck (cover + título).
class NarrativeCardTile extends ConsumerWidget {
  final NarrativeCardModel card;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const NarrativeCardTile({
    super.key,
    required this.card,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final page = LightingCardPage.of(
      kind: card.kind,
      body: card.body,
      meta: card.meta,
    );
    final metrics = page.metrics;
    final ratio = metrics.ratioOption;
    final mono = AppTypography.mono(
      palette,
    ).copyWith(fontSize: 11, color: palette.textSecondary);
    final summary = (card.body ?? '').trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xB31A1A1C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  child: _Cover(
                    db: db,
                    // Sin portada, la primera imagen de su mosaico.
                    coverId: card.coverMoodboardImageId ?? page.firstImageId,
                    palette: palette,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            card.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium(palette).copyWith(
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                          if (summary.isNotEmpty)
                            Text(
                              summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption(palette),
                            ),
                          // El dato de luz de la ficha, a la vista.
                          if (metrics.usesColors ||
                              metrics.kelvin != null ||
                              ratio != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  if (metrics.usesColors)
                                    for (final c in metrics.colors.take(5))
                                      Container(
                                        width: 10,
                                        height: 10,
                                        margin: const EdgeInsets.only(right: 3),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF000000 | c.rgb),
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                  else if (metrics.kelvin != null) ...[
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Color(
                                          0xFF000000 | metrics.color!,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text('${metrics.kelvin} K', style: mono),
                                  ],
                                  if (ratio != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      ratio.label,
                                      style: mono.copyWith(
                                        color: palette.accent,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (onDelete != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: palette.textTertiary,
                        ),
                        onPressed: onDelete,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final AppDatabase db;
  final int? coverId;
  final AppPalette palette;

  const _Cover({
    required this.db,
    required this.coverId,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    if (coverId == null) {
      return ColoredBox(
        color: Colors.white.withValues(alpha: 0.04),
        child: Center(
          child: Icon(
            Icons.image_outlined,
            color: palette.textTertiary,
            size: 36,
          ),
        ),
      );
    }
    return FutureBuilder<MoodboardImage?>(
      future: (db.select(db.moodboardImages)
            ..where((m) => m.id.equals(coverId!)))
          .getSingleOrNull(),
      builder: (context, snap) {
        final path = snap.data?.imagePath;
        if (path != null && File(path).existsSync()) {
          return Image.file(File(path), fit: BoxFit.cover);
        }
        return ColoredBox(
          color: Colors.white.withValues(alpha: 0.04),
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: palette.textTertiary,
            ),
          ),
        );
      },
    );
  }
}
