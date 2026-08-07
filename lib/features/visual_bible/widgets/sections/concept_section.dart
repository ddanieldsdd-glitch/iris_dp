import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../bible_section_fields.dart';
import '../../moodboard_helpers.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_visual_color_sheet.dart';
import '../moodboard_strip.dart';
import 'section_scaffold.dart';

/// Concepto de imagen — Stitch Production + Visual Bible (glass bento).
class ConceptSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const ConceptSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    required this.onChanged,
  });

  Map<String, dynamic> _getCustomData() {
    if (sectionContentJson == null) return {};
    try {
      final decoded = jsonDecode(sectionContentJson!);
      if (decoded is Map<String, dynamic> && decoded.containsKey('_values')) {
        final vals = decoded['_values'] as Map<String, dynamic>;
        if (vals.containsKey('conceptData')) {
          return jsonDecode(vals['conceptData'] as String)
              as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return {};
  }

  Future<void> _updateCustomData(
    WidgetRef ref,
    Map<String, dynamic> update,
  ) async {
    final current = _getCustomData();
    final newData = {...current, ...update};
    final db = ref.read(databaseProvider);
    final def = await (db.select(db.bibleSectionDefinitions)
          ..where(
            (d) =>
                d.bibleId.equals(data.id) &
                d.id.equals(BibleSectionId.concept),
          ))
        .getSingleOrNull();
    if (def != null) {
      final fields = BibleSectionFieldsConfig.parse(
        def.contentJson,
        BibleSectionId.concept,
      );
      final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
      values['conceptData'] = jsonEncode(newData);
      await db.upsertBibleSectionDefinition(
        def.copyWith(
          contentJson: drift.Value(
            BibleSectionFieldsConfig.encode(fields, values: values),
          ),
        ),
      );
    }
  }

  Color? _parseHex(String? hex) {
    if (hex == null) return null;
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final custom = _getCustomData();

    final sceneTag = custom['sceneTag'] as String? ?? '';
    final colorSymbols = (custom['colorSymbols'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final act1 = custom['act1Intent'] as String? ?? '';
    final act2 = custom['act2Intent'] as String? ?? '';
    final act3 = custom['act3Intent'] as String? ?? '';
    final actTitles = (custom['actTitles'] as Map?)?.cast<String, String>() ??
        {
          '1': 'El Orden Frágil',
          '2': 'El Descenso',
          '3': 'La Resolución',
        };
    final actComp =
        (custom['actComposition'] as Map?)?.cast<String, String>() ??
            {
              '1': 'Symmetrical, Locked Off, Wide',
              '2': 'Handheld, Asymmetrical, Medium',
              '3': 'Chaotic, Extreme Close-ups, Dutch',
            };
    final metrics =
        (custom['lightingMetrics'] as Map?)?.cast<String, String>() ??
            {
              'contrast': data.contrastStyle ?? 'ALTO (4:1)',
              'motivation': 'PRÁCTICOS VISIBLES',
              'fill': 'NEGATIVO (CLOTH)',
              'eyeLight': 'PUNTUAL / CATCHLIGHT',
            };
    final filmEmu =
        custom['filmEmulation'] as String? ?? data.creativeLutName ?? '500T Push 1';
    final grainLabel =
        custom['grainLabel'] as String? ?? data.grainLevel ?? '35mm Coarse';
    final contrastRatio =
        custom['globalContrastRatio'] as String? ?? metrics['contrast'] ?? '64:1';
    final sharpness =
        custom['sharpnessHalation'] as String? ?? 'Soft/High';
    final textureProminence =
        (custom['textureProminence'] as num?)?.toInt().clamp(0, 4) ?? 3;
    final atmosphereText = custom['atmosphereText'] as String? ?? '';
    final atmosphereTags = (custom['atmosphereTags'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final shadowTreatment = custom['shadowTreatment'] as String? ?? '';
    final keyFrameTitle =
        custom['keyFrameTitle'] as String? ?? 'Key Frame Analysis';
    final keyFrameTech = custom['keyFrameTech'] as String? ??
        'Aspect Ratio: ${data.aspectRatio ?? '2.39:1'} / Focal: 21mm / T2.8';
    final refsMetadata = (custom['refsMetadata'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return BibleSectionScaffold(
      sectionId: BibleSectionId.concept,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint: '¿Qué debe sentir el ojo del espectador en cada acto?',
      sectionNumber: null,
      sectionTitle: 'Concepto de Imagen',
      fieldWidgets: {
        'visualConcept': LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;

            final paletteCard = _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Paleta de Color',
                        style: AppTypography.titleMedium(palette)
                            .copyWith(fontSize: 20),
                      ),
                      const Spacer(),
                      Text(
                        'MASTER COLORS',
                        style: AppTypography.label(palette).copyWith(
                          color: palette.textTertiary,
                          letterSpacing: 1.2,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  StreamBuilder<List<VisualBibleColorBlock>>(
                    stream: db.watchColorBlocksForBible(data.id),
                    builder: (context, snap) {
                      final blocks = snap.data
                              ?.map(ColorBlockModel.fromRow)
                              .toList() ??
                          [];
                      final swatches = <(String, String)>[];
                      for (final b in blocks) {
                        for (final c in b.dominantColors) {
                          if (swatches.length >= 7) break;
                          swatches.add((b.blockName, c));
                        }
                        for (final c in b.accentColors) {
                          if (swatches.length >= 7) break;
                          swatches.add(('${b.blockName} · acento', c));
                        }
                        if (swatches.length >= 7) break;
                      }
                      if (swatches.isEmpty) {
                        return Text(
                          'Define colores en Color e imagen.',
                          style: AppTypography.bodyMedium(palette),
                        );
                      }
                      return LayoutBuilder(
                        builder: (context, c) {
                          final cols = c.maxWidth >= 700
                              ? swatches.length.clamp(1, 7)
                              : (c.maxWidth >= 420 ? 4 : 2);
                          return Wrap(
                            spacing: 10,
                            runSpacing: 14,
                            children: [
                              for (final s in swatches)
                                SizedBox(
                                  width: (c.maxWidth - (cols - 1) * 10) / cols,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 88,
                                        decoration: BoxDecoration(
                                          color: _parseHex(s.$2) ??
                                              palette.surfaceOverlay,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: () {
                                          Clipboard.setData(
                                            ClipboardData(text: s.$2),
                                          );
                                        },
                                        child: Text(
                                          s.$2.toUpperCase(),
                                          style: AppTypography.mono(palette)
                                              .copyWith(
                                            fontSize: 12,
                                            color: palette.textSecondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        s.$1.toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.label(palette)
                                            .copyWith(
                                          fontSize: 10,
                                          color: palette.textTertiary,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );

            final contrastCard = _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contraste y Textura',
                    style: AppTypography.titleMedium(palette)
                        .copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 16),
                  _TechScrubRow(
                    label: 'Global Contrast Ratio',
                    value: contrastRatio,
                    palette: palette,
                    accent: true,
                    onEdit: (v) {
                      _updateCustomData(ref, {'globalContrastRatio': v});
                      data.contrastStyle = v;
                      onChanged(data);
                    },
                  ),
                  _TechScrubRow(
                    label: 'Film Grain (Emulation)',
                    value: filmEmu,
                    palette: palette,
                    onEdit: (v) {
                      _updateCustomData(ref, {'filmEmulation': v});
                      data.creativeLutName = v;
                      onChanged(data);
                    },
                  ),
                  _TechScrubRow(
                    label: 'Sharpness / Halation',
                    value: sharpness,
                    palette: palette,
                    warn: true,
                    onEdit: (v) =>
                        _updateCustomData(ref, {'sharpnessHalation': v}),
                  ),
                  _TechScrubRow(
                    label: 'Grano Base',
                    value: grainLabel,
                    palette: palette,
                    onEdit: (v) {
                      _updateCustomData(ref, {'grainLabel': v});
                      data.grainLevel = v;
                      onChanged(data);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Texture Prominence',
                          style: AppTypography.bodyMedium(palette).copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                      _TextureBars(
                        level: textureProminence,
                        palette: palette,
                        onChanged: (v) =>
                            _updateCustomData(ref, {'textureProminence': v}),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'DIFUSIÓN EN ÓPTICA',
                    style: AppTypography.label(palette).copyWith(
                      color: palette.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  BibleTextField(
                    label: '',
                    hint: 'Glimmerglass 1/4…',
                    initialValue: data.diffusionNotes ?? '',
                    onChanged: (v) {
                      data.diffusionNotes = v;
                      onChanged(data);
                    },
                  ),
                ],
              ),
            );

            final atmosphereCard = _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Atmósfera Visual',
                    style: AppTypography.titleMedium(palette)
                        .copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  BibleTextField(
                    label: '',
                    hint:
                        'Desaturada, calor monocromático, polvo en suspensión…',
                    maxLines: 4,
                    initialValue: atmosphereText,
                    onChanged: (v) =>
                        _updateCustomData(ref, {'atmosphereText': v}),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < atmosphereTags.length; i++)
                        InputChip(
                          label: Text(
                            atmosphereTags[i].toUpperCase(),
                            style: AppTypography.label(palette).copyWith(
                              fontSize: 10,
                              color: const Color(0xFFADB9D1),
                            ),
                          ),
                          onDeleted: () {
                            final next = List<String>.from(atmosphereTags)
                              ..removeAt(i);
                            _updateCustomData(ref, {'atmosphereTags': next});
                          },
                          backgroundColor: palette.surfaceElevated,
                          side: BorderSide.none,
                          deleteIconColor: palette.textTertiary,
                        ),
                      ActionChip(
                        avatar: Icon(Icons.add, size: 14, color: palette.accent),
                        label: Text(
                          'TAG',
                          style: AppTypography.label(palette).copyWith(
                            fontSize: 10,
                            color: palette.accent,
                          ),
                        ),
                        onPressed: () async {
                          final c = TextEditingController();
                          final v = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Tag de atmósfera'),
                              content: TextField(
                                controller: c,
                                autofocus: true,
                                textCapitalization:
                                    TextCapitalization.characters,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, c.text.trim()),
                                  child: const Text('Añadir'),
                                ),
                              ],
                            ),
                          );
                          if (v == null || v.isEmpty) return;
                          await _updateCustomData(ref, {
                            'atmosphereTags': [...atmosphereTags, v],
                          });
                        },
                        backgroundColor: Colors.transparent,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );

            final symbolismCard = _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardHeader(
                    icon: Icons.psychology_outlined,
                    title: 'Simbología de Color',
                    palette: palette,
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < colorSymbols.length; i++) ...[
                    _SymbolCard(
                      hex: colorSymbols[i]['hex']?.toString() ?? '#FFFFFF',
                      name: colorSymbols[i]['poeticName']?.toString() ??
                          'Nombre',
                      meaning: colorSymbols[i]['narrativeMeaning']
                              ?.toString() ??
                          '',
                      palette: palette,
                      parseHex: _parseHex,
                      onEdit: () async {
                        final result = await _editSymbolDialog(
                          context,
                          name: colorSymbols[i]['poeticName']?.toString() ?? '',
                          meaning: colorSymbols[i]['narrativeMeaning']
                                  ?.toString() ??
                              '',
                          hex: colorSymbols[i]['hex']?.toString() ?? '#FFFFFF',
                        );
                        if (result == null) return;
                        final updated =
                            List<Map<String, dynamic>>.from(colorSymbols);
                        updated[i] = result;
                        await _updateCustomData(
                          ref,
                          {'colorSymbols': updated},
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await _editSymbolDialog(
                        context,
                        name: '',
                        meaning: '',
                        hex: '#1B3A4B',
                      );
                      if (result == null) return;
                      final updated =
                          List<Map<String, dynamic>>.from(colorSymbols)
                            ..add(result);
                      await _updateCustomData(
                        ref,
                        {'colorSymbols': updated},
                      );
                    },
                    icon: Icon(Icons.add, size: 16, color: palette.accent),
                    label: Text(
                      'AÑADIR SIMBOLOGÍA',
                      style: AppTypography.label(palette).copyWith(
                        color: palette.accent,
                        fontSize: 10,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      minimumSize: const Size.fromHeight(40),
                    ),
                  ),
                ],
              ),
            );

            final lightingCard = _GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardHeader(
                    icon: Icons.lightbulb_outline,
                    title: 'Filosofía de Luz',
                    palette: palette,
                  ),
                  const SizedBox(height: 12),
                  BibleTextField(
                    label: '',
                    hint: 'Noir moderno, far-side key…',
                    maxLines: 4,
                    initialValue: data.lightingPhilosophy ?? '',
                    onChanged: (v) {
                      data.lightingPhilosophy = v;
                      onChanged(data);
                    },
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth > 520 ? 4 : 2;
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.5,
                        children: [
                          _MetricTile(
                            label: 'Contraste',
                            value: metrics['contrast'] ?? '—',
                            palette: palette,
                            onEdit: (v) => _updateCustomData(ref, {
                              'lightingMetrics': {
                                ...metrics,
                                'contrast': v,
                              },
                            }),
                          ),
                          _MetricTile(
                            label: 'Motivación',
                            value: metrics['motivation'] ?? '—',
                            palette: palette,
                            onEdit: (v) => _updateCustomData(ref, {
                              'lightingMetrics': {
                                ...metrics,
                                'motivation': v,
                              },
                            }),
                          ),
                          _MetricTile(
                            label: 'Fill Light',
                            value: metrics['fill'] ?? '—',
                            palette: palette,
                            onEdit: (v) => _updateCustomData(ref, {
                              'lightingMetrics': {...metrics, 'fill': v},
                            }),
                          ),
                          _MetricTile(
                            label: 'Eye Light',
                            value: metrics['eyeLight'] ?? '—',
                            palette: palette,
                            onEdit: (v) => _updateCustomData(ref, {
                              'lightingMetrics': {
                                ...metrics,
                                'eyeLight': v,
                              },
                            }),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );

            final refsGallery = _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Cinematic References',
                        style: AppTypography.titleMedium(palette)
                            .copyWith(fontSize: 20),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          await MoodboardHelpers.addManualImages(
                            db: db,
                            projectId: projectId,
                            bibleId: data.id,
                            category: MoodboardCategory.reference,
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'AÑADIR FRAME',
                              style: AppTypography.label(palette).copyWith(
                                color: palette.accent,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: palette.accent,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CinematicRefsGrid(
                    projectId: projectId,
                    palette: palette,
                    keyFrameTitle: keyFrameTitle,
                    keyFrameTech: keyFrameTech,
                    onEditKeyFrame: () async {
                      final t = TextEditingController(text: keyFrameTitle);
                      final tech = TextEditingController(text: keyFrameTech);
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Key Frame Analysis'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: t,
                                decoration:
                                    const InputDecoration(labelText: 'Título'),
                              ),
                              TextField(
                                controller: tech,
                                decoration: const InputDecoration(
                                  labelText: 'Tech line',
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Guardar'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await _updateCustomData(ref, {
                          'keyFrameTitle': t.text.trim(),
                          'keyFrameTech': tech.text.trim(),
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  MoodboardStrip.forSection(
                    projectId: projectId,
                    sectionId: BibleSectionId.concept,
                    showTitle: false,
                    showCaptions: true,
                  ),
                ],
              ),
            );

            final shadowsCard = _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tratamiento de Sombras',
                    style: AppTypography.titleMedium(palette)
                        .copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  BibleTextField(
                    label: '',
                    hint:
                        'Negros densos (#0a0a0c), fill mínimo, sombras como elemento compositivo…',
                    maxLines: 5,
                    initialValue: shadowTreatment,
                    onChanged: (v) =>
                        _updateCustomData(ref, {'shadowTreatment': v}),
                  ),
                ],
              ),
            );

            final compositionCard = _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Composición por Actos',
                    style: AppTypography.titleMedium(palette)
                        .copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 14),
                  for (final n in ['1', '2', '3']) ...[
                    _CompositionActRow(
                      actLabel: 'Act ${['I', 'II', 'III'][int.parse(n) - 1]}:',
                      value: actComp[n] ?? '—',
                      palette: palette,
                      onEdit: (v) => _updateCustomData(ref, {
                        'actComposition': {...actComp, n: v},
                      }),
                    ),
                    if (n != '3') const SizedBox(height: 10),
                  ],
                ],
              ),
            );

            final actsTimeline = _GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardHeader(
                    icon: Icons.timeline,
                    title: 'Intención Visual por Acto',
                    palette: palette,
                  ),
                  const SizedBox(height: 20),
                  _ActTimelineItem(
                    roman: 'I',
                    title: actTitles['1'] ?? 'Acto I',
                    body: act1,
                    showLine: true,
                    palette: palette,
                    onEdit: (title, body) async {
                      await _updateCustomData(ref, {
                        'act1Intent': body,
                        'actTitles': {...actTitles, '1': title},
                      });
                    },
                  ),
                  _ActTimelineItem(
                    roman: 'II',
                    title: actTitles['2'] ?? 'Acto II',
                    body: act2,
                    showLine: true,
                    palette: palette,
                    onEdit: (title, body) async {
                      await _updateCustomData(ref, {
                        'act2Intent': body,
                        'actTitles': {...actTitles, '2': title},
                      });
                    },
                  ),
                  _ActTimelineItem(
                    roman: 'III',
                    title: actTitles['3'] ?? 'Acto III',
                    body: act3,
                    showLine: false,
                    palette: palette,
                    onEdit: (title, body) async {
                      await _updateCustomData(ref, {
                        'act3Intent': body,
                        'actTitles': {...actTitles, '3': title},
                      });
                    },
                  ),
                ],
              ),
            );

            final refsMeta = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.movie_outlined, color: palette.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Fichas de Referencia',
                      style: AppTypography.titleMedium(palette)
                          .copyWith(fontSize: 18),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        final edited = await _editRefDialog(context, {
                          'film': '',
                          'dp': '',
                          'director': '',
                          'tone': '',
                          'intent': '',
                        });
                        if (edited == null) return;
                        final updated =
                            List<Map<String, dynamic>>.from(refsMetadata)
                              ..add(edited);
                        await _updateCustomData(
                          ref,
                          {'refsMetadata': updated},
                        );
                      },
                      icon: Icon(Icons.add, color: palette.accent, size: 16),
                      label: Text(
                        'Añadir ficha',
                        style: TextStyle(color: palette.accent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...refsMetadata.map((refData) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReferenceMetaCard(
                      data: refData,
                      palette: palette,
                      onEdit: () async {
                        final edited = await _editRefDialog(context, refData);
                        if (edited == null) return;
                        final idx = refsMetadata.indexOf(refData);
                        final updated =
                            List<Map<String, dynamic>>.from(refsMetadata);
                        updated[idx] = edited;
                        await _updateCustomData(
                          ref,
                          {'refsMetadata': updated},
                        );
                      },
                    ),
                  );
                }),
              ],
            );

            final leftCol = Column(
              children: [
                contrastCard,
                const SizedBox(height: 16),
                atmosphereCard,
                const SizedBox(height: 16),
                symbolismCard,
              ],
            );

            final rightCol = Column(
              children: [
                lightingCard,
                const SizedBox(height: 16),
                refsGallery,
                const SizedBox(height: 16),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: shadowsCard),
                      const SizedBox(width: 16),
                      Expanded(child: compositionCard),
                    ],
                  )
                else ...[
                  shadowsCard,
                  const SizedBox(height: 16),
                  compositionCard,
                ],
                const SizedBox(height: 16),
                actsTimeline,
                const SizedBox(height: 16),
                refsMeta,
              ],
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ConceptIntro(
                  data: data,
                  onChanged: onChanged,
                  sceneTag: sceneTag,
                  onSceneTagEdit: (v) =>
                      _updateCustomData(ref, {'sceneTag': v}),
                ),
                const SizedBox(height: 28),
                paletteCard,
                const SizedBox(height: 20),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: leftCol),
                      const SizedBox(width: 20),
                      Expanded(flex: 8, child: rightCol),
                    ],
                  )
                else ...[
                  leftCol,
                  const SizedBox(height: 20),
                  rightCol,
                ],
              ],
            );
          },
        ),
      },
    );
  }

  Future<Map<String, dynamic>?> _editSymbolDialog(
    BuildContext context, {
    required String name,
    required String meaning,
    required String hex,
  }) async {
    final picked = await BibleVisualColorSheet.show(
      context,
      title: 'Simbología de color',
      initialName: name,
      initialColor: _parseHex(hex) ?? const Color(0xFF1B3A4B),
      nameHint: 'Nombre poético del color',
      includeMeaning: true,
      initialMeaning: meaning,
    );
    if (picked == null || picked.delete) return null;
    return {
      'poeticName': picked.name,
      'hex': picked.hex,
      'narrativeMeaning': picked.meaning ?? '',
    };
  }

  Future<Map<String, dynamic>?> _editRefDialog(
    BuildContext context,
    Map<String, dynamic> initial,
  ) async {
    final film = TextEditingController(text: initial['film']?.toString() ?? '');
    final dp = TextEditingController(text: initial['dp']?.toString() ?? '');
    final dir =
        TextEditingController(text: initial['director']?.toString() ?? '');
    final tone = TextEditingController(text: initial['tone']?.toString() ?? '');
    final intent =
        TextEditingController(text: initial['intent']?.toString() ?? '');
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Referencia'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: film,
                decoration: const InputDecoration(labelText: 'Película'),
              ),
              TextField(
                controller: dp,
                decoration: const InputDecoration(labelText: 'DP'),
              ),
              TextField(
                controller: dir,
                decoration: const InputDecoration(labelText: 'Director'),
              ),
              TextField(
                controller: tone,
                decoration: const InputDecoration(labelText: 'Tono'),
              ),
              TextField(
                controller: intent,
                decoration: const InputDecoration(labelText: 'Intención'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'film': film.text.trim(),
              'dp': dp.text.trim(),
              'director': dir.text.trim(),
              'tone': tone.text.trim(),
              'intent': intent.text.trim(),
            }),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _ConceptIntro extends StatelessWidget {
  final VisualBibleData data;
  final BibleChanged onChanged;
  final String sceneTag;
  final ValueChanged<String> onSceneTagEdit;

  const _ConceptIntro({
    required this.data,
    required this.onChanged,
    required this.sceneTag,
    required this.onSceneTagEdit,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              'Concepto de Imagen',
              style: AppTypography.displayMedium(palette).copyWith(
                fontSize: 40,
                letterSpacing: -0.8,
              ),
            ),
            Material(
              color: palette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () async {
                  final c = TextEditingController(text: sceneTag);
                  final v = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Escena / contexto'),
                      content: TextField(
                        controller: c,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'SCENE 4A — THE DUNE',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, c.text.trim()),
                          child: const Text('Guardar'),
                        ),
                      ],
                    ),
                  );
                  if (v != null) onSceneTagEdit(v);
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    sceneTag.isEmpty ? '+ ESCENA' : sceneTag.toUpperCase(),
                    style: AppTypography.mono(palette).copyWith(
                      fontSize: 12,
                      color: palette.accent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BibleTextField(
          label: '',
          hint:
              'El ADN visual del proyecto. Naturalismo estilizado, contrastes…',
          maxLines: 3,
          initialValue: data.conceptNarrativeIntent ?? data.visualConcept ?? '',
          onChanged: (v) {
            data.conceptNarrativeIntent = v;
            data.visualConcept = v;
            onChanged(data);
          },
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.05),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final AppPalette palette;

  const _CardHeader({
    required this.icon,
    required this.title,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: palette.accent, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.titleMedium(palette).copyWith(fontSize: 18),
        ),
      ],
    );
  }
}

