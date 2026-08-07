import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

enum MoodboardSortMode { recent, caption, random }

enum MoodboardViewMode { grid, compact, list }

/// Chips de catálogo biblia (ShotDeck-style): lugar / luz / paleta / pendientes.
const kMoodboardPrimaryFilters = <(String, String?)>[
  ('Todas', null),
  ('Localización', '__catalog_location__'),
  ('Luz', '__catalog_lighting__'),
  ('Paleta', '__catalog_palette__'),
  ('Pendientes', '__catalog_pending__'),
  ('Sin clasificar', '__unassigned__'),
];

/// Cabecera editorial: `13 Moodboard` + párrafo de intención.
class MoodboardStitchHeader extends StatelessWidget {
  final int sectionNumber;
  final String title;
  final String? narrative;
  final Widget? trailing;

  const MoodboardStitchHeader({
    super.key,
    this.sectionNumber = 13,
    this.title = 'Moodboard',
    this.narrative,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final body = narrative?.trim().isNotEmpty == true
        ? narrative!.trim()
        : 'Stills como eje visual. Pasa el ratón para título y apunte; amplía para '
            'paleta y catálogo (lugar, luz, color). Clasifica por la biblia, no por créditos.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$sectionNumber',
                style: AppTypography.mono(palette).copyWith(
                  color: palette.accent.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.displayMedium(palette).copyWith(
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.9,
                    color: palette.textPrimary,
                    height: 1.05,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(
              body,
              style: AppTypography.bodyLarge(palette).copyWith(
                fontSize: 17,
                height: 1.55,
                color: palette.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chips glass (All / Lighting / Color…).
class MoodboardStitchGlassChips extends StatelessWidget {
  final List<(String, String?)> filters;
  final String? activeCategory;
  final ValueChanged<String?> onSelect;

  const MoodboardStitchGlassChips({
    super.key,
    required this.filters,
    required this.activeCategory,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final f in filters)
          _GlassChip(
            label: f.$1,
            selected: activeCategory == f.$2,
            onTap: () => onSelect(f.$2),
            accent: palette.accent,
            textSecondary: palette.textSecondary,
          ),
      ],
    );
  }
}

class _GlassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final Color textSecondary;

  const _GlassChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.12)
          : const Color(0xB31A1A1C),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check, size: 14, color: accent),
                const SizedBox(width: 6),
              ],
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: selected ? accent : textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra secundaria compacta: búsqueda + acciones.
class MoodboardStitchActionBar extends StatelessWidget {
  final TextEditingController searchController;
  final int shownCount;
  final int totalCount;
  final bool selectionMode;
  final int selectedCount;
  final MoodboardSortMode sortMode;
  final ValueChanged<MoodboardSortMode> onSortMode;
  final VoidCallback onToggleSelection;
  final VoidCallback? onAdd;

  const MoodboardStitchActionBar({
    super.key,
    required this.searchController,
    required this.shownCount,
    required this.totalCount,
    required this.selectionMode,
    required this.selectedCount,
    required this.sortMode,
    required this.onSortMode,
    required this.onToggleSelection,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: searchController,
                style: AppTypography.caption(palette),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Buscar referencia…',
                  hintStyle: AppTypography.caption(palette).copyWith(
                    color: palette.textTertiary,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: palette.textTertiary,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: palette.accent.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$shownCount / $totalCount',
            style: AppTypography.mono(palette).copyWith(
              color: palette.textTertiary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<MoodboardSortMode>(
              value: sortMode,
              dropdownColor: const Color(0xFF1F1F21),
              style: AppTypography.caption(palette).copyWith(
                color: palette.accent,
              ),
              items: const [
                DropdownMenuItem(
                  value: MoodboardSortMode.recent,
                  child: Text('Recientes'),
                ),
                DropdownMenuItem(
                  value: MoodboardSortMode.caption,
                  child: Text('Título'),
                ),
                DropdownMenuItem(
                  value: MoodboardSortMode.random,
                  child: Text('Aleatorio'),
                ),
              ],
              onChanged: (v) {
                if (v != null) onSortMode(v);
              },
            ),
          ),
          IconButton(
            tooltip: 'Seleccionar',
            onPressed: onToggleSelection,
            icon: Icon(
              Icons.check_box_outlined,
              size: 20,
              color: selectionMode ? palette.warning : palette.textTertiary,
            ),
          ),
          if (onAdd != null)
            IconButton(
              tooltip: 'Añadir',
              onPressed: onAdd,
              icon: Icon(Icons.add_photo_alternate_outlined,
                  size: 20, color: palette.accent),
            ),
          if (selectedCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '$selectedCount',
                style: AppTypography.caption(palette).copyWith(
                  color: palette.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Glow ambiental de fondo (Stitch).
class MoodboardAmbientGlow extends StatelessWidget {
  const MoodboardAmbientGlow({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2997FF).withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3E495E).withValues(alpha: 0.06),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Masonry por columnas; altura intrínseca del hijo (cards editoriales).
class MoodboardMasonryGrid extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Widget? trailing;
  final List<Widget> inserts;
  final double minTileWidth;
  final double gap;
  /// Aspect ratios reales (width/height) por índice de imagen.
  final double Function(int index)? imageAspectOf;

  const MoodboardMasonryGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.trailing,
    this.inserts = const [],
    this.minTileWidth = 280,
    this.gap = 6,
    this.imageAspectOf,
  });

  /// Fallback si aún no se ha resuelto el ratio del archivo.
  static double fallbackAspectForIndex(int index) {
    const ratios = [0.72, 1.15, 0.85, 1.35, 0.95, 1.05, 0.78, 1.2];
    return ratios[index % ratios.length];
  }

  @Deprecated('Use fallbackAspectForIndex or imageAspectOf')
  static double imageAspectForIndex(int index) =>
      fallbackAspectForIndex(index);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = math.max(1, (width / minTileWidth).floor());
        final colWidth = (width - gap * (cols - 1)) / cols;

        final extras = <Widget>[
          ...inserts,
          if (trailing != null) trailing!,
        ];
        final totalItems = itemCount + extras.length;
        final columnChildren = List.generate(cols, (_) => <Widget>[]);
        final columnHeights = List.filled(cols, 0.0);

        for (var i = 0; i < totalItems; i++) {
          var bestCol = 0;
          for (var c = 1; c < cols; c++) {
            if (columnHeights[c] < columnHeights[bestCol]) bestCol = c;
          }

          final isExtra = i >= itemCount;
          final child = isExtra
              ? extras[i - itemCount]
              : itemBuilder(context, i);

          final aspect = isExtra
              ? 1.0
              : (imageAspectOf?.call(i) ?? fallbackAspectForIndex(i));
          final estH = isExtra ? 320.0 : colWidth / aspect;

          columnChildren[bestCol].add(
            Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: child,
            ),
          );
          columnHeights[bestCol] += estH + gap;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < cols; c++) ...[
              if (c > 0) SizedBox(width: gap),
              SizedBox(
                width: colWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: columnChildren[c],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Tarjeta "Project Palette" embebida en el masonry.
class MoodboardProjectPaletteCard extends StatelessWidget {
  final List<(String label, String hex)> swatches;
  final String? note;

  const MoodboardProjectPaletteCard({
    super.key,
    required this.swatches,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (swatches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xB31A1A1C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          'Project Palette\nDefine colores en Color e imagen.',
          style: AppTypography.bodyMedium(palette),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Project Palette',
                  style: AppTypography.titleMedium(palette).copyWith(
                    fontSize: 18,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'UNIFIED',
                  style: AppTypography.label(palette).copyWith(
                    color: palette.accent,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (final s in swatches) ...[
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _parseHex(s.$2) ?? palette.surfaceOverlay,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.$1.toUpperCase(),
                        style: AppTypography.label(palette).copyWith(
                          color: palette.textPrimary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.$2.toUpperCase(),
                        style: AppTypography.mono(palette).copyWith(
                          fontSize: 12,
                          color: palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (note != null && note!.trim().isNotEmpty) ...[
            Divider(color: Colors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 10),
            Text(
              note!,
              style: AppTypography.bodyMedium(palette).copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color? _parseHex(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) {
      final v = int.tryParse(h, radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return null;
  }
}