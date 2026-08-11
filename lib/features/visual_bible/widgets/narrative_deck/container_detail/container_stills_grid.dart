import 'package:flutter/material.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../moodboard_reference_meta.dart';
import '../../../services/moodboard_lighting_link_service.dart';
import '../../../visual_bible_model.dart';
import 'annotated_still_tile.dart';

/// Grid de stills del contenedor con selector S/M/L de densidad de info.
class ContainerStillsGrid extends StatefulWidget {
  final int projectId;
  final NarrativeCardModel card;
  final AppDatabase db;
  final AppPalette palette;
  final AnnotatedStillSize initialSize;

  const ContainerStillsGrid({
    super.key,
    required this.projectId,
    required this.card,
    required this.db,
    required this.palette,
    this.initialSize = AnnotatedStillSize.medium,
  });

  @override
  State<ContainerStillsGrid> createState() => _ContainerStillsGridState();
}

class _ContainerStillsGridState extends State<ContainerStillsGrid> {
  late AnnotatedStillSize _size;

  @override
  void initState() {
    super.initState();
    _size = widget.initialSize;
  }

  double get _aspect => switch (_size) {
        AnnotatedStillSize.small => 1.6,
        AnnotatedStillSize.medium => 1.35,
        AnnotatedStillSize.large => 1.05,
      };

  int _crossAxis(double width) {
    switch (_size) {
      case AnnotatedStillSize.small:
        return width >= 900 ? 4 : (width >= 520 ? 3 : 2);
      case AnnotatedStillSize.medium:
        return width >= 900 ? 3 : (width >= 520 ? 2 : 1);
      case AnnotatedStillSize.large:
        return width >= 900 ? 2 : 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final card = widget.card;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'STILLS DEL CONTENEDOR',
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: palette.textTertiary,
                ),
              ),
            ),
            SegmentedButton<AnnotatedStillSize>(
              segments: const [
                ButtonSegment(
                  value: AnnotatedStillSize.small,
                  label: Text('S', style: TextStyle(fontSize: 10)),
                ),
                ButtonSegment(
                  value: AnnotatedStillSize.medium,
                  label: Text('M', style: TextStyle(fontSize: 10)),
                ),
                ButtonSegment(
                  value: AnnotatedStillSize.large,
                  label: Text('L', style: TextStyle(fontSize: 10)),
                ),
              ],
              selected: {_size},
              onSelectionChanged: (set) {
                setState(() => _size = set.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return palette.accent;
                  }
                  return palette.textTertiary;
                }),
              ),
              showSelectedIcon: false,
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<MoodboardImage>>(
          stream: widget.db.watchMoodboardImages(widget.projectId),
          builder: (context, snap) {
            return FutureBuilder<Map<int, MoodboardReferenceMeta>>(
              future: MoodboardReferenceMetaStore.loadMany(
                widget.db,
                (snap.data ?? []).map((r) => r.id),
              ),
              builder: (context, metaSnap) {
                final metaById = metaSnap.data ?? {};
                final pool = <MoodboardImageModel>[];
                for (final row in snap.data ?? []) {
                  final meta =
                      metaById[row.id] ?? const MoodboardReferenceMeta();
                  pool.add(
                    MoodboardImageModel.fromRow(row).copyWith(meta: meta),
                  );
                }
                final matched =
                    MoodboardLightingLinkService.imagesMatchingContainer(
                  pool: pool,
                  container: card,
                );
                if (matched.isEmpty) {
                  final filter = LightingBehaviorTagFilter.fromCard(card);
                  return Text(
                    filter.hasAny
                        ? 'Ningún still coincide aún con estos tags.'
                        : 'Define tags del contenedor o asigna stills para verlos aquí.',
                    style: AppTypography.bodyMedium(palette).copyWith(
                      fontSize: 12,
                      color: palette.textTertiary,
                    ),
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final cross = _crossAxis(constraints.maxWidth);
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: matched.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: _aspect,
                      ),
                      itemBuilder: (context, i) {
                        return AnnotatedStillTile(
                          image: matched[i],
                          palette: palette,
                          size: _size,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}