class _TechScrubRow extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final ValueChanged<String> onEdit;
  final bool accent;
  final bool warn;

  const _TechScrubRow({
    required this.label,
    required this.value,
    required this.palette,
    required this.onEdit,
    this.accent = false,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warn
        ? const Color(0xFFFFB4AB)
        : accent
            ? palette.accent
            : palette.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final c = TextEditingController(text: value);
          final v = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(label),
              content: TextField(controller: c, autofocus: true),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, c.text.trim()),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          if (v != null && v.isNotEmpty) onEdit(v);
        },
        child: Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium(palette).copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
              Text(
                value,
                style: AppTypography.mono(palette).copyWith(
                  color: color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextureBars extends StatelessWidget {
  final int level;
  final AppPalette palette;
  final ValueChanged<int> onChanged;

  const _TextureBars({
    required this.level,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 4; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 1 ? 0 : 4),
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                width: 28,
                height: 8,
                decoration: BoxDecoration(
                  color: i <= level
                      ? palette.accent
                      : palette.surfaceElevated,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CinematicRefsGrid extends ConsumerWidget {
  final int projectId;
  final AppPalette palette;
  final String keyFrameTitle;
  final String keyFrameTech;
  final VoidCallback onEditKeyFrame;

  const _CinematicRefsGrid({
    required this.projectId,
    required this.palette,
    required this.keyFrameTitle,
    required this.keyFrameTech,
    required this.onEditKeyFrame,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImagesForSection(
        projectId,
        BibleSectionId.concept,
      ),
      builder: (context, snap) {
        final images = snap.data ?? [];
        if (images.isEmpty) {
          return Text(
            'Sin referencias aún. Añade frames o asigna en Moodboard.',
            style: AppTypography.caption(palette).copyWith(
              color: palette.textTertiary,
            ),
          );
        }

        final thumbs = images.take(3).toList();
        final hero = images.length > 3 ? images[3] : images.first;

        return Column(
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 520 ? 3 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: thumbs.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 16 / 9,
                  ),
                  itemBuilder: (context, i) {
                    final model = MoodboardImageModel.fromRow(thumbs[i]);
                    final file = File(model.imagePath);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          file.existsSync()
                              ? Image.file(file, fit: BoxFit.cover)
                              : ColoredBox(color: palette.surfaceOverlay),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0xCC131315),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Text(
                                (model.filmReference ??
                                        model.caption ??
                                        'REF')
                                    .toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label(palette).copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onEditKeyFrame,
                borderRadius: BorderRadius.circular(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AspectRatio(
                    aspectRatio: 21 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Builder(
                          builder: (_) {
                            final model = MoodboardImageModel.fromRow(hero);
                            final file = File(model.imagePath);
                            return file.existsSync()
                                ? Image.file(file, fit: BoxFit.cover)
                                : ColoredBox(color: palette.surfaceOverlay);
                          },
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Color(0xE6131315),
                                Color(0x33131315),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                keyFrameTitle,
                                style: AppTypography.titleMedium(palette)
                                    .copyWith(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                keyFrameTech,
                                style: AppTypography.mono(palette).copyWith(
                                  fontSize: 12,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CompositionActRow extends StatelessWidget {
  final String actLabel;
  final String value;
  final AppPalette palette;
  final ValueChanged<String> onEdit;

  const _CompositionActRow({
    required this.actLabel,
    required this.value,
    required this.palette,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final c = TextEditingController(text: value);
        final v = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(actLabel),
            content: TextField(controller: c, autofocus: true),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, c.text.trim()),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (v != null && v.isNotEmpty) onEdit(v);
      },
      child: Row(
        children: [
          Text(
            actLabel,
            style: AppTypography.mono(palette).copyWith(
              color: palette.textPrimary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.mono(palette).copyWith(
                color: palette.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SymbolCard extends StatelessWidget {
  final String hex;
  final String name;
  final String meaning;
  final AppPalette palette;
  final Color? Function(String?) parseHex;
  final VoidCallback onEdit;

  const _SymbolCard({
    required this.hex,
    required this.name,
    required this.meaning,
    required this.palette,
    required this.parseHex,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = parseHex(hex) ?? palette.accent;
    return Material(
      color: palette.surfaceOverlay.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: c, width: 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.toUpperCase(),
                style: AppTypography.label(palette).copyWith(
                  fontSize: 10,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                meaning.isEmpty ? 'Toca para editar…' : meaning,
                style: AppTypography.bodyMedium(palette).copyWith(
                  fontSize: 12,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final ValueChanged<String> onEdit;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.palette,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surfaceOverlay.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () async {
          final c = TextEditingController(text: value);
          final v = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(label),
              content: TextField(controller: c, autofocus: true),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, c.text.trim()),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          if (v != null && v.isNotEmpty) onEdit(v);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 11,
                  color: palette.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                value.toUpperCase(),
                style: AppTypography.label(palette).copyWith(
                  color: palette.accent,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActTimelineItem extends StatelessWidget {
  final String roman;
  final String title;
  final String body;
  final bool showLine;
  final AppPalette palette;
  final Future<void> Function(String title, String body) onEdit;

  const _ActTimelineItem({
    required this.roman,
    required this.title,
    required this.body,
    required this.showLine,
    required this.palette,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.accent.withValues(alpha: 0.2),
                ),
                child: Text(
                  roman,
                  style: AppTypography.label(palette).copyWith(
                    color: palette.accent,
                    fontSize: 11,
                  ),
                ),
              ),
              if (showLine)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 20 : 0),
              child: InkWell(
                onTap: () async {
                  final t = TextEditingController(text: title);
                  final b = TextEditingController(text: body);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Acto $roman'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: t,
                            decoration:
                                const InputDecoration(labelText: 'Título'),
                          ),
                          TextField(
                            controller: b,
                            maxLines: 4,
                            decoration:
                                const InputDecoration(labelText: 'Intención'),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Guardar'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await onEdit(t.text.trim(), b.text.trim());
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTO $roman: ${title.toUpperCase()}',
                      style: AppTypography.label(palette).copyWith(
                        color: palette.textPrimary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body.isEmpty ? 'Toca para definir la intención…' : body,
                      style: AppTypography.bodyMedium(palette).copyWith(
                        fontSize: 13,
                        color: palette.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceMetaCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final AppPalette palette;
  final VoidCallback onEdit;

  const _ReferenceMetaCard({
    required this.data,
    required this.palette,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xB31A1A1C),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['film']?.toString().isNotEmpty == true
                    ? data['film'].toString()
                    : 'Referencia',
                style: AppTypography.titleMedium(palette),
              ),
              const SizedBox(height: 4),
              Text(
                'Dir. Fotografía: ${data['dp'] ?? '—'}'
                '${data['director'] != null && data['director'].toString().isNotEmpty ? ' · Dir: ${data['director']}' : ''}',
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 11,
                  color: palette.textTertiary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _mini('Tono', data['tone']?.toString() ?? '—'),
                  ),
                  Expanded(
                    child:
                        _mini('Intención', data['intent']?.toString() ?? '—'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.label(palette).copyWith(
            fontSize: 9,
            color: palette.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.mono(palette).copyWith(
            fontSize: 11,
            color: palette.textPrimary,
          ),
        ),
      ],
    );
  }
}
