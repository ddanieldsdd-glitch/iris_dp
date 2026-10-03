import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/visual_bible/concept_points.dart';
import '../../../../shared/visual_bible/format_pilot_resolve.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../../../../shared/visual_bible/bible_reference.dart';
import '../../moodboard_helpers.dart';
import '../bible_navigation_scope.dart';
import '../bible_point_images.dart';
import '../bible_references_deck.dart';
import '../bible_point_panel.dart';
import '../bible_visual_color_sheet.dart';
import 'section_scaffold.dart';

/// Datos propios de Concepto dentro de `contentJson` (`values.conceptData`).
Map<String, dynamic> _conceptBlob(String? contentJson) {
  if (contentJson == null || contentJson.isEmpty) return {};
  try {
    final decoded = jsonDecode(contentJson);
    if (decoded is! Map<String, dynamic>) return {};
    final values = decoded['values'] ?? decoded['_values'];
    if (values is Map && values['conceptData'] is String) {
      final blob = jsonDecode(values['conceptData'] as String);
      if (blob is Map<String, dynamic>) return blob;
    }
  } catch (_) {}
  return {};
}

/// Concepto de imagen — Stitch Production + Visual Bible (glass bento).
class ConceptSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final String? formatSectionContentJson;
  final BibleChanged onChanged;

  const ConceptSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    this.formatSectionContentJson,
    required this.onChanged,
  });

  Map<String, dynamic> _getCustomData() => _conceptBlob(sectionContentJson);

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
        'colorPalette': _ConceptStitchModule(
          slot: 'colorPalette',
          data: data,
          projectId: projectId,
          palette: palette,
          db: db,
          onChanged: onChanged,
          sectionContentJson: sectionContentJson,
          formatSectionContentJson: formatSectionContentJson,
          parseHex: _parseHex,
          updateCustomData: _updateCustomData,
          editSymbol: _editSymbolDialog,
        ),
        'colorSymbolism': _ConceptStitchModule(
          slot: 'colorSymbolism',
          data: data,
          projectId: projectId,
          palette: palette,
          db: db,
          onChanged: onChanged,
          sectionContentJson: sectionContentJson,
          formatSectionContentJson: formatSectionContentJson,
          parseHex: _parseHex,
          updateCustomData: _updateCustomData,
          editSymbol: _editSymbolDialog,
        ),
        'lightPhilosophy': _ConceptStitchModule(
          slot: 'lightPhilosophy',
          data: data,
          projectId: projectId,
          palette: palette,
          db: db,
          onChanged: onChanged,
          sectionContentJson: sectionContentJson,
          formatSectionContentJson: formatSectionContentJson,
          parseHex: _parseHex,
          updateCustomData: _updateCustomData,
          editSymbol: _editSymbolDialog,
        ),
        'keyFrame': _ConceptStitchModule(
          slot: 'keyFrame',
          data: data,
          projectId: projectId,
          palette: palette,
          db: db,
          onChanged: onChanged,
          sectionContentJson: sectionContentJson,
          formatSectionContentJson: formatSectionContentJson,
          parseHex: _parseHex,
          updateCustomData: _updateCustomData,
          editSymbol: _editSymbolDialog,
        ),
        'shadowTreatment': _ConceptStitchModule(
          slot: 'shadowTreatment',
          data: data,
          projectId: projectId,
          palette: palette,
          db: db,
          onChanged: onChanged,
          sectionContentJson: sectionContentJson,
          formatSectionContentJson: formatSectionContentJson,
          parseHex: _parseHex,
          updateCustomData: _updateCustomData,
          editSymbol: _editSymbolDialog,
        ),
        'actComposition': _ConceptStitchModule(
          slot: 'actComposition',
          data: data,
          projectId: projectId,
          palette: palette,
          db: db,
          onChanged: onChanged,
          sectionContentJson: sectionContentJson,
          formatSectionContentJson: formatSectionContentJson,
          parseHex: _parseHex,
          updateCustomData: _updateCustomData,
          editSymbol: _editSymbolDialog,
        ),
        'actNotes': _ConceptStitchModule(
          slot: 'actNotes',
          data: data,
          projectId: projectId,
          palette: palette,
          db: db,
          onChanged: onChanged,
          sectionContentJson: sectionContentJson,
          formatSectionContentJson: formatSectionContentJson,
          parseHex: _parseHex,
          updateCustomData: _updateCustomData,
          editSymbol: _editSymbolDialog,
        ),
        'composition': _ConceptStitchModule(
          slot: 'composition',
          data: data,
          projectId: projectId,
          palette: palette,
          db: db,
          onChanged: onChanged,
          sectionContentJson: sectionContentJson,
          formatSectionContentJson: formatSectionContentJson,
          parseHex: _parseHex,
          updateCustomData: _updateCustomData,
          editSymbol: _editSymbolDialog,
        ),
        if (data.id > 0)
          'references': _ConceptStitchModule(
          slot: 'references',
          data: data,
          projectId: projectId,
          palette: palette,
          db: db,
          onChanged: onChanged,
          sectionContentJson: sectionContentJson,
          formatSectionContentJson: formatSectionContentJson,
          parseHex: _parseHex,
          updateCustomData: _updateCustomData,
          editSymbol: _editSymbolDialog,
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
      canDelete: name.isNotEmpty,
    );
    if (picked == null) return null;
    if (picked.delete) return const {'_delete': true};
    return {
      'poeticName': picked.name,
      'hex': picked.hex,
      'narrativeMeaning': picked.meaning ?? '',
    };
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
      decoration: BiblePointPanel.decoration(context.palette),
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
        Icon(icon, color: palette.accent, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: BiblePointPanel.labelStyle(palette),
          ),
        ),
      ],
    );
  }
}

