// /Users/danieldiaz/Documents/IRIS DP/iris_dp/lib/features/visual_bible/widgets/sections/color_image_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_section_shared_widgets.dart';
import '../narrative_bridge_card.dart';

class ColorImageSection extends ConsumerStatefulWidget {
  final VisualBibleData data;
  final int projectId;
  final int bibleId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const ColorImageSection({
    super.key,
    required this.data,
    required this.projectId,
    required this.bibleId,
    this.sectionContentJson,
    required this.onChanged,
  });

  @override
  ConsumerState<ColorImageSection> createState() => _ColorImageSectionState();
}

class _ColorImageSectionState extends ConsumerState<ColorImageSection> {
  BibleVisualMode _mode = BibleVisualMode.cinematic;

  int _hexToInt(String hex) {
    final clean = hex.replaceAll('#', '');
    return int.parse('ff$clean', radix: 16);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        BibleSectionHeader(
          number: '07',
          title: 'Color e Imagen',
          trailing: BibleSectionModeDropdown(
            value: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),
        ),
        NarrativeBridgeCard(
          hint: '¿Qué emoción transmite esta paleta y este LUT? Cómo el color apoya la narrativa…',
          value: widget.data.colorNarrativeIntent,
          onChanged: (v) {
            widget.data.colorNarrativeIntent = v;
            widget.onChanged(widget.data);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        
        StreamBuilder<List<VisualBibleColorBlock>>(
          stream: db.watchColorBlocksForBible(widget.bibleId),
          builder: (context, snap) {
            final blocks = snap.data?.map((row) => ColorBlockModel.fromRow(row)).toList() ?? [];
            if (blocks.isEmpty) return const SizedBox.shrink();
            
            return Column(
              children: blocks.map((block) {
                final swatches = block.dominantColors.take(3).toList();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(block.blockName, style: AppTypography.titleMedium(palette)),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            for (var i = 0; i < swatches.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(right: AppSpacing.sm),
                                child: BibleColorSwatch(
                                  color: Color(_hexToInt(swatches[i])),
                                  name: 'Color ${i + 1}',
                                  hex: swatches[i],
                                  large: true,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        BibleHeroValue(
                          value: block.colorTempKelvin?.toString() ?? '5600',
                          unit: 'K',
                          label: 'TEMPERATURA BASE',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextButton(
                          onPressed: () {},
                          child: Text('Editar paleta', style: TextStyle(color: palette.accent)),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Row(
                          children: [
                            Expanded(child: BibleTechCard(label: 'HIGHLIGHTS', value: '—')),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(child: BibleTechCard(label: 'MIDTONES', value: '—')),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(child: BibleTechCard(label: 'SHADOWS', value: '—')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ACENTOS PRÁCTICOS', style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.md),
              StreamBuilder<List<VisualBibleColorBlock>>(
                stream: db.watchColorBlocksForBible(widget.bibleId),
                builder: (context, snap) {
                  final blocks = snap.data?.map((row) => ColorBlockModel.fromRow(row)).toList() ?? [];
                  if (blocks.isEmpty || blocks.first.accentColors.isEmpty) return const Text('Sin acentos prácticos');
                  final accentHex = blocks.first.accentColors;
                  return Row(
                    children: [
                      for (var i = 0; i < accentHex.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: BibleColorSwatch(
                            color: Color(_hexToInt(accentHex[i])),
                            name: 'Acento ${i + 1}',
                            hex: accentHex[i],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.block, color: palette.error),
                  const SizedBox(width: AppSpacing.sm),
                  Text('COLORES PROHIBIDOS', style: AppTypography.titleMedium(palette).copyWith(color: palette.error)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              StreamBuilder<List<VisualBibleColorBlock>>(
                stream: db.watchColorBlocksForBible(widget.bibleId),
                builder: (context, snap) {
                  final blocks = snap.data?.map((row) => ColorBlockModel.fromRow(row)).toList() ?? [];
                  if (blocks.isEmpty || blocks.first.prohibitedColors.isEmpty) return const Text('Ninguno');
                  final prohibited = blocks.first.prohibitedColors;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: prohibited.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          Icon(Icons.block, size: 14, color: palette.error),
                          const SizedBox(width: AppSpacing.sm),
                          Text(p, style: TextStyle(color: palette.textPrimary)),
                        ],
                      ),
                    )).toList(),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GLOBAL ATTRIBUTES', style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.md),
              _buildSliderRow(context, 'Contrast', widget.data.contrastStyle ?? '—', 0.6),
              _buildSliderRow(context, 'Saturation', '—', 0.5),
              _buildSliderRow(context, 'Grain', widget.data.grainLevel ?? '—', 0.4),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MONITORING LUT', style: AppTypography.label(palette)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(widget.data.workingLutName ?? '—', style: GoogleFonts.jetBrainsMono(color: palette.textPrimary, fontSize: 13)),
                      const SizedBox(height: AppSpacing.sm),
                      const BibleChipRow(chips: ['REC.709', 'DISPLAY']),
                      const SizedBox(height: AppSpacing.md),
                      BibleTextField(
                        label: 'LUT Name',
                        initialValue: widget.data.workingLutName,
                        onChanged: (v) {
                          widget.data.workingLutName = v;
                          widget.onChanged(widget.data);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CREATIVE LUT', style: AppTypography.label(palette)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(widget.data.creativeLutName ?? '—', style: GoogleFonts.jetBrainsMono(color: palette.textPrimary, fontSize: 13)),
                      const SizedBox(height: AppSpacing.sm),
                      const BibleChipRow(chips: ['LOG', 'GRADE']),
                      const SizedBox(height: AppSpacing.md),
                      BibleTextField(
                        label: 'LUT Name',
                        initialValue: widget.data.creativeLutName,
                        onChanged: (v) {
                          widget.data.creativeLutName = v;
                          widget.onChanged(widget.data);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SIMBOLOGÍA DE COLOR', style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.md),
              if (widget.data.visualConcept?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    widget.data.visualConcept!,
                    style: TextStyle(fontStyle: FontStyle.italic, color: palette.textSecondary),
                  ),
                ),
              BibleTextField(
                label: 'Simbología y significado narrativo',
                maxLines: 4,
                initialValue: widget.data.visualConcept,
                onChanged: (v) {
                  widget.data.visualConcept = v;
                  widget.onChanged(widget.data);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSliderRow(BuildContext context, String title, String value, double sliderValue) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(title, style: AppTypography.caption(palette))),
          Expanded(
            child: Slider(
              value: sliderValue,
              onChanged: null,
              activeColor: palette.accent,
            ),
          ),
          SizedBox(width: 80, child: Text(value, style: AppTypography.caption(palette), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
