import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_navigation_scope.dart';
import '../bible_visual_color_sheet.dart';
import '../color_scene_palettes_panel.dart';
import 'section_scaffold.dart';

/// Color e imagen — layout Stitch (paletas + Kelvin + LUTs).
class ColorImageSection extends ConsumerWidget {
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

  Map<String, dynamic> _getCustomData() {
    if (sectionContentJson == null || sectionContentJson!.isEmpty) return {};
    try {
      final decoded = jsonDecode(sectionContentJson!);
      if (decoded is! Map<String, dynamic>) return {};
      final valuesRaw = decoded['values'] ?? decoded['_values'];
      if (valuesRaw is Map) {
        final vals = Map<String, dynamic>.from(valuesRaw);
        if (vals['colorData'] is String) {
          final parsed = jsonDecode(vals['colorData'] as String);
          if (parsed is Map<String, dynamic>) return parsed;
        }
        return vals;
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
                d.id.equals(BibleSectionId.colorImage),
          ))
        .getSingleOrNull();
    if (def == null) return;
    final fields = BibleSectionFieldsConfig.parse(
      def.contentJson,
      BibleSectionId.colorImage,
    );
    final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
    values['colorData'] = jsonEncode(newData);
    await db.upsertBibleSectionDefinition(
      def.copyWith(
        contentJson: drift.Value(
          BibleSectionFieldsConfig.encode(fields, values: values),
        ),
      ),
    );
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

  /// Hex puede venir como `#RRGGBB` o `Nombre|#RRGGBB`.
  (String name, String hex) _parseSwatch(String raw, String fallbackName) {
    if (raw.contains('|')) {
      final parts = raw.split('|');
      final name = parts.first.trim();
      final hex = parts.length > 1 ? parts[1].trim() : parts.first.trim();
      return (name.isEmpty ? fallbackName : name, _normalizeHex(hex));
    }
    return (fallbackName, _normalizeHex(raw));
  }

  String _normalizeHex(String hex) {
    var h = hex.trim();
    if (!h.startsWith('#')) h = '#$h';
    return h.toUpperCase();
  }

  Map<String, String> _nameMap(Map<String, dynamic> custom) {
    final raw = custom['swatchNames'];
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString().toUpperCase(), v.toString()));
  }

  String _displayName(
    String hex,
    String fallback,
    Map<String, String> names,
  ) {
    return names[_normalizeHex(hex)] ??
        names[hex.toUpperCase()] ??
        fallback;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final custom = _getCustomData();
    final names = _nameMap(custom);
    final kelvinLabel = custom['kelvinLabel'] as String? ?? 'Temperatura Base (EXT)';
    final workingTags = (custom['workingLutTags'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        ['LogC4', 'Rec.709'];
    final creativeTags = (custom['creativeLutTags'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        ['Contraste Alto', 'Tint Cyan'];

    return BibleSectionScaffold(
      sectionId: BibleSectionId.colorImage,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Qué emoción transmite esta paleta y este LUT? Cómo el color apoya la narrativa…',
      sectionNumber: null,
      sectionTitle: 'Color e imagen',
      fieldWidgets: {
        'narrative': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BibleCrossNavChips.techTriplet(current: BibleSectionId.colorImage),
            const SizedBox(height: 12),
            _ColorEditorialHeader(
              data: data,
              onChanged: onChanged,
              palette: palette,
            ),
          ],
        ),
        'lut': const SizedBox.shrink(),
        'blocks': StreamBuilder<List<VisualBibleColorBlock>>(
          stream: db.watchColorBlocksForBible(bibleId),
          builder: (context, snap) {
            final blocks =
                snap.data?.map(ColorBlockModel.fromRow).toList() ?? [];
            final primary = blocks.isNotEmpty ? blocks.first : null;

            final dominant = <(String, String)>[];
            final accents = <(String, String)>[];
            final prohibited = <(String, String)>[];

            if (primary != null) {
              for (var i = 0; i < primary.dominantColors.length; i++) {
                final parsed = _parseSwatch(
                  primary.dominantColors[i],
                  'Color ${i + 1}',
                );
                dominant.add((
                  _displayName(parsed.$2, parsed.$1, names),
                  parsed.$2,
                ));
              }
              for (var i = 0; i < primary.accentColors.length; i++) {
                final parsed = _parseSwatch(
                  primary.accentColors[i],
                  'Acento ${i + 1}',
                );
                accents.add((
                  _displayName(parsed.$2, parsed.$1, names),
                  parsed.$2,
                ));
              }
              for (var i = 0; i < primary.prohibitedColors.length; i++) {
                final parsed = _parseSwatch(
                  primary.prohibitedColors[i],
                  'Prohibido ${i + 1}',
                );
                prohibited.add((
                  _displayName(parsed.$2, parsed.$1, names),
                  parsed.$2,
                ));
              }
            }

            // Agregar dominantes de otros bloques si el primero tiene pocos
            if (dominant.length < 4) {
              for (final b in blocks.skip(1)) {
                for (final c in b.dominantColors) {
                  if (dominant.length >= 4) break;
                  final parsed = _parseSwatch(c, b.blockName);
                  dominant.add((
                    _displayName(parsed.$2, parsed.$1, names),
                    parsed.$2,
                  ));
                }
              }
            }

            final kelvin = primary?.colorTempKelvin ??
                (custom['kelvin'] as num?)?.toInt() ??
                5600;

            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final left = Column(
                  children: [
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(
                            icon: Icons.water_drop_outlined,
                            label: 'Paleta Dominante',
                            palette: palette,
                          ),
                          const SizedBox(height: 16),
                          if (dominant.isEmpty)
                            _EmptyHint(
                              text:
                                  'Añade colores dominantes al bloque de paleta.',
                              palette: palette,
                              onAdd: () => _ensureBlockAndEdit(
                                context,
                                ref,
                                blocks,
                                kind: _SwatchKind.dominant,
                              ),
                            )
                          else
                            LayoutBuilder(
                              builder: (context, c) {
                                final cols = c.maxWidth >= 520
                                    ? dominant.length.clamp(1, 4)
                                    : 2;
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 14,
                                  children: [
                                    for (var i = 0; i < dominant.length; i++)
                                      SizedBox(
                                        width: (c.maxWidth - (cols - 1) * 12) /
                                            cols,
                                        child: _DominantSwatch(
                                          name: dominant[i].$1,
                                          hex: dominant[i].$2,
                                          palette: palette,
                                          parseHex: _parseHex,
                                          onEdit: () => _editSwatch(
                                            context,
                                            ref,
                                            blocks,
                                            kind: _SwatchKind.dominant,
                                            index: i,
                                            name: dominant[i].$1,
                                            hex: dominant[i].$2,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _ensureBlockAndEdit(
                                context,
                                ref,
                                blocks,
                                kind: _SwatchKind.dominant,
                              ),
                              icon: Icon(
                                Icons.add,
                                size: 16,
                                color: palette.accent,
                              ),
                              label: Text(
                                'Añadir color',
                                style: TextStyle(color: palette.accent),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, c) {
                        final sideBySide = c.maxWidth >= 480;
                        final accentsCard = _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionLabel(
                                icon: Icons.flare,
                                label: 'Acentos (Prácticos)',
                                palette: palette,
                              ),
                              const SizedBox(height: 14),
                              if (accents.isEmpty)
                                _EmptyHint(
                                  text: 'Sin acentos prácticos.',
                                  palette: palette,
                                  onAdd: () => _ensureBlockAndEdit(
                                    context,
                                    ref,
                                    blocks,
                                    kind: _SwatchKind.accent,
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    for (var i = 0; i < accents.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 12),
                                      Expanded(
                                        child: _AccentSwatch(
                                          name: accents[i].$1,
                                          hex: accents[i].$2,
                                          palette: palette,
                                          parseHex: _parseHex,
                                          onEdit: () => _editSwatch(
                                            context,
                                            ref,
                                            blocks,
                                            kind: _SwatchKind.accent,
                                            index: i,
                                            name: accents[i].$1,
                                            hex: accents[i].$2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              TextButton.icon(
                                onPressed: () => _ensureBlockAndEdit(
                                  context,
                                  ref,
                                  blocks,
                                  kind: _SwatchKind.accent,
                                ),
                                icon: Icon(
                                  Icons.add,
                                  size: 14,
                                  color: palette.accent,
                                ),
                                label: Text(
                                  'Añadir',
                                  style: TextStyle(
                                    color: palette.accent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        final forbiddenCard = _GlassCard(
                          borderColor:
                              const Color(0xFFFFB4AB).withValues(alpha: 0.25),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionLabel(
                                icon: Icons.block,
                                label: 'Colores Prohibidos',
                                palette: palette,
                                color: const Color(0xFFFFB4AB),
                              ),
                              const SizedBox(height: 14),
                              if (prohibited.isEmpty)
                                _EmptyHint(
                                  text: 'Ninguno definido.',
                                  palette: palette,
                                  onAdd: () => _ensureBlockAndEdit(
                                    context,
                                    ref,
                                    blocks,
                                    kind: _SwatchKind.prohibited,
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  children: [
                                    for (var i = 0;
                                        i < prohibited.length;
                                        i++)
                                      _ForbiddenSwatch(
                                        name: prohibited[i].$1,
                                        hex: prohibited[i].$2,
                                        palette: palette,
                                        parseHex: _parseHex,
                                        onEdit: () => _editSwatch(
                                          context,
                                          ref,
                                          blocks,
                                          kind: _SwatchKind.prohibited,
                                          index: i,
                                          name: prohibited[i].$1,
                                          hex: prohibited[i].$2,
                                        ),
                                      ),
                                  ],
                                ),
                              TextButton.icon(
                                onPressed: () => _ensureBlockAndEdit(
                                  context,
                                  ref,
                                  blocks,
                                  kind: _SwatchKind.prohibited,
                                ),
                                icon: const Icon(
                                  Icons.add,
                                  size: 14,
                                  color: Color(0xFFFFB4AB),
                                ),
                                label: const Text(
                                  'Añadir',
                                  style: TextStyle(
                                    color: Color(0xFFFFB4AB),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (sideBySide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: accentsCard),
                              const SizedBox(width: 16),
                              Expanded(child: forbiddenCard),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            accentsCard,
                            const SizedBox(height: 16),
                            forbiddenCard,
                          ],
                        );
                      },
                    ),
                  ],
                );

                final right = Column(
                  children: [
                    _KelvinCard(
                      kelvin: kelvin,
                      label: kelvinLabel,
                      palette: palette,
                      onChanged: (v) async {
                        await _updateCustomData(ref, {'kelvin': v});
                        if (primary != null) {
                          await db.updateColorBlock(
                            (await (db.select(db.visualBibleColorBlocks)
                                      ..where((t) => t.id.equals(primary.id)))
                                    .getSingle())
                                .copyWith(colorTempKelvin: drift.Value(v)),
                          );
                        }
                      },
                      onEditLabel: () async {
                        final c = TextEditingController(text: kelvinLabel);
                        final v = await _prompt(
                          context,
                          title: 'Etiqueta Kelvin',
                          controller: c,
                        );
                        if (v != null) {
                          await _updateCustomData(ref, {'kelvinLabel': v});
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _LutsCard(
                      workingLut: data.workingLutName ?? '',
                      creativeLut: data.creativeLutName ?? '',
                      workingTags: workingTags,
                      creativeTags: creativeTags,
                      palette: palette,
                      onEditWorking: () async {
                        final c = TextEditingController(
                          text: data.workingLutName ?? '',
                        );
                        final v = await _prompt(
                          context,
                          title: 'Monitoring / Working LUT',
                          controller: c,
                        );
                        if (v == null) return;
                        data.workingLutName = v;
                        onChanged(data);
                      },
                      onEditCreative: () async {
                        final c = TextEditingController(
                          text: data.creativeLutName ?? '',
                        );
                        final v = await _prompt(
                          context,
                          title: 'Creative LUT (Show LUT)',
                          controller: c,
                        );
                        if (v == null) return;
                        data.creativeLutName = v;
                        onChanged(data);
                      },
                      onEditWorkingTags: () async {
                        final c = TextEditingController(
                          text: workingTags.join(', '),
                        );
                        final v = await _prompt(
                          context,
                          title: 'Tags Working LUT (coma)',
                          controller: c,
                        );
                        if (v == null) return;
                        await _updateCustomData(ref, {
                          'workingLutTags': v
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList(),
                        });
                      },
                      onEditCreativeTags: () async {
                        final c = TextEditingController(
                          text: creativeTags.join(', '),
                        );
                        final v = await _prompt(
                          context,
                          title: 'Tags Creative LUT (coma)',
                          controller: c,
                        );
                        if (v == null) return;
                        await _updateCustomData(ref, {
                          'creativeLutTags': v
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList(),
                        });
                      },
                    ),
                  ],
                );

                Widget main;
                if (wide) {
                  main = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 8, child: left),
                      const SizedBox(width: 20),
                      Expanded(flex: 4, child: right),
                    ],
                  );
                } else {
                  main = Column(
                    children: [
                      left,
                      const SizedBox(height: 16),
                      right,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    main,
                    const SizedBox(height: 28),
                    ColorScenePalettesPanel(
                      projectId: projectId,
                      bibleId: bibleId,
                      blocks: blocks,
                    ),
                  ],
                );
              },
            );
          },
        ),
      },
    );
  }

  Future<ColorBlockModel> _ensurePrimaryBlock(
    WidgetRef ref,
    List<ColorBlockModel> blocks,
  ) async {
    if (blocks.isNotEmpty) return blocks.first;
    final db = ref.read(databaseProvider);
    final id = await db.insertColorBlock(
      VisualBibleColorBlocksCompanion.insert(
        bibleId: bibleId,
        blockName: 'Paleta Dominante',
        dominantColors: '[]',
      ),
    );
    return ColorBlockModel(
      id: id,
      bibleId: bibleId,
      blockName: 'Paleta Dominante',
    );
  }

  Future<void> _ensureBlockAndEdit(
    BuildContext context,
    WidgetRef ref,
    List<ColorBlockModel> blocks, {
    required _SwatchKind kind,
  }) async {
    final block = await _ensurePrimaryBlock(ref, blocks);
    if (!context.mounted) return;
    await _editSwatch(
      context,
      ref,
      [block, ...blocks.where((b) => b.id != block.id)],
      kind: kind,
      index: -1,
      name: '',
      hex: kind == _SwatchKind.prohibited ? '#FF00FF' : '#1A3C40',
    );
  }

  Future<void> _editSwatch(
    BuildContext context,
    WidgetRef ref,
    List<ColorBlockModel> blocks, {
    required _SwatchKind kind,
    required int index,
    required String name,
    required String hex,
  }) async {
    final block = await _ensurePrimaryBlock(ref, blocks);
    if (!context.mounted) return;
    final kindLabel = switch (kind) {
      _SwatchKind.dominant => 'dominante',
      _SwatchKind.accent => 'de acento',
      _SwatchKind.prohibited => 'prohibido',
    };
    final picked = await BibleVisualColorSheet.show(
      context,
      title: index < 0 ? 'Añadir color $kindLabel' : 'Editar color $kindLabel',
      initialName: name,
      initialColor: _parseHex(hex) ?? const Color(0xFF1A3C40),
      canDelete: index >= 0,
      nameHint: switch (kind) {
        _SwatchKind.dominant => 'Ej. Teal noche, ámbar práctico…',
        _SwatchKind.accent => 'Ej. Magenta neón, rojo señal…',
        _SwatchKind.prohibited => 'Ej. Verde hospital, magenta…',
      },
    );
    if (picked == null) return;

    final db = ref.read(databaseProvider);
    final row = await (db.select(db.visualBibleColorBlocks)
          ..where((t) => t.id.equals(block.id)))
        .getSingle();
    final model = ColorBlockModel.fromRow(row);

    List<String> list;
    switch (kind) {
      case _SwatchKind.dominant:
        list = List<String>.from(model.dominantColors);
      case _SwatchKind.accent:
        list = List<String>.from(model.accentColors);
      case _SwatchKind.prohibited:
        list = List<String>.from(model.prohibitedColors);
    }

    if (picked.delete && index >= 0) {
      if (index < list.length) list.removeAt(index);
    } else if (!picked.delete) {
      final n = picked.name.trim();
      final h = _normalizeHex(picked.hex);
      final encoded = n.isEmpty ? h : '$n|$h';
      if (index < 0) {
        list.add(encoded);
      } else if (index < list.length) {
        list[index] = encoded;
      } else {
        list.add(encoded);
      }
      final custom = _getCustomData();
      final nameMap = _nameMap(custom);
      nameMap[h] = n.isEmpty ? h : n;
      await _updateCustomData(ref, {'swatchNames': nameMap});
    } else {
      return;
    }

    switch (kind) {
      case _SwatchKind.dominant:
        model.dominantColors = list;
      case _SwatchKind.accent:
        model.accentColors = list;
      case _SwatchKind.prohibited:
        model.prohibitedColors = list;
    }
    await db.updateColorBlock(row.copyWith(
      dominantColors: jsonEncode(model.dominantColors),
      accentColors: drift.Value(
        model.accentColors.isEmpty ? null : jsonEncode(model.accentColors),
      ),
      prohibitedColors: drift.Value(
        model.prohibitedColors.isEmpty
            ? null
            : jsonEncode(model.prohibitedColors),
      ),
    ));
  }

  static Future<String?> _prompt(
    BuildContext context, {
    required String title,
    required TextEditingController controller,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

enum _SwatchKind { dominant, accent, prohibited }

class _ColorEditorialHeader extends StatelessWidget {
  final VisualBibleData data;
  final BibleChanged onChanged;
  final AppPalette palette;

  const _ColorEditorialHeader({
    required this.data,
    required this.onChanged,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SEC. 07',
          style: AppTypography.mono(palette).copyWith(
            fontSize: 13,
            color: palette.textTertiary.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Color e imagen',
                style: AppTypography.displayMedium(palette).copyWith(
                  fontSize: 40,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.only(left: 16),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: palette.accent, width: 2),
                  ),
                ),
                child: BibleTextField(
                  label: '',
                  hint:
                      'Intención Narrativa: La paleta debe sentirse sofocante pero clínica…',
                  maxLines: 4,
                  initialValue: data.colorNarrativeIntent ?? '',
                  onChanged: (v) {
                    data.colorNarrativeIntent = v;
                    onChanged(data);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const _GlassCard({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppPalette palette;
  final Color? color;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.palette,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? palette.textTertiary;
    return Row(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: AppTypography.label(palette).copyWith(
            fontSize: 11,
            letterSpacing: 1.4,
            color: c,
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  final AppPalette palette;
  final VoidCallback onAdd;

  const _EmptyHint({
    required this.text,
    required this.palette,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: AppTypography.bodyMedium(palette).copyWith(
            color: palette.textTertiary,
          ),
        ),
        TextButton(
          onPressed: onAdd,
          child: Text('Añadir', style: TextStyle(color: palette.accent)),
        ),
      ],
    );
  }
}

class _DominantSwatch extends StatelessWidget {
  final String name;
  final String hex;
  final AppPalette palette;
  final Color? Function(String?) parseHex;
  final VoidCallback onEdit;

  const _DominantSwatch({
    required this.name,
    required this.hex,
    required this.palette,
    required this.parseHex,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 88,
            decoration: BoxDecoration(
              color: parseHex(hex) ?? palette.surfaceOverlay,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.mono(palette).copyWith(fontSize: 12),
                ),
              ),
              GestureDetector(
                onTap: () => Clipboard.setData(ClipboardData(text: hex)),
                child: Text(
                  hex,
                  style: AppTypography.mono(palette).copyWith(
                    fontSize: 10,
                    color: palette.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  final String name;
  final String hex;
  final AppPalette palette;
  final Color? Function(String?) parseHex;
  final VoidCallback onEdit;

  const _AccentSwatch({
    required this.name,
    required this.hex,
    required this.palette,
    required this.parseHex,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: parseHex(hex) ?? palette.surfaceOverlay,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.mono(palette).copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ForbiddenSwatch extends StatelessWidget {
  final String name;
  final String hex;
  final AppPalette palette;
  final Color? Function(String?) parseHex;
  final VoidCallback onEdit;

  const _ForbiddenSwatch({
    required this.name,
    required this.hex,
    required this.palette,
    required this.parseHex,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (parseHex(hex) ?? palette.error).withValues(alpha: 0.5),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              const Icon(Icons.close, size: 14, color: Color(0xFFFFB4AB)),
            ],
          ),
          const SizedBox(width: 10),
          Text(
            name,
            style: AppTypography.mono(palette).copyWith(
              fontSize: 12,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _KelvinCard extends StatefulWidget {
  final int kelvin;
  final String label;
  final AppPalette palette;
  final ValueChanged<int> onChanged;
  final VoidCallback onEditLabel;

  const _KelvinCard({
    required this.kelvin,
    required this.label,
    required this.palette,
    required this.onChanged,
    required this.onEditLabel,
  });

  @override
  State<_KelvinCard> createState() => _KelvinCardState();
}

class _KelvinCardState extends State<_KelvinCard> {
  late int _value;
  double? _dragStartX;
  int? _dragStartK;

  @override
  void initState() {
    super.initState();
    _value = widget.kelvin;
  }

  @override
  void didUpdateWidget(covariant _KelvinCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kelvin != widget.kelvin &&
        _dragStartX == null) {
      _value = widget.kelvin;
    }
  }

  void _commit(int v) {
    final clamped = v.clamp(2000, 10000);
    setState(() => _value = clamped);
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E3A8A).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                InkWell(
                  onTap: widget.onEditLabel,
                  child: Text(
                    widget.label.toUpperCase(),
                    style: AppTypography.label(widget.palette).copyWith(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      color: widget.palette.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onHorizontalDragStart: (d) {
                    _dragStartX = d.globalPosition.dx;
                    _dragStartK = _value;
                  },
                  onHorizontalDragUpdate: (d) {
                    if (_dragStartX == null || _dragStartK == null) return;
                    final dx = d.globalPosition.dx - _dragStartX!;
                    final steps = (dx / 8).round();
                    setState(() {
                      _value = (_dragStartK! + steps * 100).clamp(2000, 10000);
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    _dragStartX = null;
                    _dragStartK = null;
                    widget.onChanged(_value);
                  },
                  onTap: () async {
                    final c = TextEditingController(text: '$_value');
                    final v = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Kelvin'),
                        content: TextField(
                          controller: c,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(ctx, c.text.trim()),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                    final n = int.tryParse(v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '');
                    if (n != null) _commit(n);
                  },
                  child: Text(
                    '${_value}K',
                    style: AppTypography.mono(widget.palette).copyWith(
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      color: widget.palette.accent,
                      letterSpacing: -1.5,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Deslizar para ajustar',
                  style: AppTypography.mono(widget.palette).copyWith(
                    fontSize: 11,
                    color: widget.palette.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LutsCard extends StatelessWidget {
  final String workingLut;
  final String creativeLut;
  final List<String> workingTags;
  final List<String> creativeTags;
  final AppPalette palette;
  final VoidCallback onEditWorking;
  final VoidCallback onEditCreative;
  final VoidCallback onEditWorkingTags;
  final VoidCallback onEditCreativeTags;

  const _LutsCard({
    required this.workingLut,
    required this.creativeLut,
    required this.workingTags,
    required this.creativeTags,
    required this.palette,
    required this.onEditWorking,
    required this.onEditCreative,
    required this.onEditWorkingTags,
    required this.onEditCreativeTags,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(
            icon: Icons.transform,
            label: 'LUTs Asignados',
            palette: palette,
          ),
          const SizedBox(height: 16),
          _LutTile(
            eyebrow: 'MONITORING / WORKING LUT',
            name: workingLut.isEmpty ? 'Sin LUT' : workingLut,
            tags: workingTags,
            palette: palette,
            primaryTag: true,
            onEdit: onEditWorking,
            onEditTags: onEditWorkingTags,
          ),
          const SizedBox(height: 12),
          _LutTile(
            eyebrow: 'CREATIVE LUT (SHOW LUT)',
            name: creativeLut.isEmpty ? 'Sin LUT' : creativeLut,
            tags: creativeTags,
            palette: palette,
            primaryTag: false,
            onEdit: onEditCreative,
            onEditTags: onEditCreativeTags,
          ),
        ],
      ),
    );
  }
}

class _LutTile extends StatelessWidget {
  final String eyebrow;
  final String name;
  final List<String> tags;
  final AppPalette palette;
  final bool primaryTag;
  final VoidCallback onEdit;
  final VoidCallback onEditTags;

  const _LutTile({
    required this.eyebrow,
    required this.name,
    required this.tags,
    required this.palette,
    required this.primaryTag,
    required this.onEdit,
    required this.onEditTags,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: AppTypography.label(palette).copyWith(
              fontSize: 9,
              letterSpacing: 1.1,
              color: palette.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: onEdit,
            child: Text(
              name,
              style: AppTypography.mono(palette).copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onEditTags,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < tags.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: i == 0 && primaryTag
                          ? palette.accent.withValues(alpha: 0.2)
                          : i == 0 && !primaryTag
                              ? const Color(0xFFC9C2E5).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tags[i],
                      style: AppTypography.mono(palette).copyWith(
                        fontSize: 10,
                        color: i == 0 && primaryTag
                            ? palette.accent
                            : i == 0 && !primaryTag
                                ? const Color(0xFFC9C2E5)
                                : palette.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