/// Muestra de la paleta maestra: color, código y nombre.
class _PaletteSwatch extends StatelessWidget {
  final Color? color;
  final String hex;
  final String name;
  final AppPalette palette;
  final VoidCallback onTap;

  const _PaletteSwatch({
    required Color this.color,
    required this.hex,
    required this.name,
    required this.palette,
    required this.onTap,
  });

  const _PaletteSwatch.add({required this.palette, required this.onTap})
      : color = null,
        hex = '',
        name = '';

  @override
  Widget build(BuildContext context) {
    final label = BiblePointPanel.labelStyle(palette).copyWith(fontSize: 10);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 96,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.borderBright),
              ),
              child: color == null
                  ? Center(
                      child: Icon(Icons.add, color: palette.textSecondary),
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              color == null ? 'AÑADIR' : hex.toUpperCase(),
              style: AppTypography.mono(palette).copyWith(fontSize: 11),
            ),
            if (name.isNotEmpty)
              Text(
                name.toUpperCase(),
                style: label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
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

/// Módulos Stitch descompuestos para el panel Widgets ↔ pantalla.
class _ConceptStitchModule extends ConsumerWidget {
  final String slot;
  final VisualBibleData data;
  final int projectId;
  final AppPalette palette;
  final AppDatabase db;
  final String? sectionContentJson;
  final String? formatSectionContentJson;
  final BibleChanged onChanged;
  final Color? Function(String?) parseHex;
  final Future<void> Function(WidgetRef ref, Map<String, dynamic> update)
      updateCustomData;
  final Future<Map<String, dynamic>?> Function(
    BuildContext context, {
    required String name,
    required String meaning,
    required String hex,
  }) editSymbol;

  const _ConceptStitchModule({
    required this.slot,
    required this.data,
    required this.projectId,
    required this.palette,
    required this.db,
    required this.onChanged,
    required this.sectionContentJson,
    this.formatSectionContentJson,
    required this.parseHex,
    required this.updateCustomData,
    required this.editSymbol,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = _conceptBlob(sectionContentJson);
    final colorSymbols = (custom['colorSymbols'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final actTitles = (custom['actTitles'] as Map?)?.cast<String, String>() ??
        kConceptActTitles;
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
              if (data.contrastStyle?.isNotEmpty == true)
                'contrast': data.contrastStyle!,
            };
    final composition = custom['composition'] as String? ?? '';
    final compositionMetrics =
        (custom['compositionMetrics'] as Map?)?.cast<String, String>() ?? {};
    final masterPalette = [
      for (final e in (custom['masterPalette'] as List? ?? kConceptStarterPalette))
        if (e is Map) {'hex': '${e['hex'] ?? ''}', 'name': '${e['name'] ?? ''}'},
    ];
    final usesStarterPalette = custom['masterPalette'] == null;

    // Imágenes del moodboard que acompañan al texto de un punto.
    Widget pointImages(String key) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: BiblePointImages(
            projectId: projectId,
            bibleId: data.id,
            sectionId: BibleSectionId.concept,
            imageIds: biblePointImageIds(custom, key),
            onChanged: (ids) => updateCustomData(ref, {
              'pointImages': biblePointImagesWith(custom, key, ids),
            }),
          ),
        );

    Future<void> editSwatch(int? index) async {
      final current = index == null ? null : masterPalette[index];
      final picked = await BibleVisualColorSheet.show(
        context,
        title: 'Color de la paleta',
        initialName: current?['name'] ?? '',
        initialColor: parseHex(current?['hex']) ?? const Color(0xFF1B3A4B),
        nameHint: 'Nombre del color',
        canDelete: index != null,
      );
      if (picked == null) return;
      final next = [...masterPalette];
      if (picked.delete) {
        if (index != null) next.removeAt(index);
      } else if (index != null) {
        next[index] = {'hex': picked.hex, 'name': picked.name};
      } else {
        next.add({'hex': picked.hex, 'name': picked.name});
      }
      await updateCustomData(ref, {'masterPalette': next});
    }

    Widget addButton(String label, VoidCallback onTap) => Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onTap,
            icon: Icon(Icons.add, size: 16, color: palette.textSecondary),
            label: Text(
              label.toUpperCase(),
              style: BiblePointPanel.labelStyle(palette),
            ),
          ),
        );
    final shadowTreatment = custom['shadowTreatment'] as String? ?? '';
    final keyFrameTitle =
        custom['keyFrameTitle'] as String? ?? 'Key Frame Analysis';
    final formatBlob = FormatPilotResolve.parseBlob(formatSectionContentJson);
    final aspectLabel =
        FormatPilotResolve.activeRatio(formatBlob, data) ?? '2.39:1';
    final keyFrameTech = custom['keyFrameTech'] as String? ??
        'Aspect Ratio: $aspectLabel / Focal: 21mm / T2.8';
    final act1 = custom['act1Intent'] as String? ?? '';
    final act2 = custom['act2Intent'] as String? ?? '';
    final act3 = custom['act3Intent'] as String? ?? '';

    return switch (slot) {
      'colorPalette' => _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                icon: Icons.palette_outlined,
                title: 'Paleta Maestra',
                palette: palette,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  for (var i = 0; i < masterPalette.length; i++)
                    _PaletteSwatch(
                      color: parseHex(masterPalette[i]['hex']) ??
                          palette.surfaceOverlay,
                      hex: masterPalette[i]['hex'] ?? '',
                      name: masterPalette[i]['name'] ?? '',
                      palette: palette,
                      onTap: () => editSwatch(i),
                    ),
                  _PaletteSwatch.add(
                    palette: palette,
                    onTap: () => editSwatch(null),
                  ),
                ],
              ),
              if (usesStarterPalette)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Paleta de partida. Toca un color para hacerla tuya.',
                    style: AppTypography.caption(palette),
                  ),
                ),
              pointImages('colorPalette'),
            ],
          ),
        ),
      'colorSymbolism' => _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                icon: Icons.psychology_outlined,
                title: 'Simbología de Color',
                palette: palette,
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < colorSymbols.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SymbolCard(
                    hex: colorSymbols[i]['hex']?.toString() ?? '',
                    name: colorSymbols[i]['poeticName']?.toString() ?? 'Color',
                    meaning:
                        colorSymbols[i]['narrativeMeaning']?.toString() ?? '',
                    palette: palette,
                    parseHex: parseHex,
                    onEdit: () async {
                      final edited = await editSymbol(
                        context,
                        name: colorSymbols[i]['poeticName']?.toString() ?? '',
                        meaning:
                            colorSymbols[i]['narrativeMeaning']?.toString() ??
                                '',
                        hex: colorSymbols[i]['hex']?.toString() ?? '',
                      );
                      if (edited == null) return;
                      final next = [...colorSymbols];
                      if (edited['_delete'] == true) {
                        next.removeAt(i);
                      } else {
                        next[i] = edited;
                      }
                      await updateCustomData(ref, {'colorSymbols': next});
                    },
                  ),
                ),
              addButton('Añadir simbología', () async {
                final added = await editSymbol(
                  context,
                  name: '',
                  meaning: '',
                  hex: '',
                );
                if (added == null || added['_delete'] == true) return;
                await updateCustomData(ref, {
                  'colorSymbols': [...colorSymbols, added],
                });
              }),
              pointImages('colorSymbolism'),
            ],
          ),
        ),
      'lightPhilosophy' => _GlassCard(
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
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (key, label) in kConceptLightMetrics)
                    SizedBox(
                      width: 132,
                      child: _MetricTile(
                        label: label,
                        value: metrics[key] ?? '—',
                        palette: palette,
                        onEdit: (v) => updateCustomData(ref, {
                          'lightingMetrics': {...metrics, key: v},
                        }),
                      ),
                    ),
                ],
              ),
              pointImages('lightPhilosophy'),
            ],
          ),
        ),
      'references' => _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                icon: Icons.collections_outlined,
                title: 'Referencias Visuales',
                palette: palette,
              ),
              const SizedBox(height: 16),
              BibleReferencesDeck(
                projectId: projectId,
                bibleId: data.id,
                sectionId: BibleSectionId.concept,
                kinds: kConceptReferenceKinds,
                copy: BibleReferencesCopy.concept,
                references: BibleReference.listFrom(custom['keyReferences']),
                onChanged: (next) => updateCustomData(ref, {
                  'keyReferences': [for (final r in next) r.toJson()],
                }),
                onAddImage: () => MoodboardHelpers.addManualImages(
                  db: db,
                  projectId: projectId,
                  bibleId: data.id,
                  assignedSections: const [BibleSectionId.concept],
                ),
                onOpenMoodboard: () =>
                    BibleNavigationScope.openMoodboardForSection(
                      context,
                      BibleSectionId.concept,
                    ),
              ),
            ],
          ),
        ),
      'keyFrame' => _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                icon: Icons.movie_filter_outlined,
                title: keyFrameTitle,
                palette: palette,
              ),
              const SizedBox(height: 8),
              Text(keyFrameTech, style: AppTypography.mono(palette)),
            ],
          ),
        ),
      'shadowTreatment' => _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                icon: Icons.contrast,
                title: 'Tratamiento de Sombras',
                palette: palette,
              ),
              const SizedBox(height: 12),
              BibleTextField(
                label: '',
                maxLines: 5,
                initialValue: shadowTreatment,
                onChanged: (v) =>
                    updateCustomData(ref, {'shadowTreatment': v}),
              ),
              pointImages('shadowTreatment'),
            ],
          ),
        ),
      'composition' => _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                icon: Icons.grid_on_outlined,
                title: 'Composición',
                palette: palette,
              ),
              const SizedBox(height: 12),
              BibleTextField(
                label: '',
                hint: 'Cómo se ordena el cuadro: simetría, espacio negativo, '
                    'líneas, relación del personaje con el entorno…',
                maxLines: 5,
                initialValue: composition,
                onChanged: (v) => updateCustomData(ref, {'composition': v}),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (key, label) in kConceptCompositionMetrics)
                    SizedBox(
                      width: 132,
                      child: _MetricTile(
                        label: label,
                        value: compositionMetrics[key] ?? '—',
                        palette: palette,
                        onEdit: (v) => updateCustomData(ref, {
                          'compositionMetrics': {...compositionMetrics, key: v},
                        }),
                      ),
                    ),
                ],
              ),
              pointImages('composition'),
            ],
          ),
        ),
      'actComposition' => _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                icon: Icons.grid_view_outlined,
                title: 'Composición por Actos',
                palette: palette,
              ),
              const SizedBox(height: 14),
              for (final n in ['1', '2', '3'])
                _CompositionActRow(
                  actLabel: 'Act ${['I', 'II', 'III'][int.parse(n) - 1]}:',
                  value: actComp[n] ?? '—',
                  palette: palette,
                  onEdit: (v) => updateCustomData(ref, {
                    'actComposition': {...actComp, n: v},
                  }),
                ),
            ],
          ),
        ),
      'actNotes' => _GlassCard(
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
                  await updateCustomData(ref, {
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
                  await updateCustomData(ref, {
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
                  await updateCustomData(ref, {
                    'act3Intent': body,
                    'actTitles': {...actTitles, '3': title},
                  });
                },
              ),
            ],
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
