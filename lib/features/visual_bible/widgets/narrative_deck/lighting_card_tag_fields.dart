import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../moodboard_reference_meta.dart';
import '../../services/moodboard_lighting_link_service.dart';
import '../../visual_bible_model.dart';

/// Selectores multi-tag para un contenedor de comportamiento de luz.
class LightingCardTagFields extends StatelessWidget {
  final NarrativeCardModel card;
  final ValueChanged<NarrativeCardModel> onChanged;
  final AppPalette palette;

  const LightingCardTagFields({
    super.key,
    required this.card,
    required this.onChanged,
    required this.palette,
  });

  void _apply(LightingBehaviorTagFilter filter) {
    final meta = Map<String, dynamic>.from(card.meta);
    if (filter.hasAny) {
      meta['tagFilters'] = filter.toMetaMap();
    } else {
      meta.remove('tagFilters');
    }
    meta.remove('lightingLook');
    meta.remove('lightSource');
    meta.remove('lightTexture');
    meta.remove('colorMood');
    if (filter.lightingLooks.isNotEmpty) {
      meta['lightingLook'] = filter.lightingLooks.first;
    }
    if (filter.lightSources.isNotEmpty) {
      meta['lightSource'] = filter.lightSources.first;
    }
    if (filter.lightTextures.isNotEmpty) {
      meta['lightTexture'] = filter.lightTextures.first;
    }
    if (filter.colorMoods.isNotEmpty) {
      meta['colorMood'] = filter.colorMoods.first;
    }
    onChanged(card.copyWith(meta: meta));
  }

  @override
  Widget build(BuildContext context) {
    final filter = LightingBehaviorTagFilter.fromCard(card);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'TAGS DEL CONTENEDOR',
          style: AppTypography.mono(palette).copyWith(
            fontSize: 11,
            letterSpacing: 1.1,
            color: palette.textTertiary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Los stills del moodboard con estos tags aparecerán en este contenedor.',
          style: AppTypography.bodyMedium(palette).copyWith(
            fontSize: 12,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        _MultiTagFamily(
          label: 'Calidad de luz',
          options: kMoodboardLightingLooks,
          selected: filter.lightingLooks.toSet(),
          palette: palette,
          onChanged: (next) => _apply(
            LightingBehaviorTagFilter(
              lightingLooks: next.toList()..sort(),
              lightSources: filter.lightSources,
              lightTextures: filter.lightTextures,
              colorMoods: filter.colorMoods,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MultiTagFamily(
          label: 'Fuente de luz',
          options: kMoodboardLightSources,
          selected: filter.lightSources.toSet(),
          palette: palette,
          onChanged: (next) => _apply(
            LightingBehaviorTagFilter(
              lightingLooks: filter.lightingLooks,
              lightSources: next.toList()..sort(),
              lightTextures: filter.lightTextures,
              colorMoods: filter.colorMoods,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MultiTagFamily(
          label: 'Textura de luz',
          options: kMoodboardLightTextures,
          selected: filter.lightTextures.toSet(),
          palette: palette,
          onChanged: (next) => _apply(
            LightingBehaviorTagFilter(
              lightingLooks: filter.lightingLooks,
              lightSources: filter.lightSources,
              lightTextures: next.toList()..sort(),
              colorMoods: filter.colorMoods,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MultiTagFamily(
          label: 'Look color',
          options: kMoodboardColorMoods,
          selected: filter.colorMoods.toSet(),
          palette: palette,
          onChanged: (next) => _apply(
            LightingBehaviorTagFilter(
              lightingLooks: filter.lightingLooks,
              lightSources: filter.lightSources,
              lightTextures: filter.lightTextures,
              colorMoods: next.toList()..sort(),
            ),
          ),
        ),
      ],
    );
  }
}

class _MultiTagFamily extends StatelessWidget {
  final String label;
  final List<String> options;
  final Set<String> selected;
  final AppPalette palette;
  final ValueChanged<Set<String>> onChanged;

  const _MultiTagFamily({
    required this.label,
    required this.options,
    required this.selected,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium(palette).copyWith(
            fontSize: 12,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final opt in options)
              FilterChip(
                label: Text(opt, style: const TextStyle(fontSize: 12)),
                selected: selected.contains(opt),
                onSelected: (_) {
                  final next = {...selected};
                  if (next.contains(opt)) {
                    next.remove(opt);
                  } else {
                    next.add(opt);
                  }
                  onChanged(next);
                },
                selectedColor: palette.accent.withValues(alpha: 0.25),
                checkmarkColor: palette.accent,
                side: BorderSide(
                  color: selected.contains(opt)
                      ? palette.accent
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
