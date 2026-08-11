import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../services/moodboard_lighting_link_service.dart';
import '../../../visual_bible_model.dart';
import '../lighting_card_tag_fields.dart';

/// Chips de tags de luz encima del título del contenedor.
class ContainerHeaderTags extends StatelessWidget {
  final NarrativeCardModel card;
  final AppPalette palette;
  final ValueChanged<NarrativeCardModel> onChanged;

  const ContainerHeaderTags({
    super.key,
    required this.card,
    required this.palette,
    required this.onChanged,
  });

  Future<void> _openTagSheet(BuildContext context) async {
    var draft = card;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tags del contenedor',
                            style: AppTypography.bodyMedium(palette).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            onChanged(draft);
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            'Aplicar',
                            style: TextStyle(color: palette.accent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LightingCardTagFields(
                      card: draft,
                      palette: palette,
                      onChanged: (updated) {
                        setSheetState(() => draft = updated);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<String> _allTags() {
    final filter = LightingBehaviorTagFilter.fromCard(card);
    return [
      ...filter.lightingLooks,
      ...filter.lightSources,
      ...filter.lightTextures,
      ...filter.colorMoods,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tags = _allTags();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in tags)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: palette.accent.withValues(alpha: 0.5),
                  ),
                  color: palette.accent.withValues(alpha: 0.12),
                ),
                child: Text(
                  tag.toUpperCase(),
                  style: AppTypography.mono(palette).copyWith(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: palette.accent,
                  ),
                ),
              ),
            ActionChip(
              label: Text(
                tags.isEmpty ? 'Añadir tags' : '+ Tag',
                style: TextStyle(
                  fontSize: 11,
                  color: palette.textSecondary,
                ),
              ),
              avatar: Icon(
                Icons.add,
                size: 16,
                color: palette.textSecondary,
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.04),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              onPressed: () => _openTagSheet(context),
            ),
          ],
        ),
      ],
    );
  }
}
