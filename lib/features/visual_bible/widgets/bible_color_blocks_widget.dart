import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_palette.dart';
import '../../../shared/visual_bible/color_points.dart';
import 'bible_palette_widget.dart';
import 'bible_point_panel.dart';

List<String> _decode(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return [for (final e in decoded) e.toString()];
  } catch (_) {}
  return [];
}

/// Paletas por bloque (acto, localización, personaje…): cada una con su
/// intención, sus colores dominantes, sus acentos, los colores a evitar y
/// su temperatura. Todo se edita en el sitio y se guarda en la tabla de
/// bloques de color de la biblia.
class BibleColorBlocksWidget extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;

  /// Nombres de muestra que la pantalla antigua guardaba aparte.
  final Map<String, String> legacyNames;

  const BibleColorBlocksWidget({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    this.legacyNames = const {},
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final palette = context.palette;
    return StreamBuilder<List<VisualBibleColorBlock>>(
      stream: db.watchColorBlocksForBible(bibleId),
      builder: (context, snap) {
        final blocks = snap.data ?? const <VisualBibleColorBlock>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final block in blocks)
              _ColorBlockCard(
                key: ValueKey('color_block_${block.id}'),
                projectId: projectId,
                bibleId: bibleId,
                sectionId: sectionId,
                block: block,
                legacyNames: legacyNames,
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => db.insertColorBlock(
                  VisualBibleColorBlocksCompanion.insert(
                    bibleId: bibleId,
                    blockName: '',
                    dominantColors: '[]',
                    sortOrder: Value(blocks.length),
                  ),
                ),
                icon: Icon(Icons.add, size: 16, color: palette.textSecondary),
                label: Text(
                  'AÑADIR BLOQUE DE COLOR',
                  style: BiblePointPanel.labelStyle(palette),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ColorBlockCard extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final VisualBibleColorBlock block;
  final Map<String, String> legacyNames;

  const _ColorBlockCard({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.block,
    required this.legacyNames,
  });

  @override
  ConsumerState<_ColorBlockCard> createState() => _ColorBlockCardState();
}

class _ColorBlockCardState extends ConsumerState<_ColorBlockCard> {
  Timer? _debounce;
  VisualBibleColorBlock? _pending;

  AppDatabase get _db => ref.read(databaseProvider);

  /// La fila con lo último escrito, se haya guardado ya o no.
  VisualBibleColorBlock get _row => _pending ?? widget.block;

  void _typed(VisualBibleColorBlock next) {
    _pending = next;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _flush);
  }

  void _flush() {
    final row = _pending;
    _pending = null;
    if (row != null) _db.updateColorBlock(row);
  }

  void _save(VisualBibleColorBlock next) {
    _debounce?.cancel();
    _pending = null;
    _db.updateColorBlock(next);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _flush();
    super.dispose();
  }

  InputDecoration _bare(AppPalette palette, String hint, TextStyle style) =>
      InputDecoration(
        hintText: hint,
        hintStyle: style.copyWith(color: palette.textTertiary),
        isDense: true,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      );

  Widget _palette(
    AppPalette palette,
    String label,
    List<String> stored,
    VisualBibleColorBlock Function(String json) write,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: BiblePointPanel.labelStyle(palette)),
      const SizedBox(height: 6),
      BiblePaletteWidget(
        projectId: widget.projectId,
        bibleId: widget.bibleId,
        sectionId: widget.sectionId,
        swatchSize: 56,
        colors: ColorPoints.swatches(stored, names: widget.legacyNames),
        onChanged: (colors) =>
            _save(write(jsonEncode(ColorPoints.storeSwatches(colors)))),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final block = widget.block;
    final title = AppTypography.titleMedium(palette);
    final body = AppTypography.bodyMedium(palette);
    final mono = AppTypography.mono(palette).copyWith(color: palette.accent);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.background.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: block.blockName,
                  style: title,
                  decoration: _bare(
                    palette,
                    'Nombre del bloque: acto, localización, personaje…',
                    title,
                  ),
                  onChanged: (v) => _typed(_row.copyWith(blockName: v.trim())),
                ),
              ),
              SizedBox(
                width: 96,
                child: TextFormField(
                  initialValue: block.colorTempKelvin?.toString() ?? '',
                  style: mono,
                  textAlign: TextAlign.end,
                  keyboardType: TextInputType.number,
                  decoration: _bare(palette, 'Kelvin', mono).copyWith(
                    suffixText: ' K',
                    suffixStyle: mono,
                  ),
                  onChanged: (v) => _typed(
                    _row.copyWith(colorTempKelvin: Value(int.tryParse(v.trim()))),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 14, color: palette.textTertiary),
                tooltip: 'Quitar bloque',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _debounce?.cancel();
                  _pending = null;
                  _db.deleteColorBlock(block.id);
                },
              ),
            ],
          ),
          TextFormField(
            initialValue: block.emotionalIntent ?? '',
            minLines: 1,
            maxLines: null,
            style: body,
            decoration: _bare(
              palette,
              'Qué emoción lleva este color y por qué…',
              body,
            ),
            onChanged: (v) => _typed(
              _row.copyWith(
                emotionalIntent: Value(v.trim().isEmpty ? null : v.trim()),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.md,
            children: [
              _palette(
                palette,
                'Dominantes',
                _decode(block.dominantColors),
                (json) => _row.copyWith(dominantColors: json),
              ),
              _palette(
                palette,
                'Acentos',
                _decode(block.accentColors),
                (json) => _row.copyWith(accentColors: Value(json)),
              ),
              _palette(
                palette,
                'Se evitan',
                _decode(block.prohibitedColors),
                (json) => _row.copyWith(prohibitedColors: Value(json)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
